// Message text cache + edit history + deleted-message log (AyuGram style).
#import "Headers.h"
#import "TLWalker.h"

NSString *TGXMessageKey(int64_t channelId, int32_t messageId);

static dispatch_queue_t gQ;
static NSMutableDictionary<NSString *, NSArray *> *gTexts;   // key -> @[text, date]
static NSMutableArray<NSString *> *gOrder;                    // LRU-ish insertion order
static NSMutableArray<NSDictionary *> *gEdits;
static NSMutableArray<NSDictionary *> *gDeletedLog;
static BOOL gDirty;

#define MAX_TEXTS 30000
#define MAX_EDITS 3000
#define MAX_DELETED 3000

static NSString *storePath(void) {
	NSString *dir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"TGExtra"];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	return [dir stringByAppendingPathComponent:@"store.plist"];
}

static void scheduleSave(void) {
	if (gDirty) return;
	gDirty = YES;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), gQ, ^{
		gDirty = NO;
		NSDictionary *d = @{@"texts": gTexts, @"order": gOrder, @"edits": gEdits, @"deleted": gDeletedLog};
		NSData *data = [NSPropertyListSerialization dataWithPropertyList:d format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
		[data writeToFile:storePath() atomically:YES];
	});
}

static void onMessage(int64_t channelId, int32_t messageId, int32_t date, int32_t editDate, const char *text, size_t len) {
	NSString *t = [[NSString alloc] initWithBytes:text length:len encoding:NSUTF8StringEncoding] ?: @"";
	NSString *key = TGXMessageKey(channelId, messageId);
	dispatch_async(gQ, ^{
		NSArray *prev = gTexts[key];
		if (prev && ![prev[0] isEqualToString:t] && editDate != 0 &&
		    [[NSUserDefaults standardUserDefaults] boolForKey:kEditHistory]) {
			[gEdits addObject:@{@"key": key, @"old": prev[0], @"new": t, @"date": @(editDate)}];
			while (gEdits.count > MAX_EDITS) [gEdits removeObjectAtIndex:0];
		}
		if (!prev) {
			[gOrder addObject:key];
			while (gOrder.count > MAX_TEXTS) { [gTexts removeObjectForKey:gOrder[0]]; [gOrder removeObjectAtIndex:0]; }
		}
		if (!prev || ![prev[0] isEqualToString:t]) {
			gTexts[key] = @[t, @(date)];
			scheduleSave();
		}
	});
}

void TGXStoreDeleted(NSString *key) {
	dispatch_async(gQ, ^{
		NSArray *prev = gTexts[key];
		[gDeletedLog addObject:@{@"key": key, @"text": prev ? prev[0] : @"(text not cached - chat was not opened before deletion)",
		                          @"date": @((long long)[[NSDate date] timeIntervalSince1970])}];
		while (gDeletedLog.count > MAX_DELETED) [gDeletedLog removeObjectAtIndex:0];
		scheduleSave();
	});
}

NSArray *TGXEditHistory(void) { __block NSArray *r; dispatch_sync(gQ, ^{ r = [gEdits copy]; }); return r; }
NSArray *TGXDeletedLog(void) { __block NSArray *r; dispatch_sync(gQ, ^{ r = [gDeletedLog copy]; }); return r; }
void TGXClearLogs(void) { dispatch_sync(gQ, ^{ [gEdits removeAllObjects]; [gDeletedLog removeAllObjects]; scheduleSave(); }); }

__attribute__((constructor)) static void TGXStoreInit(void) {
	gQ = dispatch_queue_create("dev.magician.tgextra.store", DISPATCH_QUEUE_SERIAL);
	NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:storePath()];
	gTexts = [d[@"texts"] mutableCopy] ?: [NSMutableDictionary dictionary];
	gOrder = [d[@"order"] mutableCopy] ?: [NSMutableArray array];
	gEdits = [d[@"edits"] mutableCopy] ?: [NSMutableArray array];
	gDeletedLog = [d[@"deleted"] mutableCopy] ?: [NSMutableArray array];
	TLWSetMessageCallback(onMessage);
}

// All versions of one message, oldest first: @[@{text,date}...]; empty if never edited.
NSArray *TGXVersionsForKey(NSString *key) {
	__block NSMutableArray *r = [NSMutableArray array];
	dispatch_sync(gQ, ^{
		for (NSDictionary *e in gEdits) {
			if (![e[@"key"] isEqualToString:key]) continue;
			if (r.count == 0) [r addObject:@{@"text": e[@"old"], @"date": gTexts[key] ? gTexts[key][1] : e[@"date"]}];
			[r addObject:@{@"text": e[@"new"], @"date": e[@"date"]}];
		}
	});
	return r;
}
