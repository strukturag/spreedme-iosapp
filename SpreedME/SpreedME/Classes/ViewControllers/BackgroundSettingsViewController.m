/**
 * @copyright Copyright (c) 2017 Struktur AG
 * @author Yuriy Shevchuk
 * @author Ivan Sein <ivan@nextcloud.com>
 *
 * @license GNU GPL version 3 or any later version
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "BackgroundSettingsViewController.h"


typedef enum : NSUInteger {
    kBackgroundDisconnection = 0,
    kBackgroundCleanData,
    kBackgroundSettingsCount
} BackgroundSettingsRows;

typedef enum : NSUInteger {
    kConnectedNotClear = 0,
    kConnectedClear,
    kDisconnectedNotClear,
    kDisconnectedClear
} BackgroundSettingsStates;


@interface BackgroundSettingsViewController ()
{
    UISwitch *_backgroundDisconnectionSwitch;
    UISwitch *_backgroundCleanDataSwitch;
}
@property (nonatomic, strong) IBOutlet UITableView *optionsTableView;
@property (nonatomic, strong) IBOutlet UITextView *explanationTextView;

@end

@implementation BackgroundSettingsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
		self.title = NSLocalizedStringWithDefaultValue(@"screen_title_background-settings",
													   nil, [NSBundle mainBundle],
													   @"Background",
													   @"Background settings screen title");
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	
	if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.view.backgroundColor = kGrayColor_e5e5e5;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.optionsTableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.optionsTableView.backgroundView = nil;
    }
    
    self.explanationTextView.layer.cornerRadius = 5.0;
    self.optionsTableView.scrollEnabled = NO;
    
    _backgroundDisconnectionSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    [_backgroundDisconnectionSwitch setOn:self.backgroundDisconnectionValue];
    [_backgroundDisconnectionSwitch addTarget: self action: @selector(backgroundDisconnectionValueChanged:) forControlEvents:UIControlEventValueChanged];
    
    _backgroundCleanDataSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    [_backgroundCleanDataSwitch setOn:self.backgroundCleanDataValue];
    [_backgroundCleanDataSwitch addTarget: self action: @selector(backgroundCleanDataValueChanged:) forControlEvents:UIControlEventValueChanged];
    
    [self setExplanationTextViewText];
}


#pragma mark - UIViewController Rotation

- (NSUInteger)supportedInterfaceOrientations
{
	NSUInteger supportedInterfaceOrientations = UIInterfaceOrientationMaskAll;
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
		supportedInterfaceOrientations = UIInterfaceOrientationMaskPortrait;
	}
	
	return supportedInterfaceOrientations;
}


#pragma mark -

- (void)backgroundDisconnectionValueChanged:(id)sender
{
    self.backgroundDisconnectionValue = _backgroundDisconnectionSwitch.on;
    [self setExplanationTextViewText];
    [self saveChanges];
}


- (void)backgroundCleanDataValueChanged:(id)sender
{
    self.backgroundCleanDataValue = _backgroundCleanDataSwitch.on;
    [self setExplanationTextViewText];
    [self saveChanges];
}


- (void)setExplanationTextViewText
{
    NSUInteger state;
    NSString *stateExplanation;
    
    if (_backgroundDisconnectionSwitch.on) {
        state = (_backgroundCleanDataSwitch.on) ? kDisconnectedClear : kDisconnectedNotClear;
    } else {
        state = (_backgroundCleanDataSwitch.on) ? kConnectedClear : kConnectedNotClear;
    }
    
    switch (state) {
        case kDisconnectedClear:
        stateExplanation =
			NSLocalizedStringWithDefaultValue(@"mode_description_diconnected-in-background-and-clears-data",
											  nil, [NSBundle mainBundle],
											  @"You will be disconnected from server when the app goes to background.\n\nYour chat history and missed calls will be wiped.",
											  @"Explanation to user what happens depending on the options he/she has chosen.");
        break;
        
        case kDisconnectedNotClear:
        stateExplanation =
			NSLocalizedStringWithDefaultValue(@"mode_description_diconnected-in-background-and-keeps-data",
											  nil, [NSBundle mainBundle],
											  @"You will be disconnected from server when the app goes to background.\n\nYour chat history and missed calls will be preserved.",
											  @"Explanation to user what happens depending on the options he/she has chosen");
        break;
        
        case kConnectedClear:
        stateExplanation =
			NSLocalizedStringWithDefaultValue(@"mode_description_connected-in-background-and-clears-data",
											  nil, [NSBundle mainBundle],
											  @"The connection to the server will be kept when the app goes to background.\n\nYour chat history and missed calls will be wiped but new incomming events will be preserved.",
											  @"Explanation to user what happens depending on the options he/she has chosen");
        break;
        
        case kConnectedNotClear:
        stateExplanation =
			NSLocalizedStringWithDefaultValue(@"mode_description_connected-in-background-and-keeps-data",
											  nil, [NSBundle mainBundle],
											  @"The connection to the server will be kept when the app goes to background.\n\nYour chat history and missed calls will be preserved.",
											  @"Explanation to user what happens depending on the options he/she has chosen");
        break;
        
        default:
        break;
    }
    
    self.explanationTextView.text = stateExplanation;
    self.explanationTextView.font = [UIFont systemFontOfSize:16];
}


- (void)saveChanges
{	
	if (self.delegate && [self.delegate respondsToSelector:@selector(backgroundSettingsViewController:hasSetBackgroundDisconnection:andCleanData:)]) {
		[self.delegate backgroundSettingsViewController:self hasSetBackgroundDisconnection:_backgroundDisconnectionSwitch.on andCleanData:_backgroundCleanDataSwitch.on];
	}
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - UITableView Datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return kBackgroundSettingsCount;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = nil;
	
	static NSString *BackgroundDisconnectionCellIdentifier = @"BackgroundDisconnectionCellIdentifier";
	static NSString *BackgroundCleanDataCellIdentifier = @"BackgroundCleanDataCellIdentifier";
	
	switch (indexPath.row) {
		case kBackgroundDisconnection:
		{
            cell = [tableView dequeueReusableCellWithIdentifier:BackgroundDisconnectionCellIdentifier];
			if (!cell) {
				cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:BackgroundDisconnectionCellIdentifier];
			}
			
			cell.textLabel.text =
				NSLocalizedStringWithDefaultValue(@"mode_label_diconnected-in-background",
												  nil, [NSBundle mainBundle],
												  @"Disconnect from server",
												  @"Label for the checkbox of 'disconnected in background' mode");
			
			cell.accessoryView = _backgroundDisconnectionSwitch;
		}
		break;
        
		case kBackgroundCleanData:
		{
            cell = [tableView dequeueReusableCellWithIdentifier:BackgroundCleanDataCellIdentifier];
			if (!cell) {
				cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:BackgroundCleanDataCellIdentifier];
			}
			
			cell.textLabel.text =
				NSLocalizedStringWithDefaultValue(@"mode_label_clears-data",
												  nil, [NSBundle mainBundle],
												  @"Clean data",
												  @"Label for the checkbox of 'clean data when going to background' mode");
			cell.accessoryView = _backgroundCleanDataSwitch;
		}
		break;
        
		default:
		break;
	}
    
	if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        cell.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
	return cell;
}


@end