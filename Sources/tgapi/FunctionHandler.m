#import "Headers.h"
#import "TLSchema.h"

NSData *boolTrue() {
    uint8_t bytes[] = {0xB5, 0x75, 0x72, 0x99}; // boolTrue#997275b5
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

NSData *boolFalse() {
    uint8_t bytes[] = {0x37, 0x97, 0x79, 0xBC}; // boolFalse#bc799737
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

// Handlers
void handleOnlineStatus(MTRequest *request, NSData *payload) {
	
	NSData *isOfflineData = [payload subdataWithRange:NSMakeRange(payload.length - 4, 4)];
	uint32_t isOffline = 0;
	[isOfflineData getBytes:&isOffline length:4];
	
	if (isOffline == 3162085175) { // Online (BOOL false)
		if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableOnlineStatus]) {
			request.fakeData = boolTrue();
		}
	}
	
}

void read_Input_Peer(NSData *data, int *offset) {
	#define InputPeerEmpty 2134579434
	#define InputPeerSelf 2107670217
	#define InputPeerChat 900291769
	#define InputPeerUser -571955892
	#define InputPeerChannel 666680316
	#define InputPeerUserFromChannel -1468331492 /* inputPeerUserFromMessage */
	#define InputPeerChannelFromMessage -1121318848
	
	int32_t peerConstructorID = 0;
	[data getBytes:&peerConstructorID range:NSMakeRange(*offset, 4)];
	*offset += 4;
	
	switch (peerConstructorID) {
		case InputPeerEmpty:
		    return;
		case InputPeerSelf:
		    return;
		case InputPeerChat:
		    *offset += 8;
			return;
		case InputPeerUser:
		    *offset += 16;
			return;
		case InputPeerChannel:
		    *offset += 16;
			return;
		case InputPeerUserFromChannel:
		    read_Input_Peer(data, offset);
		    *offset += 12;
			return;
		case InputPeerChannelFromMessage:
		    read_Input_Peer(data, offset);
		    *offset += 12;
			return;
		default :
		    return;
	}
}

void handleSetTyping(MTRequest *request, NSData *payload) {
	
	int offset = 0; 
	offset += 4; // Skip First 4 Bytes of constructor id;
	int32_t flags = 0;
	[payload getBytes:&flags range:NSMakeRange(offset, 4)];
	offset += 4;
	
	read_Input_Peer(payload, &offset); // Read Peer
	
	if ((flags & (1 << 0)) != 0) {
		offset += 4; // Topic id
	}
	
	int32_t actionID = 0;
	[payload getBytes:&actionID range:NSMakeRange(offset, 4)];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	bool shouldBlockAction = false;
	
	//customLog(@"Handle Set Typing action : %d actionData:%@", actionID, [payload description]);
	switch (actionID) {
		case TLA_sendMessageTypingAction:
		shouldBlockAction = [defaults boolForKey:kDisableTypingStatus];
		  break;
		case TLA_sendMessageRecordVideoAction:
		  shouldBlockAction = [defaults boolForKey:kDisableRecordingVideoStatus];
		  break;
		case TLA_sendMessageUploadVideoAction:
		  shouldBlockAction = [defaults boolForKey:kDisableUploadingVideoStatus];
		  break;
		case TLA_sendMessageRecordAudioAction:
		  shouldBlockAction = [defaults boolForKey:kDisableRecordingVoiceStatus];
		  break;
		case TLA_sendMessageUploadAudioAction:
		  shouldBlockAction = [defaults boolForKey:kDisableUploadingVoiceStatus];
		  break;
		case TLA_sendMessageUploadPhotoAction:
		  shouldBlockAction = [defaults boolForKey:kDisableUploadingPhotoStatus];
		  break;
		case TLA_sendMessageUploadDocumentAction:
		  shouldBlockAction = [defaults boolForKey:kDisableUploadingFileStatus];
		  break;
		case TLA_sendMessageGeoLocationAction:
		  shouldBlockAction = [defaults boolForKey:kDisableChoosingLocationStatus];
		  break;
		case TLA_sendMessageChooseContactAction:
		  shouldBlockAction = [defaults boolForKey:kDisableChoosingContactStatus];
		  break;
		case TLA_sendMessageGamePlayAction:
		  shouldBlockAction = [defaults boolForKey:kDisablePlayingGameStatus];
		  break;
		case TLA_sendMessageRecordRoundAction:
		  shouldBlockAction = [defaults boolForKey:kDisableRecordingRoundVideoStatus];
		  break;
		case TLA_sendMessageUploadRoundAction:
		  shouldBlockAction = [defaults boolForKey:kDisableUploadingRoundVideoStatus];
		  break;
		case TLA_speakingInGroupCallAction:
		  shouldBlockAction = [defaults boolForKey:kDisableSpeakingInGroupCallStatus];
		  break;
		case TLA_sendMessageHistoryImportAction:
		  shouldBlockAction = [defaults boolForKey:@"reserverHistroyImport"];
		  break;
		case TLA_sendMessageChooseStickerAction:
		  shouldBlockAction = [defaults boolForKey:kDisableChoosingStickerStatus];
		  break;
		case TLA_sendMessageEmojiInteraction:
		  shouldBlockAction = [defaults boolForKey:kDisableEmojiInteractionStatus];
		  break;
		case TLA_sendMessageEmojiInteractionSeen:
		  shouldBlockAction = [defaults boolForKey:kDisableEmojiAcknowledgementStatus];
		  break;
	}
	
	if (shouldBlockAction) {
		request.fakeData = boolTrue();
	}
}

static NSData *affectedMessages(void) {
	uint8_t bytes[12] = {0x85, 0x91, 0xD1, 0x84, 0,0,0,0, 0,0,0,0}; // messages.affectedMessages pts=0 pts_count=0
	return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

static NSData *emptyVector(void) {
	uint8_t bytes[8] = {0x15, 0xC4, 0xB5, 0x1C, 0,0,0,0};
	return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

static BOOL pref(NSString *key) { return [[NSUserDefaults standardUserDefaults] boolForKey:key]; }

void handleMessageReadReceipt(MTRequest *request, NSData *payload) {
	if (pref(kDisableMessageReadReceipt)) request.fakeData = affectedMessages();
}

void handleChannelsReadReceipt(MTRequest *request, NSData *payload) {
	if (pref(kDisableMessageReadReceipt)) request.fakeData = boolTrue();
}

void handleStoriesReadReceipt(MTRequest *request, NSData *payload) {
	if (pref(kDisableStoriesReadReceipt)) request.fakeData = emptyVector();
}

void handleStoryViews(MTRequest *request, NSData *payload) {
	if (pref(kDisableStoriesReadReceipt)) request.fakeData = boolTrue();
}

// Voice/video notes "listened" + mentions/reactions read markers.
void handleReadContents(MTRequest *request, NSData *payload) {
	if (pref(kDisableReadContents)) request.fakeData = affectedMessages();
}

void handleChannelReadContents(MTRequest *request, NSData *payload) {
	if (pref(kDisableReadContents)) request.fakeData = boolTrue();
}

void handleGetSponsoredMessages(MTRequest *request, NSData *payload) {
	if (pref(kDisableAllAds)) {
		uint32_t v = TLC_messages_sponsoredMessagesEmpty;
		request.fakeData = [NSData dataWithBytes:&v length:4];
	}
}

void handleGetSponsoredPeers(MTRequest *request, NSData *payload) {
	if (pref(kDisableAllAds)) {
		uint32_t v = TLC_contacts_sponsoredPeersEmpty;
		request.fakeData = [NSData dataWithBytes:&v length:4];
	}
}
