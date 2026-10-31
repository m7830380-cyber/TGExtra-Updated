#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "Icons.h"
#import "Headers.h"

#define TGLoc(key) [TGExtraLocalization localizedStringForKey:(key)]

@interface TGExtra ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSString *cacheSize;
@end

@implementation TGExtra

- (void)viewDidLoad {

	[self setupTableView];
	[self setupIconAsHeader];
	[self setupApplyButton];
	self.title = @"TGExtra by dev.magician";

	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangeLanguage)
                                                 name:@"LanguageChangedNotification"
                                               object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangeFakeLocation)
                                                 name:@"TGExtraLocationChanged"
                                               object:nil];
}

- (void)didChangeLanguage {
	[self.tableView reloadData];
}

- (void)didChangeFakeLocation {
	NSIndexSet *section = [NSIndexSet indexSetWithIndex:4];
	[self.tableView reloadSections:section withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)setupTableView {
	self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
	self.tableView.delegate = self;
	self.tableView.dataSource = self;
	self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

	[self.view addSubview:self.tableView];

	[NSLayoutConstraint activateConstraints:@[
    	[self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
		[self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
		[self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
		[self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
	]];
}

- (void)setupIconAsHeader {
    UIView *logoContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 100)];

    // Logo Image
	//NSString *imagePath = [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"Choco.png"];
	NSData *imageData = [[NSData alloc] initWithBase64EncodedString:DEVLOGOPNG options:NSDataBase64DecodingIgnoreUnknownCharacters];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage imageWithData:imageData]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.layer.cornerRadius = 100 / 4;
	iconView.userInteractionEnabled = YES;
    iconView.clipsToBounds = YES;
    iconView.contentMode = UIViewContentModeScaleAspectFill;

    [logoContainer addSubview:iconView];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.centerYAnchor constraintEqualToAnchor:logoContainer.centerYAnchor],
        [iconView.centerXAnchor constraintEqualToAnchor:logoContainer.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:100],
        [iconView.heightAnchor constraintEqualToConstant:100]
    ]];

    self.tableView.tableHeaderView = logoContainer;
}

- (void)setupApplyButton {
	UIButton *applyChangesButton = [UIButton buttonWithType:UIButtonTypeSystem];
	UIImage *applyImage = [UIImage systemImageNamed:@"checkmark.square"];
	applyImage = [applyImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	applyChangesButton.tintColor = [UIColor systemPinkColor];
	[applyChangesButton setImage:applyImage forState:UIControlStateNormal];
	[applyChangesButton addTarget:self action:@selector(applyChanges) forControlEvents:UIControlEventTouchUpInside];
	UIBarButtonItem *applyButtonItem = [[UIBarButtonItem alloc] initWithCustomView:applyChangesButton];
	self.navigationItem.rightBarButtonItems = @[applyButtonItem];
}

- (void)applyChanges {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TGLoc(@"APPLY")
                                                                   message:TGLoc(@"APPLY_CHANGES")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:TGLoc(@"OK")
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
		[[UIApplication sharedApplication] performSelector:@selector(suspend)];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			exit(0);
		});
	}];

    [alert addAction:okAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:TGLoc(@"CANCEL")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (UIColor *)dynamicColorBW {
    static dispatch_once_t token;
    static UIColor *cached;
    dispatch_once(&token, ^{
        cached = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
            if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor whiteColor];
            } else {
                return [UIColor blackColor];
            }
        }];
    });
    return cached;
}

# pragma mark - UITableViewDataSource

typedef NS_ENUM(NSInteger, TABLE_VIEW_SECTIONS) {
    GHOST_MODE = 0,
    READ_RECEIPT = 1,
    MISC = 2,
    FILE_FIXER = 3,
    FAKE_LOCATION = 4,
    LANGUAGE = 5,
	CREDITS = 6,
	EXTRAS = 7,
};

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 8;
}

static NSInteger TGXMapSection(NSInteger s) { return s == 6 ? 7 : (s == 7 ? 6 : s); }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	section = TGXMapSection(section);
	switch (section) {
		case GHOST_MODE:
		   return 17;
		case READ_RECEIPT:
		   return 2;
		case MISC:
		   return 5;
		case FILE_FIXER:
		   return 2;
		case FAKE_LOCATION:
		   return 2;
		case LANGUAGE:
		   return 1;
		case CREDITS:
		   return 2;
		case EXTRAS:
		   return 6;
		default:
		   return 0;
	}
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	section = TGXMapSection(section);

	switch (section) {
		case GHOST_MODE:
		   return TGLoc(@"GHOST_MODE_SECTION_HEADER");
		case READ_RECEIPT:
		   return TGLoc(@"READ_RECEIPT_SECTION_HEADER");
		case MISC:
		   return TGLoc(@"MISC_SECTION_HEADER");
		case FILE_FIXER:
		   return TGLoc(@"FILE_FIXER_SECTION_HEADER");
		case FAKE_LOCATION:
		   return TGLoc(@"FAKE_LOCATION_SECTION_HEADER");
		case LANGUAGE:
		   return TGLoc(@"LANGUAGE_SECTION_HEADER");
		case CREDITS:
		   return TGLoc(@"CREDITS_SECTION_HEADER");
		case EXTRAS:
		   return @"Extras";
		default:
		   return nil;
	}
	return nil;
}

- (UITableViewCell *)switchCellFromTableView:(UITableView *)tableView {
	UITableViewCell *switchCell = [tableView dequeueReusableCellWithIdentifier:@"switchCell"];
	if (!switchCell) {
		switchCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"switchCell"];
	}

	return switchCell;
}

- (UITableViewCell *)normalCellFromTableView:(UITableView *)tableView {
	UITableViewCell *normalCell = [tableView dequeueReusableCellWithIdentifier:@"normalCell"];
	if (!normalCell) {
		normalCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"normalCell"];
	}

	return normalCell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSIndexPath *visibleIndexPath = indexPath;
	indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:TGXMapSection(indexPath.section)];
	UITableViewCell *cell;

	if (indexPath.section == 0) { // GHOST MOODE
		cell = [self switchCellFromTableView:tableView];
		cell.imageView.image = nil;

		if (indexPath.row == 0) {
			cell.textLabel.text = TGLoc(@"DISABLE_ONLINE_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_ONLINE_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 1) {
			cell.textLabel.text = TGLoc(@"DISABLE_TYPING_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_TYPING_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 2) {
			cell.textLabel.text = TGLoc(@"DISABLE_RECORDING_VIDEO_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_RECORDING_VIDEO_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 3) {
			cell.textLabel.text = TGLoc(@"DISABLE_UPLOADING_VIDEO_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_UPLOADING_VIDEO_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 4) {
			cell.textLabel.text = TGLoc(@"DISABLE_VC_MESSAGE_RECORDING_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_VC_MESSAGE_RECORDING_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 5) {
			cell.textLabel.text = TGLoc(@"DISABLE_VC_MESSAGE_UPLOADING_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_VC_MESSAGE_UPLOADING_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 6) {
			cell.textLabel.text = TGLoc(@"DISABLE_UPLOADING_PHOTO_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_UPLOADING_PHOTO_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 7) {
			cell.textLabel.text = TGLoc(@"DISABLE_UPLOADING_FILE_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_UPLOADING_FILE_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 8) {
			cell.textLabel.text = TGLoc(@"DISABLE_CHOOSING_LOCATION_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_CHOOSING_LOCATION_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 9) {
			cell.textLabel.text = TGLoc(@"DISABLE_CHOOSING_CONTACT_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_CHOOSING_CONTACT_SUBTITLE");
		}
		else if (indexPath.row == 10) {
			cell.textLabel.text = TGLoc(@"DISABLE_PLAYING_GAME_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_PLAYING_GAME_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 11) {
			cell.textLabel.text = TGLoc(@"DISABLE_RECORDING_ROUND_VIDEO_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_RECORDING_ROUND_VIDEO_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 12) {
			cell.textLabel.text = TGLoc(@"DISABLE_UPLOADING_ROUND_VIDEO_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_UPLOADING_ROUND_VIDEO_STATUS_TITLE");
		}
		else if (indexPath.row == 13) {
			cell.textLabel.text = TGLoc(@"DISABLE_SPEAKING_IN_GROUP_CALL_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_SPEAKING_IN_GROUP_CALL_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 14) {
			cell.textLabel.text = TGLoc(@"DISABLE_CHOOSING_STICKER_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_CHOOSING_STICKER_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 15) {
			cell.textLabel.text = TGLoc(@"DISABLE_EMOJI_INTERACTION_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_EMOJI_INTERACTION_STATUS_SUBTITLE");
		}
		else if (indexPath.row == 16) {
			cell.textLabel.text = TGLoc(@"DISABLE_EMOJI_ACKNOWLEDGEMENT_STATUS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_EMOJI_ACKNOWLEDGEMENT_STATUS_SUBTITLE");
		}

		UISwitch *toggle = (UISwitch *)cell.accessoryView;
		if (!toggle || ![toggle isKindOfClass:[UISwitch class]]) {
			toggle = [[UISwitch alloc] init];
		}

		NSString *switchKey = [self switchKeyForIndexPath:indexPath];
		toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:switchKey];
		[toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
		toggle.tag = 1000 + (indexPath.section *1000) + indexPath.row;
		cell.accessoryView = toggle;

		cell.textLabel.numberOfLines = 0;
		cell.detailTextLabel.numberOfLines = 0;
		return cell;

	}
	else if (indexPath.section == 1) { // Read Receipts
		cell = [self switchCellFromTableView:tableView];
		cell.imageView.image = nil;

		if (indexPath.row == 0) {
			cell.textLabel.text = TGLoc(@"DISABLE_MESSAGE_READ_RECEIPT_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_MESSAGE_READ_RECEIPT_SUBTITLE");
		}
		else if (indexPath.row == 1) {
			cell.textLabel.text = TGLoc(@"DISABLE_STORY_READ_RECEIPT_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_STORY_READ_RECEIPT_SUBTITLE");
		}

		UISwitch *toggle = (UISwitch *)cell.accessoryView;
		if (!toggle || ![toggle isKindOfClass:[UISwitch class]]) {
			toggle = [[UISwitch alloc] init];
		}

		NSString *switchKey = [self switchKeyForIndexPath:indexPath];
		toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:switchKey];
		[toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
		toggle.tag = 1000 + (indexPath.section *1000) + indexPath.row;
		cell.accessoryView = toggle;

		cell.textLabel.numberOfLines = 0;
		cell.detailTextLabel.numberOfLines = 0;
		return cell;
	}
	else if (indexPath.section == 2) { // MISC
		cell = [self switchCellFromTableView:tableView];
		cell.imageView.image = nil;

		if (indexPath.row == 0) {
			cell.textLabel.text = TGLoc(@"DISABLE_ALL_ADS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_ALL_ADS_SUBTITLE");
		}
		else if (indexPath.row == 1) {
			cell.textLabel.text = TGLoc(@"ENABLE_SAVING_PROTECTED_CONTENT_TITLE");
			cell.detailTextLabel.text = TGLoc(@"ENABLE_SAVING_PROTECTED_CONTENT_SUBTITLE");
		}
		else if (indexPath.row == 2) {
			cell.textLabel.text = TGLoc(@"ANTI_DELETE_TITLE");
			cell.detailTextLabel.text = TGLoc(@"ANTI_DELETE_SUBTITLE");
		}
		else if (indexPath.row == 3) {
			cell.textLabel.text = TGLoc(@"DISABLE_READ_CONTENTS_TITLE");
			cell.detailTextLabel.text = TGLoc(@"DISABLE_READ_CONTENTS_SUBTITLE");
		}
		else if (indexPath.row == 4) {
			cell.textLabel.text = TGLoc(@"LOCAL_PREMIUM_TITLE");
			cell.detailTextLabel.text = TGLoc(@"LOCAL_PREMIUM_SUBTITLE");
		}

		UISwitch *toggle = (UISwitch *)cell.accessoryView;
		if (!toggle || ![toggle isKindOfClass:[UISwitch class]]) {
			toggle = [[UISwitch alloc] init];
		}

		NSString *switchKey = [self switchKeyForIndexPath:indexPath];
		toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:switchKey];
		[toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
		toggle.tag = 1000 + (indexPath.section *1000) + indexPath.row;
		cell.accessoryView = toggle;

		cell.textLabel.numberOfLines = 0;
		cell.detailTextLabel.numberOfLines = 0;
		return cell;

	}
	if (indexPath.section == 3) { // File Picker Fix
		if (indexPath.row ==0) { //Enable File Picker Fix
			cell = [self switchCellFromTableView:tableView];

			cell.imageView.image = [UIImage systemImageNamed:@"folder.fill.badge.gear"];
			cell.imageView.tintColor = [self dynamicColorBW];
			cell.textLabel.text = TGLoc(@"FIX_FILE_PICKER_TITLE");
			cell.detailTextLabel.text = TGLoc(@"FIX_FILE_PICKER_SUBTITLE");

			UISwitch *toggle = (UISwitch *)cell.accessoryView;
			if (!toggle || ![toggle isKindOfClass:[UISwitch class]]) {
				toggle = [[UISwitch alloc] init];
			}

			NSString *switchKey = [self switchKeyForIndexPath:indexPath];
			toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:switchKey];
			[toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
			toggle.tag = 1000 + (indexPath.section *1000) + indexPath.row;
			cell.accessoryView = toggle;

			cell.textLabel.numberOfLines = 0;
			cell.detailTextLabel.numberOfLines = 0;
			return cell;
		}

		if (indexPath.row == 1) {
			cell = [self normalCellFromTableView:tableView];
			cell.imageView.image = nil;

		    cell.textLabel.text = TGLoc(@"CLEAR_FILE_PICKER_CACHE_TITLE");
		    cell.detailTextLabel.text = TGLoc(@"CLEAR_FILE_PICKER_CACHE_SUBTITLE");
		    cell.imageView.image = [UIImage systemImageNamed:@"trash"];
		    cell.imageView.tintColor = [UIColor redColor];

		    // Initially show a UIActivityIndicator
		    UIActivityIndicatorView *loadingIcon = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
		    [loadingIcon startAnimating];
		    cell.accessoryView = loadingIcon;

		    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
				if (!self.cacheSize) {
					self.cacheSize = [self sizeOfUglyFileFixDirectory];
				}

		        dispatch_async(dispatch_get_main_queue(), ^{
					UITableViewCell *currentCell = [tableView cellForRowAtIndexPath:visibleIndexPath];
					if (currentCell == cell) {
						UILabel *sizeLabel = [[UILabel alloc] init];
						sizeLabel.text = self.cacheSize;
						cell.accessoryView = sizeLabel;

						[sizeLabel sizeToFit];
					}
		        });
		    });

			cell.textLabel.numberOfLines = 0;
			cell.detailTextLabel.numberOfLines = 0;
			return cell;
		}
	}

	if (indexPath.section == 4) { // Fake Location
		if (indexPath.row ==0) {
			cell = [self switchCellFromTableView:tableView];

			cell.imageView.image = [UIImage systemImageNamed:@"location.fill"];
			cell.imageView.tintColor = [self dynamicColorBW];
			cell.textLabel.text = TGLoc(@"ENABLE_FAKE_LOCATION_TITLE");
			cell.detailTextLabel.text = TGLoc(@"ENABLE_FAKE_LOCATION_SUBTITLE");

			UISwitch *toggle = (UISwitch *)cell.accessoryView;
			if (!toggle || ![toggle isKindOfClass:[UISwitch class]]) {
				toggle = [[UISwitch alloc] init];
			}

			NSString *switchKey = [self switchKeyForIndexPath:indexPath];
			toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:switchKey];
			[toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
			toggle.tag = 1000 + (indexPath.section *1000) + indexPath.row;
			cell.accessoryView = toggle;
		}

		if (indexPath.row == 1) {
			cell = [self normalCellFromTableView:tableView];

			cell.imageView.image = [UIImage systemImageNamed:@"location.fill"];
			cell.imageView.tintColor = [self dynamicColorBW];
			cell.textLabel.text = TGLoc(@"SELECT_FAKE_LOCATION_TITLE");

			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			CGFloat savedLongitude = [defaults floatForKey:FAKE_LONGITUDE_KEY];
			CGFloat savedLatitude = [defaults floatForKey:FAKE_LATITUDE_KEY];

			NSString *savedCord = savedCord = [NSString stringWithFormat:@"lon :%f\nlat :%f", savedLongitude ? : 0, savedLatitude ? : 0];

			cell.textLabel.numberOfLines = 0;
			cell.detailTextLabel.text = savedCord;
		}
		cell.detailTextLabel.numberOfLines = 0;
		return cell;
	}

	if (indexPath.section == 5) { // Language
		cell = [self normalCellFromTableView:tableView];
		if (indexPath.row == 0) {
			cell.textLabel.text = @"Change Language";
			cell.detailTextLabel.text = @"";
			cell.imageView.image = [UIImage systemImageNamed:@"globe"];
			cell.imageView.tintColor = [self dynamicColorBW];
			cell.imageView.layer.cornerRadius = 40/8;
			cell.imageView.layer.masksToBounds = YES;
			cell.accessoryView = nil;

			cell.textLabel.numberOfLines = 0;
			cell.detailTextLabel.numberOfLines = 0;
			return cell;
		}
	}

	if (indexPath.section == EXTRAS) {
		NSArray *titles = @[@"Edit History", @"Streamer Mode", @"View Edit History", @"View Deleted Messages", @"Font", @"Font Size"];
		NSArray *subs = @[@"Remember old versions of edited messages.",
		                  @"Blur Telegram while screen is recorded/mirrored and in the app switcher.",
		                  @"", @"", @"", @""];
		NSArray *icons = @[@"pencil.and.outline", @"video.slash", @"clock.arrow.circlepath", @"trash.slash", @"textformat", @"textformat.size"];
		if (indexPath.row < 2) {
			cell = [self switchCellFromTableView:tableView];
			UISwitch *toggle = [UISwitch new];
			toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:[self switchKeyForIndexPath:indexPath]];
			[toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
			toggle.tag = 1000 + (indexPath.section * 1000) + indexPath.row;
			cell.accessoryView = toggle;
			cell.detailTextLabel.text = subs[indexPath.row];
		} else {
			cell = [self normalCellFromTableView:tableView];
			cell.accessoryView = nil;
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
			if (indexPath.row == 2) cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu edits", (unsigned long)TGXEditHistory().count];
			if (indexPath.row == 3) cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu messages", (unsigned long)TGXDeletedLog().count];
			if (indexPath.row == 4) cell.detailTextLabel.text = [d stringForKey:kCustomFont] ?: @"System";
			if (indexPath.row == 5) cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f%%", ([d doubleForKey:kFontScale] ?: 1.0) * 100];
		}
		cell.textLabel.text = titles[indexPath.row];
		cell.imageView.image = [UIImage systemImageNamed:icons[indexPath.row]];
		cell.imageView.tintColor = [UIColor systemPinkColor];
		cell.textLabel.numberOfLines = 0;
		cell.detailTextLabel.numberOfLines = 0;
		return cell;
	}

	if (indexPath.section == 6) { // Credits
		cell = [self normalCellFromTableView:tableView];

		if (indexPath.row == 0) {
			cell.textLabel.text = @"dev.magician";
			cell.detailTextLabel.text = @"Developer";
			cell.detailTextLabel.textColor = [UIColor lightGrayColor];
			NSData *imageData = [[NSData alloc] initWithBase64EncodedString:DEVLOGOPNG options:NSDataBase64DecodingIgnoreUnknownCharacters];
			cell.imageView.image = [UIImage imageWithData:imageData scale:2.0];
			cell.imageView.layer.cornerRadius = 40/8;
			cell.imageView.layer.masksToBounds = YES;
			cell.accessoryView = nil;

		}
		else if (indexPath.row == 1) {
			cell.textLabel.text = TGLoc(@"DISCLAIMER");
			cell.detailTextLabel.text = @"A note from the developer";
			cell.imageView.image = [UIImage systemImageNamed:@"note.text"];
			cell.imageView.tintColor = [self dynamicColorBW];
			cell.accessoryView = nil;
			cell.detailTextLabel.textColor = [UIColor lightGrayColor];
		}
		cell.textLabel.numberOfLines = 0;
		cell.detailTextLabel.numberOfLines = 0;
		return cell;
	}

    return cell;
}

# pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
	indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:TGXMapSection(indexPath.section)];

	if (indexPath.section == FILE_FIXER) { // File Picker Fix
		if (indexPath.row == 1) {
			[self clearFilePickerFixCache];
		}
	}

	if (indexPath.section == FAKE_LOCATION) { // Fake Location
		if (indexPath.row == 1) {
			[self showLocationSelector];
		}
	}

	if (indexPath.section == LANGUAGE) { // Language
		if (indexPath.row == 0) {
			[self showLanguageSelector];
		}
	}

	if (indexPath.section == EXTRAS) {
		if (indexPath.row == 2) [self showLog:TGXEditHistory() title:@"Edit History" edits:YES];
		if (indexPath.row == 3) [self showLog:TGXDeletedLog() title:@"Deleted Messages" edits:NO];
		if (indexPath.row == 4) [self showFontPicker];
		if (indexPath.row == 5) [self showFontSize];
	}

    if (indexPath.section == CREDITS) {
		if (indexPath.row == 0) {
			NSString *base64String = @"aHR0cHM6Ly9naXRodWIuY29tL203ODMwMzgwLWN5YmVyL1RHRXh0cmEtVXBkYXRlZA==";
	        NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
	        NSString *decodedURL = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];

	        NSURL *url = [NSURL URLWithString:decodedURL];
	        if ([[UIApplication sharedApplication] canOpenURL:url]) {
	            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
	        }
		}
		else if (indexPath.row == 1) {
		    [self showDisclaimer];
		}
    }
}

- (void)switchChanged:(UISwitch *)sender {
    NSInteger adjustedTag = sender.tag - 1000;
    NSInteger section = adjustedTag / 1000;
    NSInteger row = adjustedTag % 1000;

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
    NSString *switchKey = [self switchKeyForIndexPath:indexPath];

    if (switchKey) {
        [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:switchKey];
    }
}

- (NSString *)switchKeyForIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
            switch (indexPath.row) {
                case 0: return kDisableOnlineStatus;
                case 1: return kDisableTypingStatus;
                case 2: return kDisableRecordingVideoStatus;
                case 3: return kDisableUploadingVideoStatus;
                case 4: return kDisableRecordingVoiceStatus;
                case 5: return kDisableUploadingVoiceStatus;
                case 6: return kDisableUploadingPhotoStatus;
                case 7: return kDisableUploadingFileStatus;
                case 8: return kDisableChoosingLocationStatus;
                case 9: return kDisableChoosingContactStatus;
                case 10: return kDisablePlayingGameStatus;
                case 11: return kDisableRecordingRoundVideoStatus;
                case 12: return kDisableUploadingRoundVideoStatus;
                case 13: return kDisableSpeakingInGroupCallStatus;
                case 14: return kDisableChoosingStickerStatus;
                case 15: return kDisableEmojiInteractionStatus;
                case 16: return kDisableEmojiAcknowledgementStatus;
                default: return nil;
            }
        case 1:
            switch (indexPath.row) {
                case 0: return kDisableMessageReadReceipt;
                case 1: return kDisableStoriesReadReceipt;
                default: return nil;
            }
        case 2:
            switch (indexPath.row) {
                case 0: return kDisableAllAds;
                case 1: return kDisableForwardRestriction;
                case 2: return kAntiDelete;
                case 3: return kDisableReadContents;
                case 4: return kLocalPremium;
                default: return nil;
            }
        case 3:
            switch (indexPath.row) {
                case 0: return FILE_PICKER_FIX_KEY;
                default: return nil;
            }
        case 4:
            switch (indexPath.row) {
                case 0: return FAKE_LOCATION_ENABLED_KEY;
                default: return nil;
            }
        case 7:
            switch (indexPath.row) {
                case 0: return kEditHistory;
                case 1: return kStreamerMode;
                default: return nil;
            }
        default:
            return nil;
    }
}

- (void)showLog:(NSArray *)entries title:(NSString *)title edits:(BOOL)edits {
	NSDateFormatter *f = [NSDateFormatter new];
	f.dateStyle = NSDateFormatterShortStyle; f.timeStyle = NSDateFormatterShortStyle;
	NSMutableString *text = [NSMutableString string];
	for (NSDictionary *e in entries.reverseObjectEnumerator) {
		NSString *when = [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:[e[@"date"] doubleValue]]];
		NSString *where = [e[@"key"] hasPrefix:@"c"] ? @"channel/group" : @"private/group";
		if (edits) [text appendFormat:@"[%@] %@ #%@\nBEFORE: %@\nAFTER:  %@\n\n", when, where, [e[@"key"] componentsSeparatedByString:@"_"].lastObject, e[@"old"], e[@"new"]];
		else [text appendFormat:@"[%@] %@ #%@\n%@\n\n", when, where, [e[@"key"] componentsSeparatedByString:@"_"].lastObject, e[@"text"]];
	}
	UIViewController *vc = [UIViewController new];
	vc.title = title;
	UITextView *tv = [UITextView new];
	tv.editable = NO;
	tv.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
	tv.text = text.length ? text : @"Nothing yet.";
	vc.view = tv;
	vc.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(clearLogs)];
	[self.navigationController pushViewController:vc animated:YES];
}

- (void)clearLogs {
	TGXClearLogs();
	[self.navigationController popViewControllerAnimated:YES];
	[self.tableView reloadData];
}

- (void)showFontPicker {
	UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Font" message:@"Restart Telegram to apply" preferredStyle:UIAlertControllerStyleActionSheet];
	NSArray *fams = @[@"System", @"Avenir Next", @"Helvetica Neue", @"Georgia", @"Menlo", @"Futura", @"Gill Sans", @"Optima", @"Chalkboard SE", @"Rockwell", @"American Typewriter", @"Courier New", @"Noteworthy", @"Marker Felt", @"Didot", @"Baskerville"];
	[a addAction:[UIAlertAction actionWithTitle:@"＋ Import Font (.ttf / .otf)…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
		TGXImportFont(self, ^(NSString *family) {
			if (family) [[NSUserDefaults standardUserDefaults] setObject:family forKey:kCustomFont];
			[self.tableView reloadData];
		});
	}]];
	fams = [TGXImportedFontFamilies() arrayByAddingObjectsFromArray:fams];
	for (NSString *fam in fams) {
		[a addAction:[UIAlertAction actionWithTitle:fam style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
			if ([fam isEqualToString:@"System"]) [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCustomFont];
			else [[NSUserDefaults standardUserDefaults] setObject:fam forKey:kCustomFont];
			[self.tableView reloadData];
		}]];
	}
	[a addAction:[UIAlertAction actionWithTitle:TGLoc(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
	a.popoverPresentationController.sourceView = self.view;
	[self presentViewController:a animated:YES completion:nil];
}

- (void)showFontSize {
	UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Font Size" message:@"Restart Telegram to apply" preferredStyle:UIAlertControllerStyleActionSheet];
	for (NSNumber *n in @[@0.85, @0.9, @1.0, @1.1, @1.2, @1.3]) {
		[a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%.0f%%", n.doubleValue * 100] style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
			[[NSUserDefaults standardUserDefaults] setDouble:n.doubleValue forKey:kFontScale];
			[self.tableView reloadData];
		}]];
	}
	[a addAction:[UIAlertAction actionWithTitle:TGLoc(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
	a.popoverPresentationController.sourceView = self.view;
	[self presentViewController:a animated:YES completion:nil];
}

- (NSString *)sizeOfUglyFileFixDirectory {
	NSString *uglyFixDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:FILE_PICKER_PATH];

    // Calculate size of it recursively
    unsigned long long totalSize = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *contents = [fileManager subpathsAtPath:uglyFixDirectory];

    for (NSString *path in contents) {
        NSString *fullPath = [uglyFixDirectory stringByAppendingPathComponent:path];
        BOOL isDirectory;
        if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
            if (!isDirectory) {
                NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];
                totalSize += [attributes fileSize];
            }
        }
    }

    // Format the size into MB or GB
    NSString *formattedSize;
    if (totalSize >= 1024 * 1024 * 1024) { // if the size is >= 1GB
        formattedSize = [NSString stringWithFormat:@"%.2f GB", totalSize / (1024.0 * 1024.0 * 1024.0)];
    } else {
        formattedSize = [NSString stringWithFormat:@"%.2f MB", totalSize / (1024.0 * 1024.0)];
    }
	return formattedSize;
}

- (void)showDisclaimer {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:TGLoc(@"DISCLAIMER")
		              message:TGLoc(@"AUTHOR_MESSAGE")
		       preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:TGLoc(@"OK")
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];

    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showLanguageSelector {
	LanguageSelector *ui = [LanguageSelector new];
	UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:ui];
	[self presentViewController:navVC animated:YES completion:nil];
}

- (void)showLocationSelector {
	LocationSelector *ui = [LocationSelector new];
	UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:ui];
	[self presentViewController:navVC animated:YES completion:nil];
}

- (void)clearFilePickerFixCache {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TGLoc(@"CACHE_CLEAR_WARNING_TITLE")
                                                                   message:TGLoc(@"CACHE_CLEAR_WARNING_MESSAGE")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:TGLoc(@"OK")
                                                       style:UIAlertActionStyleDestructive
                                                     handler:^(UIAlertAction *action) {
        NSString *uglyFixDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"TGExtraFileFixUsingSomeUglyHacks"];

        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:uglyFixDirectory error:&error];

        if (error) {
            NSLog(@"Failed to remove cache directory: %@", error.localizedDescription);
        } else {
            NSLog(@"Successfully cleared cache: %@", uglyFixDirectory);
        }

		self.cacheSize = @"Cleared";

        // Reload section or row as needed
        dispatch_async(dispatch_get_main_queue(), ^{
            NSIndexSet *section = [NSIndexSet indexSetWithIndex:FILE_FIXER];
            [self.tableView reloadSections:section withRowAnimation:UITableViewRowAnimationAutomatic];
        });
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:TGLoc(@"CANCEL")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:cancelAction];
    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"LanguageChangedNotification" object:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"TGExtralocationChanged" object:nil];

}

@end
