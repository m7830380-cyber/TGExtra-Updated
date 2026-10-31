// Font override + streamer mode.
//
// Font: Telegram (Display/AsyncDisplayKit) builds every UI font through
// UIFont systemFontOfSize:/weight:, boldSystemFontOfSize:, italicSystemFontOfSize:
// and Font.with(...) which ends in +[UIFont fontWithDescriptor:size:]. Swapping
// those to the chosen family + optional scale covers chats, lists and settings.
//
// Streamer mode: blurs the app while the screen is being recorded/mirrored and in
// the app switcher snapshot.
#import "Headers.h"
#import <objc/runtime.h>

static NSString *fontName(void) {
	NSString *n = [[NSUserDefaults standardUserDefaults] stringForKey:kCustomFont];
	return n.length ? n : nil;
}

static CGFloat fontScale(void) {
	double s = [[NSUserDefaults standardUserDefaults] doubleForKey:kFontScale];
	return (s >= 0.7 && s <= 1.6) ? s : 1.0;
}

static UIFont *custom(CGFloat size, UIFontWeight weight, BOOL italic) {
	NSString *family = fontName();
	if (!family) return nil;
	size *= fontScale();
	UIFontDescriptor *d = [UIFontDescriptor fontDescriptorWithFontAttributes:@{
		UIFontDescriptorFamilyAttribute: family,
		UIFontDescriptorTraitsAttribute: @{UIFontWeightTrait: @(weight)}
	}];
	if (italic) d = [d fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic] ?: d;
	UIFont *f = [UIFont fontWithDescriptor:d size:size];
	return [f.familyName isEqualToString:family] ? f : nil;
}

%group Fonts
%hook UIFont
+ (UIFont *)systemFontOfSize:(CGFloat)size {
	UIFont *f = custom(size, UIFontWeightRegular, NO);
	if (f) return f;
	CGFloat scaled = size * fontScale();
	return %orig(scaled);
}
+ (UIFont *)systemFontOfSize:(CGFloat)size weight:(UIFontWeight)w {
	UIFont *f = custom(size, w, NO);
	if (f) return f;
	CGFloat scaled = size * fontScale();
	return %orig(scaled, w);
}
+ (UIFont *)boldSystemFontOfSize:(CGFloat)size {
	UIFont *f = custom(size, UIFontWeightBold, NO);
	if (f) return f;
	CGFloat scaled = size * fontScale();
	return %orig(scaled);
}
+ (UIFont *)italicSystemFontOfSize:(CGFloat)size {
	UIFont *f = custom(size, UIFontWeightRegular, YES);
	if (f) return f;
	CGFloat scaled = size * fontScale();
	return %orig(scaled);
}
%end
%end

// ---------- Streamer mode ----------
static UIView *gPrivacyCover;

static void coverWindow(BOOL show) {
	UIWindow *w = UIApplication.sharedApplication.keyWindow;
	if (!w) return;
	if (show) {
		if (gPrivacyCover.superview) return;
		gPrivacyCover = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]];
		gPrivacyCover.frame = w.bounds;
		gPrivacyCover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[w addSubview:gPrivacyCover];
	} else {
		[gPrivacyCover removeFromSuperview];
	}
}

static void streamerSetup(void) {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) {
		coverWindow(YES);
	}];
	[nc addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) {
		coverWindow(UIScreen.mainScreen.isCaptured);
	}];
	[nc addObserverForName:UIScreenCapturedDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) {
		coverWindow(UIScreen.mainScreen.isCaptured);
	}];
}

%ctor {
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	if (fontName() || fontScale() != 1.0) {
		%init(Fonts);
	}
	if ([d boolForKey:kStreamerMode]) {
		dispatch_async(dispatch_get_main_queue(), ^{ streamerSetup(); });
	}
}
