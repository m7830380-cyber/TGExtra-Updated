// Deleted messages -> semi-transparent bubbles.
//
// Deletion ids come from TLWalker (anti-delete). Keys: "c<channelId>_<msgId>" for
// channels/supergroups, "u_<msgId>" for private chats + basic groups (ids there are
// unique per account). Chat rows are matched by reading ChatMessageItemView's Swift
// `item` ivar (class-bound existential: first word = object) and parsing its description:
//   "(ChatMessageItem id: <peerNs>:<peerId>:<msgNs>_<msgId>, text: ...)"
#import "Headers.h"
#import <objc/runtime.h>

#define kDeletedSetKey @"TGExtraDeletedSet"
#define kDeletedAlpha 0.4

@interface ASDisplayNode : NSObject
@property (nonatomic) CGFloat alpha;
@end

static NSMutableSet<NSString *> *gDeleted;
static NSHashTable *gLiveNodes;
static Class gItemViewClass;
static ptrdiff_t gItemOffset = -1;
static const void *kTGXFadedKey = &kTGXFadedKey;
static NSRegularExpression *gIdRegex;

static void loadDeleted(void) {
	NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:kDeletedSetKey];
	gDeleted = saved ? [NSMutableSet setWithArray:saved] : [NSMutableSet set];
}

static void saveDeletedSoon(void) {
	static BOOL pending = NO;
	if (pending) return;
	pending = YES;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		pending = NO;
		NSArray *all = gDeleted.allObjects;
		if (all.count > 20000) all = [all subarrayWithRange:NSMakeRange(all.count - 20000, 20000)];
		[[NSUserDefaults standardUserDefaults] setObject:all forKey:kDeletedSetKey];
	});
}

NSString *TGXMessageKey(int64_t channelId, int32_t messageId) {
	if (channelId != 0) return [NSString stringWithFormat:@"c%lld_%d", channelId, messageId];
	return [NSString stringWithFormat:@"u_%d", messageId];
}

BOOL TGXIsDeletedKey(NSString *key) {
	if (!key) return NO;
	@synchronized (gDeleted) { return [gDeleted containsObject:key]; }
}

static NSString *keyForNode(id node) {
	if (gItemOffset < 0) return nil;
	void *raw = *(void **)((uint8_t *)(__bridge void *)node + gItemOffset);
	if (!raw) return nil;
	id item = (__bridge id)raw;
	NSString *desc = nil;
	@try { desc = [item description]; } @catch (NSException *e) { return nil; }
	if (!desc) return nil;
	NSTextCheckingResult *m = [gIdRegex firstMatchInString:desc options:0 range:NSMakeRange(0, MIN(desc.length, (NSUInteger)160))];
	if (!m) return nil;
	int ns = [[desc substringWithRange:[m rangeAtIndex:1]] intValue];
	long long peer = [[desc substringWithRange:[m rangeAtIndex:2]] longLongValue];
	int msgNs = [[desc substringWithRange:[m rangeAtIndex:3]] intValue];
	int mid = [[desc substringWithRange:[m rangeAtIndex:4]] intValue];
	if (msgNs != 0) return nil; // only cloud messages
	return TGXMessageKey(ns == 2 ? peer : 0, mid);
}

@interface ASDisplayNode (TGX)
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly) BOOL isNodeLoaded;
@end

extern "C" void TGXShowEditHistory(NSArray *versions);
extern "C" NSArray *TGXVersionsForKey(NSString *key);

static const void *kTGXKeyKey = &kTGXKeyKey;

static UIView *bubbleView(UIView *row) {
	UIView *best = nil; CGFloat area = 0;
	for (UIView *v in row.subviews) {
		if (v.hidden || v.tag >= 7770) continue;
		CGFloat a = v.bounds.size.width * v.bounds.size.height;
		if (a > area && v.bounds.size.width < row.bounds.size.width - 8) { area = a; best = v; }
	}
	return best;
}

@interface TGXHistoryButton : UIButton
@end
@implementation TGXHistoryButton
- (void)tgxOpen {
	NSString *key = objc_getAssociatedObject(self, kTGXKeyKey);
	NSArray *v = TGXVersionsForKey(key);
	if (v.count) TGXShowEditHistory(v);
}
@end

static void placeBadges(ASDisplayNode *node, NSString *key, BOOL deleted) {
	if (!node.isNodeLoaded) return;
	UIView *row = node.view;
	UIView *bubble = bubbleView(row);
	CGRect b = bubble ? bubble.frame : row.bounds;

	UIImageView *bin = (UIImageView *)[row viewWithTag:7771];
	if (deleted) {
		if (!bin) {
			bin = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"trash.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold]]];
			bin.tintColor = [UIColor systemRedColor];
			bin.tag = 7771;
			bin.userInteractionEnabled = NO;
			[row addSubview:bin];
		}
		bin.hidden = NO;
	} else if (bin) {
		bin.hidden = YES;
	}

	TGXHistoryButton *hist = (TGXHistoryButton *)[row viewWithTag:7772];
	BOOL edited = key && [[NSUserDefaults standardUserDefaults] boolForKey:kEditHistory] && TGXVersionsForKey(key).count > 1;
	if (edited) {
		if (!hist) {
			hist = [TGXHistoryButton buttonWithType:UIButtonTypeSystem];
			[hist setImage:[UIImage systemImageNamed:@"clock.arrow.circlepath" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
			hist.tintColor = [UIColor systemPinkColor];
			hist.tag = 7772;
			[hist addTarget:hist action:@selector(tgxOpen) forControlEvents:UIControlEventTouchUpInside];
			[row addSubview:hist];
		}
		objc_setAssociatedObject(hist, kTGXKeyKey, key, OBJC_ASSOCIATION_COPY_NONATOMIC);
		hist.hidden = NO;
	} else if (hist) {
		hist.hidden = YES;
	}

	// Lay out outside the bubble, next to the timestamp row, on the side away from the tail.
	BOOL outgoing = CGRectGetMidX(b) > row.bounds.size.width / 2;
	CGFloat size = 22, gap = 4;
	CGFloat y = CGRectGetMaxY(b) - size - 4;
	CGFloat x = outgoing ? CGRectGetMinX(b) - gap - size : CGRectGetMaxX(b) + gap;
	NSArray *icons = outgoing ? @[hist ?: [NSNull null], bin ?: [NSNull null]] : @[bin ?: [NSNull null], hist ?: [NSNull null]];
	for (id o in icons) {
		if (o == [NSNull null] || [o isHidden]) continue;
		UIView *v = o;
		v.frame = CGRectMake(x, y, size, size);
		v.alpha = 1.0;
		v.contentMode = UIViewContentModeCenter;
		[row bringSubviewToFront:v];
		x += outgoing ? -(size + gap) : (size + gap);
	}
}

static void applyFade(ASDisplayNode *node) {
	NSString *badgeKey = keyForNode(node);
	placeBadges(node, badgeKey, [[NSUserDefaults standardUserDefaults] boolForKey:kAntiDelete] && TGXIsDeletedKey(badgeKey));
	if (![[NSUserDefaults standardUserDefaults] boolForKey:kAntiDelete]) return;
	BOOL deleted = TGXIsDeletedKey(badgeKey);
	BOOL faded = [objc_getAssociatedObject(node, kTGXFadedKey) boolValue];
	if (!node.isNodeLoaded) return;
	if (deleted || faded) {
		for (UIView *v in node.view.subviews) {
			if (v.tag >= 7770 && v.tag < 7780) continue;
			v.alpha = deleted ? kDeletedAlpha : 1.0;
		}
		objc_setAssociatedObject(node, kTGXFadedKey, deleted ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}

static void TGXLog(NSString *fmt, ...) {
	static NSFileHandle *fh;
	static int lines;
	if (lines++ > 400) return;
	if (!fh) {
		NSString *dir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"TGExtra"];
		[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
		NSString *p = [dir stringByAppendingPathComponent:@"debug.log"];
		[@"" writeToFile:p atomically:NO encoding:NSUTF8StringEncoding error:nil];
		fh = [NSFileHandle fileHandleForWritingAtPath:p];
	}
	va_list ap; va_start(ap, fmt);
	NSString *line = [[NSString alloc] initWithFormat:fmt arguments:ap];
	va_end(ap);
	[fh writeData:[[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
}

static void scanView(UIView *v, int depth) {
	if (depth > 40) return;
	id node = [v respondsToSelector:@selector(asyncdisplaykit_node)] ? [v performSelector:@selector(asyncdisplaykit_node)] : nil;
	if (node && gItemViewClass && [node isKindOfClass:gItemViewClass]) {
		static int logged;
		if (logged < 15) {
			logged++;
			void *raw = gItemOffset >= 0 ? *(void **)((uint8_t *)(__bridge void *)node + gItemOffset) : NULL;
			NSString *d = raw ? [(__bridge id)raw description] : @"(nil item)";
			TGXLog(@"node %@ key=%@ desc=%@", NSStringFromClass([node class]), keyForNode(node), d.length > 120 ? [d substringToIndex:120] : d);
		}
		[gLiveNodes addObject:node];
		applyFade((ASDisplayNode *)node);
		return;
	}
	for (UIView *sub in v.subviews) scanView(sub, depth + 1);
}

static void scanAll(void) {
	if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
	for (UIWindow *w in UIApplication.sharedApplication.windows) scanView(w, 0);
}

void TGXMarkDeleted(int64_t channelId, int32_t messageId) {
	NSString *key = TGXMessageKey(channelId, messageId);
	@synchronized (gDeleted) { [gDeleted addObject:key]; }
	dispatch_async(dispatch_get_main_queue(), ^{
		saveDeletedSoon();
		for (id node in gLiveNodes.allObjects) applyFade(node);
	});
}

%group TGXDeleted
%hook ASDisplayNode
- (void)layout {
	%orig;
	if (gItemViewClass && [self isKindOfClass:gItemViewClass]) {
		[gLiveNodes addObject:self];
		applyFade((ASDisplayNode *)self);
	}
}
%end
%end

%ctor {
	loadDeleted();
	gLiveNodes = [NSHashTable weakObjectsHashTable];
	gIdRegex = [NSRegularExpression regularExpressionWithPattern:@"id: (\\d+):(?:Id\\(rawValue: )?(-?\\d+)\\)?:(\\d+)_(-?\\d+)" options:0 error:nil];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		gItemViewClass = objc_getClass("ChatMessageItemView.ChatMessageItemView");
		if (!gItemViewClass) gItemViewClass = NSClassFromString(@"_TtC19ChatMessageItemView19ChatMessageItemView");
		TGXLog(@"TGExtra 1.6.0 itemClass=%@", gItemViewClass);
		if (!gItemViewClass) return;
		Ivar iv = class_getInstanceVariable(gItemViewClass, "item");
		if (iv) gItemOffset = ivar_getOffset(iv);
		TGXLog(@"item ivar=%p offset=%td deletedKeys=%lu", iv, gItemOffset, (unsigned long)gDeleted.count);
		[NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) { scanAll(); }];
		if (gItemOffset >= 0) {
			%init(TGXDeleted);
		}
	});
}
