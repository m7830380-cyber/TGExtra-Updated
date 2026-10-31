#import "Headers.h"
#import "TLWalker.h"
#import "TLSchema.h"

static uint32_t TGXWalkOptions(void) {
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	uint32_t opts = 0;
	if ([d boolForKey:kDisableForwardRestriction]) opts |= TLW_NOFORWARDS;
	if ([d boolForKey:kAntiDelete]) opts |= TLW_ANTI_DELETE;
	if ([d boolForKey:kLocalPremium]) opts |= TLW_LOCAL_PREMIUM;
	return opts;
}

static void TGXRecordDeleted(const TLWalkStats *stats) {
	if (stats->deletedCount == 0) return;
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	NSMutableArray *log = [[d arrayForKey:kAntiDeleteLog] mutableCopy] ?: [NSMutableArray array];
	NSNumber *now = @((long long)[[NSDate date] timeIntervalSince1970]);
	for (uint32_t i = 0; i < stats->deletedCount; i++) {
		[log addObject:@{@"id": @(stats->deletedIds[i]), @"date": now}];
	}
	while (log.count > 500) [log removeObjectAtIndex:0];
	[d setObject:log forKey:kAntiDeleteLog];
}

// Returns a patched copy, or nil when nothing needs to change.
NSData *TGXPatchIncoming(NSData *input) {
	uint32_t opts = TGXWalkOptions();
	if (!opts || input.length < 4) return nil;
	NSMutableData *copy = [input mutableCopy];
	TLWalkStats stats;
	memset(&stats, 0, sizeof(stats));
	TLWalkPatch((uint8_t *)copy.mutableBytes, copy.length, opts, &stats);
	TGXRecordDeleted(&stats);
	return copy;
}

static NSData *TGXSafePatch(NSData *input) {
	@try {
		return TGXPatchIncoming(input);
	} @catch (NSException *e) {
		return nil;
	}
}

typedef id (^TGXParser)(NSData *);
static TGXParser TGXWrapParser(TGXParser original) {
	return ^id(NSData *inputData) {
		NSData *patched = TGXSafePatch(inputData);
		return original(patched ? patched : inputData);
	};
}

%hook MTRequest
%property (nonatomic, strong) NSData *fakeData;
%property (nonatomic, strong) NSNumber *functionID;

- (void)setPayload:(NSData *)payload metadata:(id)metadata shortMetadata:(id)shortMetadata responseParser:(id (^)(NSData *))responseParser {
	int32_t functionID = 0;
	if (payload.length >= 4) [payload getBytes:&functionID length:4];
	self.functionID = @(functionID);

	switch (functionID) {
		case TLFN_account_updateStatus:          handleOnlineStatus(self, payload); break;
		case TLFN_messages_setTyping:            handleSetTyping(self, payload); break;
		case TLFN_messages_readHistory:          handleMessageReadReceipt(self, payload); break;
		case TLFN_channels_readHistory:          handleChannelsReadReceipt(self, payload); break;
		case TLFN_messages_readDiscussion:       handleChannelsReadReceipt(self, payload); break;
		case TLFN_messages_readSavedHistory:     handleChannelsReadReceipt(self, payload); break;
		case TLFN_stories_readStories:           handleStoriesReadReceipt(self, payload); break;
		case TLFN_stories_incrementStoryViews:   handleStoryViews(self, payload); break;
		case TLFN_messages_readMessageContents:  handleReadContents(self, payload); break;
		case TLFN_channels_readMessageContents:  handleChannelReadContents(self, payload); break;
		case TLFN_messages_getSponsoredMessages: handleGetSponsoredMessages(self, payload); break;
		case TLFN_contacts_getSponsoredPeers:    handleGetSponsoredPeers(self, payload); break;
		default: break;
	}

	TGXParser hooked = responseParser;
	if (responseParser != NULL) hooked = TGXWrapParser(responseParser);
	%orig(payload, metadata, shortMetadata, hooked);
}
%end

// Requests answered locally (ghost mode): never sent to Telegram.
%hook MTRequestMessageService
- (void)addRequest:(MTRequest *)request {
	if (request.fakeData) {
		@try {
			if (request.completed) {
				MTRequestResponseInfo *info = [[%c(MTRequestResponseInfo) alloc] initWithNetworkType:1
					timestamp:[[NSDate date] timeIntervalSince1970] duration:0.045];
				id result = request.responseParser(request.fakeData);
				request.completed(result, info, nil);
			}
		} @catch (NSException *exception) {
			customLog2(@"TGExtra fake response failed: %@", exception);
		}
		return;
	}
	%orig;
}
%end

%group Updates
// Push updates (new messages, deletions, edits) arrive here already gunzipped.
%hook TGXSerialization
- (id)parseMessage:(NSData *)data {
	NSData *patched = TGXSafePatch(data);
	return %orig(patched ?: data);
}
%end
%end

%ctor {
	Class serialization = objc_getClass("TelegramCore.Serialization");
	if (!serialization) serialization = objc_getClass("_TtC12TelegramCore13Serialization");
	if (serialization) {
		%init(Updates, TGXSerialization = serialization);
	}
	%init();
}
