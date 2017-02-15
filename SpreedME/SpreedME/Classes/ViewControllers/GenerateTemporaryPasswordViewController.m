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

#import "GenerateTemporaryPasswordViewController.h"

#import "DateFormatterManager.h"
#import "SettingsController.h"
#import "SMConnectionController.h"
#import "SMLocalizedStrings.h"
#import "STSectionModel.h"
#import "STProgressView.h"
#import "STExpirationDateTableViewCell.h"
#import "STTextFieldTableViewCell.h"


typedef enum : NSUInteger {
    kGenerateTPSectionsNameSection = 0,
    kGenerateTPSectionsTimeSection,
    kGenerateTPSectionsCount
} GenerateTPSections;


@interface GenerateTemporaryPasswordViewController () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
{
    NSMutableArray *_datasource;
    STSectionModel *_nameSection;
    STSectionModel *_timeSection;
    
    NSDate *_expirationDate;
    
    NSString *_namePlaceholder;
    
    STProgressView *_generatingTPView;
}

@property (nonatomic, strong) UIBarButtonItem *cancelBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *sendBarButtonItem;
@property (nonatomic, strong) UITextField *nameTextField;
@property (nonatomic, strong) UILabel *expirationDateLabel;
@property (nonatomic, strong) UIButton *expirationDateCalendarButton;

@property (nonatomic, strong) IBOutlet UITableView *generateTPTableView;
@property (nonatomic, strong) IBOutlet UIDatePicker *generateTPDatePicker;

@end

@implementation GenerateTemporaryPasswordViewController

#pragma mark - Object lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _namePlaceholder = @"John Doe";
        
        _datasource = [[NSMutableArray alloc] init];
        
        _nameSection = [STSectionModel new];
        _nameSection.type = kGenerateTPSectionsNameSection;
        _nameSection.title =  NSLocalizedStringWithDefaultValue(@"label_enter-friend-name",
                                                                nil, [NSBundle mainBundle],
                                                                @"Enter a name",
                                                                @"Enter a name");
        
        _timeSection = [STSectionModel new];
        _timeSection.type = kGenerateTPSectionsTimeSection;
        _timeSection.title =  NSLocalizedStringWithDefaultValue(@"label_enter-expiration-time",
                                                                nil, [NSBundle mainBundle],
                                                                @"Enter an expiration date",
                                                                @"Enter an expiration date");
        
        [_datasource addObject:_nameSection];
        [_datasource addObject:_timeSection];
    }
    return self;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = kGrayColor_e5e5e5;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.generateTPTableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.generateTPTableView.backgroundView = nil;
    }
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.cancelBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.leftBarButtonItem = _cancelBarButtonItem;
    
    self.sendBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(sendTP:)];
    self.navigationItem.rightBarButtonItem = _sendBarButtonItem;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    _expirationDate = [NSDate date];
    NSTimeInterval oneHour = 60 * 60;
    _expirationDate = [_expirationDate dateByAddingTimeInterval:oneHour];
    
    [self createGeneratingTemporaryPasswordView];
    
    [_generateTPDatePicker setHidden:YES];
    [_generateTPDatePicker addTarget:self action:@selector(dateIsChanged:) forControlEvents:UIControlEventValueChanged];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}


- (void)viewDidAppear:(BOOL)animated
{
    [self initialDataPickerSetup];
    [self.nameTextField becomeFirstResponder];
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


#pragma mark - Actions

-(void)cancel
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


-(void)sendTP:(NSString *)TP
{
    NSString *name = [_nameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSInteger timeStamp = [_expirationDate timeIntervalSince1970];
    NSString *expirationDate = [NSString stringWithFormat:@"%li", (long)timeStamp];
    
    NSLog(@"Generating TP for name:%@ time:%@", name, expirationDate);
    
    [self getTPforName:name andExpirationDate:expirationDate];
}


- (void)dismissKeyboard
{
    [self.nameTextField resignFirstResponder];
}


- (void)dateIsChanged:(id)sender
{
    [self setDatePickerDateInDateLabel];
}

#pragma mark - Notifications

// This method should be called only once on viewDidLoad
- (void)createGeneratingTemporaryPasswordView
{
    _generatingTPView = [[STProgressView alloc] initWithWidth:240.0f
                                                      message:NSLocalizedStringWithDefaultValue(@"label_user-view_generating-temporary-password",
                                                                                                nil, [NSBundle mainBundle],
                                                                                                @"Generating Temporary Password",
                                                                                                @"Generating Temporary Password")
                                                         font:nil
                                             cancelButtonText:nil
                                                     userInfo:nil];
    
    _generatingTPView.frame = CGRectMake(40.0f, 92.0f,
                                         _generatingTPView.frame.size.width,
                                         _generatingTPView.frame.size.height);
    
    _generatingTPView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    [self.view addSubview:_generatingTPView];
    
    
    _generatingTPView.layer.cornerRadius = 5.0;
    _generatingTPView.backgroundColor = [[UIColor alloc] initWithRed:0.0 green:0.0 blue:0.0 alpha:0.6];
    _generatingTPView.hidden = YES;
}


- (void)showGeneratingTemporaryPassView
{
    _generatingTPView.hidden = NO;
    [self.view bringSubviewToFront:_generatingTPView];
}


- (void)hideGeneratingTemporaryPassView
{
    _generatingTPView.hidden = YES;
}


#pragma mark - Utilities

- (NSString *)getTPforName:(NSString *)name andExpirationDate:(NSString *)expirationDate
{
    NSString *serverEndpoint = [[SMConnectionController sharedInstance].currentOwnCloudRESTAPIEndpoint stringByAppendingFormat:@"/admin/tp"];
    __block NSString *temporaryPass = nil;
    
    [self showGeneratingTemporaryPassView];
    
    [[SettingsController sharedInstance] getTemporaryPaswordGeneratedByServer:serverEndpoint forName:name andExpirationDate:expirationDate withCompletionBlock:^(NSString *temporaryPassword, NSError *error) {
        
        [self hideGeneratingTemporaryPassView];
        
        if (!error) {
            temporaryPass = temporaryPassword;
            [self.delegate userHasGeneratedATempPass:temporaryPassword];
        } else {
            [self showErrorAlertView];
        }
    }];
    
    return temporaryPass;
}


- (void)initialDataPickerSetup
{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar];
    NSDateComponents *components = [gregorian components: NSUIntegerMax fromDate: _expirationDate];
    NSDate *startDate = [gregorian dateFromComponents: components];
    
    [_generateTPDatePicker setDatePickerMode:UIDatePickerModeDateAndTime];
    [_generateTPDatePicker setMinimumDate:startDate];
    [_generateTPDatePicker setDate:startDate animated:YES];
    [_generateTPDatePicker reloadInputViews];
    
    [self setDatePickerDateInDateLabel];
}


- (void)setDatePickerDateInDateLabel
{
    _expirationDate = [_generateTPDatePicker date];
    
    NSDateFormatter *dateFormatter = [[DateFormatterManager sharedInstance] userVisibleDateFormatter];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    [dateFormatter setDateFormat:@"dd MMM yyyy - HH:mm"];
    _expirationDateLabel.text = [dateFormatter stringFromDate:_expirationDate];
    
    [_expirationDateLabel setNeedsDisplay];
}


- (void)toggleCalendarButton
{
    if (_expirationDateCalendarButton.selected) {
        [_expirationDateCalendarButton setSelected:NO];
        [_generateTPDatePicker setHidden:YES];
    } else {
        [_expirationDateCalendarButton setSelected:YES];
        [_generateTPDatePicker setHidden:NO];
    }
}


- (void)showErrorAlertView
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                    message:NSLocalizedStringWithDefaultValue(@"message_body_tp-error",
                                                                                              nil, [NSBundle mainBundle],
                                                                                              @"Could not generate a temporary password",
                                                                                              @"Could not generate a temporary password")
                                                   delegate:nil
                                          cancelButtonTitle:kSMLocalStringSadOKButton
                                          otherButtonTitles:nil];
    [alert show];
}


#pragma mark - UITextField delegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *alreadyModifiedText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    alreadyModifiedText = [alreadyModifiedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (alreadyModifiedText.length > 0 && (textField == _nameTextField)) {
        self.navigationItem.rightBarButtonItem.enabled = YES;
    } else {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
    
    return YES;
}


- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (_expirationDateCalendarButton.selected) {
        [self toggleCalendarButton];
    }
    
    return YES;
}


- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [textField resignFirstResponder];
}


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    
    switch (sectionModel.type) {
            
        default:
            break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL answer = YES;
    
    STSectionModel *sectionModel = _datasource[indexPath.section];
    
    if (sectionModel.type == kGenerateTPSectionsNameSection) {
        answer = NO;
    }
    
    return answer;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    
    if (sectionModel.type == kGenerateTPSectionsNameSection) {
        return [STTextFieldTableViewCell cellHeight];
    } else if (sectionModel.type == kGenerateTPSectionsTimeSection) {
        return [STExpirationDateTableViewCell cellHeight];
    }
    
    return 44.0f;
}


- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self dismissKeyboard];
}


#pragma mark - UITableView Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _datasource.count;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows = 0;
    
    STSectionModel *sectionModel = _datasource[section];
    
    switch (sectionModel.type) {
        case kGenerateTPSectionsNameSection:
            numberOfRows = 1;
            break;
        
        case kGenerateTPSectionsTimeSection:
            numberOfRows = 1;
            break;
            
        default:
            break;
    }
    
    return numberOfRows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    STSectionModel *sectionModel = _datasource[indexPath.section];
    
    switch (sectionModel.type) {
        case kGenerateTPSectionsNameSection:
        {
            STTextFieldTableViewCell *nameCell = (STTextFieldTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[STTextFieldTableViewCell cellReuseIdentifier]];
            if (!nameCell) {
                nameCell = [[STTextFieldTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[STTextFieldTableViewCell cellReuseIdentifier]];
            }
            
            nameCell.cellTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_namePlaceholder
                                                                                                 attributes:@{NSForegroundColorAttributeName: kSMBuddyCellSubtitleColor}];
            nameCell.cellTextField.delegate = self;
            self.nameTextField = nameCell.cellTextField;
            
            cell = nameCell;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
            break;
            
        case kGenerateTPSectionsTimeSection:
        {
            STExpirationDateTableViewCell *dateCell = (STExpirationDateTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[STExpirationDateTableViewCell cellReuseIdentifier]];
            if (!dateCell) {
                dateCell = [[STExpirationDateTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[STExpirationDateTableViewCell cellReuseIdentifier]];
            }
            
            [dateCell.changeDateButton addTarget:self action:@selector(toggleCalendarButton) forControlEvents:UIControlEventTouchUpInside];
            self.expirationDateCalendarButton = dateCell.changeDateButton;
            
            self.expirationDateLabel = dateCell.dateLabel;
            
            cell = dateCell;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
            break;
            
        default:
            break;
    }
    
    // Remove seperator inset
    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        [cell setSeparatorInset:UIEdgeInsetsZero];
    }
    
    // Prevent the cell from inheriting the Table View's margin settings
    if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)]) {
        [cell setPreservesSuperviewLayoutMargins:NO];
    }
    
    // Explictly set your cell's layout margins
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
    
    return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    STSectionModel *sectionModel = _datasource[section];
    NSString *title = sectionModel.title;
    return title;
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return kTableViewHeaderHeight + kTableViewFooterHeight;
    }
    
    return kTableViewHeaderHeight;
}


- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return kTableViewFooterHeight;
}


@end
