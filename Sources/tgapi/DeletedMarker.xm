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

static void applyFade(ASDisplayNode *node) {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:kAntiDelete]) return;
	BOOL deleted = TGXIsDeletedKey(keyForNode(node));
	BOOL faded = [objc_getAssociatedObject(node, kTGXFadedKey) boolValue];
	if (deleted) {
		if (node.alpha > kDeletedAlpha + 0.01) node.alpha = kDeletedAlpha;
		if (!faded) objc_setAssociatedObject(node, kTGXFadedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	} else if (faded) {
		node.alpha = 1.0;
		objc_setAssociatedObject(node, kTGXFadedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
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
	gIdRegex = [NSRegularExpression regularExpressionWithPattern:@"id: (\\d+):(-?\\d+):(\\d+)_(-?\\d+)" options:0 error:nil];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		gItemViewClass = objc_getClass("ChatMessageItemView.ChatMessageItemView");
		if (!gItemViewClass) return;
		Ivar iv = class_getInstanceVariable(gItemViewClass, "item");
		if (iv) gItemOffset = ivar_getOffset(iv);
		if (gItemOffset >= 0) {
			%init(TGXDeleted);
		}
	});
}
