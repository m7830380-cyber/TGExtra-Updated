// AyuGram-style "Edits History": every version of a message as a chat bubble,
// oldest first, with the time it was posted/edited.
// Plus custom font import (.ttf/.otf via document picker, registered with CoreText).
#import "Headers.h"
#import <CoreText/CoreText.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface TGXEditHistoryVC : UITableViewController
@property (nonatomic, copy) NSArray *versions;
@end

@implementation TGXEditHistoryVC
- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Edits History";
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
	self.tableView.rowHeight = UITableViewAutomaticDimension;
	self.tableView.estimatedRowHeight = 60;
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.versions.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
	UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"b"];
	UILabel *text, *meta; UIView *bubble;
	if (!c) {
		c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"b"];
		c.backgroundColor = UIColor.clearColor;
		c.selectionStyle = UITableViewCellSelectionStyleNone;
		bubble = [UIView new]; bubble.tag = 1;
		bubble.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
		bubble.layer.cornerRadius = 16;
		bubble.translatesAutoresizingMaskIntoConstraints = NO;
		text = [UILabel new]; text.tag = 2; text.numberOfLines = 0;
		text.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
		meta = [UILabel new]; meta.tag = 3;
		meta.font = [UIFont systemFontOfSize:11]; meta.textColor = UIColor.secondaryLabelColor;
		meta.textAlignment = NSTextAlignmentRight;
		for (UIView *v in @[text, meta]) { v.translatesAutoresizingMaskIntoConstraints = NO; [bubble addSubview:v]; }
		[c.contentView addSubview:bubble];
		[NSLayoutConstraint activateConstraints:@[
			[bubble.leadingAnchor constraintEqualToAnchor:c.contentView.leadingAnchor constant:12],
			[bubble.trailingAnchor constraintLessThanOrEqualToAnchor:c.contentView.trailingAnchor constant:-60],
			[bubble.topAnchor constraintEqualToAnchor:c.contentView.topAnchor constant:4],
			[bubble.bottomAnchor constraintEqualToAnchor:c.contentView.bottomAnchor constant:-4],
			[text.leadingAnchor constraintEqualToAnchor:bubble.leadingAnchor constant:12],
			[text.trailingAnchor constraintEqualToAnchor:bubble.trailingAnchor constant:-12],
			[text.topAnchor constraintEqualToAnchor:bubble.topAnchor constant:8],
			[meta.topAnchor constraintEqualToAnchor:text.bottomAnchor constant:2],
			[meta.leadingAnchor constraintGreaterThanOrEqualToAnchor:bubble.leadingAnchor constant:12],
			[meta.trailingAnchor constraintEqualToAnchor:bubble.trailingAnchor constant:-10],
			[meta.bottomAnchor constraintEqualToAnchor:bubble.bottomAnchor constant:-6],
		]];
	}
	bubble = [c.contentView viewWithTag:1];
	text = (UILabel *)[bubble viewWithTag:2]; meta = (UILabel *)[bubble viewWithTag:3];
	NSDictionary *v = self.versions[ip.row];
	text.text = [v[@"text"] length] ? v[@"text"] : @"(media / empty)";
	NSDateFormatter *f = [NSDateFormatter new];
	f.dateStyle = NSDateFormatterShortStyle; f.timeStyle = NSDateFormatterShortStyle;
	NSString *when = [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:[v[@"date"] doubleValue]]];
	BOOL last = ip.row == (NSInteger)self.versions.count - 1;
	meta.text = ip.row == 0 ? [NSString stringWithFormat:@"original · %@", when]
	          : [NSString stringWithFormat:@"%@edited · %@", last ? @"current · " : @"", when];
	bubble.layer.borderWidth = last ? 1 : 0;
	bubble.layer.borderColor = [UIColor systemPinkColor].CGColor;
	return c;
}
@end

static UIViewController *topVC(void) {
	UIViewController *vc = UIApplication.sharedApplication.keyWindow.rootViewController;
	while (vc.presentedViewController) vc = vc.presentedViewController;
	return vc;
}

void TGXShowEditHistory(NSArray *versions) {
	TGXEditHistoryVC *vc = [[TGXEditHistoryVC alloc] initWithStyle:UITableViewStylePlain];
	vc.versions = versions;
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
	if (@available(iOS 15.0, *)) nav.sheetPresentationController.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
	[topVC() presentViewController:nav animated:YES completion:nil];
}

// ---------- Font import ----------
static NSString *fontsDir(void) {
	NSString *d = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"TGExtra/Fonts"];
	[[NSFileManager defaultManager] createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:nil];
	return d;
}

// Registers a font file; returns its family name or nil.
static NSString *registerFont(NSString *path) {
	NSURL *url = [NSURL fileURLWithPath:path];
	CFErrorRef err = NULL;
	CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, &err);
	if (err) CFRelease(err); // already-registered is fine
	NSArray *descs = CFBridgingRelease(CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url));
	if (!descs.count) return nil;
	return CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)descs[0], kCTFontFamilyNameAttribute));
}

NSArray<NSString *> *TGXImportedFontFamilies(void) {
	NSMutableOrderedSet *fams = [NSMutableOrderedSet orderedSet];
	for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:fontsDir() error:nil]) {
		NSString *fam = registerFont([fontsDir() stringByAppendingPathComponent:f]);
		if (fam) [fams addObject:fam];
	}
	return fams.array;
}

@interface TGXFontImporter : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, copy) void (^done)(NSString *family);
@end

@implementation TGXFontImporter
- (void)documentPicker:(UIDocumentPickerViewController *)c didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
	NSString *family = nil;
	for (NSURL *u in urls) {
		BOOL scoped = [u startAccessingSecurityScopedResource];
		NSString *dst = [fontsDir() stringByAppendingPathComponent:u.lastPathComponent];
		[[NSFileManager defaultManager] removeItemAtPath:dst error:nil];
		[[NSFileManager defaultManager] copyItemAtURL:u toURL:[NSURL fileURLWithPath:dst] error:nil];
		if (scoped) [u stopAccessingSecurityScopedResource];
		family = registerFont(dst) ?: family;
	}
	if (self.done) self.done(family);
	self.done = nil;
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)c { self.done = nil; }
@end

void TGXImportFont(UIViewController *from, void (^done)(NSString *family)) {
	static TGXFontImporter *importer;
	importer = [TGXFontImporter new];
	importer.done = done;
	NSArray *types = @[[UTType typeWithFilenameExtension:@"ttf"], [UTType typeWithFilenameExtension:@"otf"], UTTypeFont];
	UIDocumentPickerViewController *p = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:[types filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != nil"]] asCopy:YES];
	p.allowsMultipleSelection = YES;
	p.delegate = importer;
	[from presentViewController:p animated:YES completion:nil];
}

__attribute__((constructor)) static void TGXRegisterImportedFonts(void) {
	TGXImportedFontFamilies(); // must be registered before Appearance resolves the family
}
