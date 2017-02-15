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

#import "RoomChangeViewController.h"

#import "SettingsController.h"
#import "SMConnectionController.h"
#import "SMLocalizedStrings.h"
#import "STRoomChangeTableViewCell.h"
#import "STSectionModel.h"


typedef enum : NSUInteger {
    kRoomChangeSectionChangeRoom = 0,
    kOptionsTableViewSectionCount
} RoomChangeSections;


@interface RoomChangeViewController () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
{
    NSMutableArray *_datasource;
    STSectionModel *_changeRoomSection;
    
    NSString *_noRandomRoomPlaceholder;
}

@property (nonatomic, strong) UIBarButtonItem *cancelBarButtonItem;
@property (nonatomic, strong) UITextField *roomTextField;

@property (nonatomic, strong) IBOutlet UITableView *changeRoomTableView;

@end

@implementation RoomChangeViewController

#pragma mark - Object lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _noRandomRoomPlaceholder = NSLocalizedStringWithDefaultValue(@"label_room-name",
                                                                     nil, [NSBundle mainBundle],
                                                                     @"Room name",
                                                                     @"Room name");
        
        _datasource = [[NSMutableArray alloc] init];
        
        _changeRoomSection = [STSectionModel new];
        _changeRoomSection.type = kRoomChangeSectionChangeRoom;
        _changeRoomSection.title =  NSLocalizedStringWithDefaultValue(@"label_enter-room-name",
                                                                      nil, [NSBundle mainBundle],
                                                                      @"Enter a room name",
                                                                      @"Enter a room name");
        
        [_datasource addObject:_changeRoomSection];
    }
    return self;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = kGrayColor_e5e5e5;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.changeRoomTableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.changeRoomTableView.backgroundView = nil;
    }
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    [self getAndSetNewRandomRoom];
    
    self.cancelBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    
    self.navigationItem.rightBarButtonItem = _cancelBarButtonItem;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}


- (void)viewDidAppear:(BOOL)animated
{
    [self.roomTextField becomeFirstResponder];
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


- (void)dismissKeyboard
{
    [self.roomTextField resignFirstResponder];
}


- (void)changeRoomButtonPressed
{
    [self.roomTextField resignFirstResponder];
    
    NSString *newRoomName = [_roomTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (!newRoomName.length) {
        newRoomName = _roomTextField.placeholder;
    }
    
    if ([newRoomName isEqualToString:_noRandomRoomPlaceholder]) {
        return; //If we could not get a random room name from server and user has not introduced a room name. Don't do anything.
    } else {
        SMRoom *newRoom = [[SMRoom alloc]  init];
        newRoom.displayName = newRoomName;
        newRoom.name = newRoomName;
        
        [self.delegate userWantsToChangeToRoom:newRoom];
    }
}


#pragma mark - Utilities

- (void)getAndSetNewRandomRoom
{
    NSString *requestString = [[SMConnectionController sharedInstance].currentRESTAPIEndpoint stringByAppendingFormat:@"/rooms"];
    [[SettingsController sharedInstance] getRandomRoomNameGeneratedByServer:requestString withCompletionBlock:^(NSString *newRandomRoomName, NSError *error) {
        if (!error) {
            self.roomTextField.placeholder = newRandomRoomName;
        }
    }];
}


#pragma mark - UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.roomTextField) {
        [textField resignFirstResponder];
        [self changeRoomButtonPressed];
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
        case kRoomChangeSectionChangeRoom:
        {
        }
            break;
            
        default:
            break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL answer = YES;
    
    STSectionModel *sectionModel = _datasource[indexPath.section];
    
    if (sectionModel.type == kRoomChangeSectionChangeRoom) {
        answer = NO;
    }
    
    return answer;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    
    if (sectionModel.type == kRoomChangeSectionChangeRoom) {
        return [STRoomChangeTableViewCell cellHeight];
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
        case kRoomChangeSectionChangeRoom:
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
    
    static NSString *RoomChangeCellIdentifier = @"RoomChangeCellIdentifier";
    
    STSectionModel *sectionModel = _datasource[indexPath.section];
    
    switch (sectionModel.type) {
        case kRoomChangeSectionChangeRoom:
        {
            STRoomChangeTableViewCell *roomChangeCell = (STRoomChangeTableViewCell *)[tableView dequeueReusableCellWithIdentifier:RoomChangeCellIdentifier];
            if (!roomChangeCell) {
                roomChangeCell = [[STRoomChangeTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:RoomChangeCellIdentifier];
            }
            
            roomChangeCell.roomTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_noRandomRoomPlaceholder
                                                                                                 attributes:@{NSForegroundColorAttributeName: kSMBuddyCellSubtitleColor}];
            roomChangeCell.roomTextField.delegate = self;
            [roomChangeCell.changeRoomButton addTarget:self action:@selector(changeRoomButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            self.roomTextField = roomChangeCell.roomTextField;
            
            cell = roomChangeCell;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
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
    STSectionModel *sectionModel = _datasource[section];
    
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
