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

#import "SMRoomsViewController.h"

#import "BuddyTableViewCell.h"
#import "ChildRotationNavigationController.h"
#import "RoomChangeViewController.h"
#import "SMConnectionController.h"
#import "SMLocalizedStrings.h"
#import "SMRoomViewController.h"
#import "UserInterfaceManager.h"
#import "UsersManager.h"
#import "UIImage+RoundedCorners.h"

#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"

@interface SMRoomsViewController () <UITableViewDataSource, UITableViewDelegate, RoomChangeViewControllerDelegate>
{
    NSMutableArray *_roomList;
    NSString *_currentRoomName;
    NSString *_tryingToConnectRoomName;
    BOOL _isOnline;
    NSString *_noRoomNotification;
    NSString *_disconnectedFromServerNotification;
}

@property (nonatomic, strong) IBOutlet UITableView *roomsTableView;
@property (nonatomic, weak) IBOutlet UIView *noRoomNotificationView;
@property (nonatomic, weak) IBOutlet UILabel *noRoomNotificationLabel;
@property (nonatomic, weak) IBOutlet UIView *disconnectedNotificationView;
@property (nonatomic, weak) IBOutlet UILabel *disconnectedNotificationLabel;

@property (nonatomic, strong) UIBarButtonItem *addBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *editBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *doneBarButtonItem;

@end

@implementation SMRoomsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        NSString *roomsLocString = NSLocalizedStringWithDefaultValue(@"tabbar-item_title_rooms",
                                                                     nil, [NSBundle mainBundle],
                                                                     @"Rooms",
                                                                     @"This should be small enough to fit into tab. ~11 Latin symbols fit.");
        
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:roomsLocString image:[UIImage imageNamed:@"rooms_black"] tag:0];
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
            self.tabBarItem.selectedImage = [UIImage imageNamed:@"rooms_white"];
        } else {
            self.tabBarItem.selectedImage = [UIImage imageNamed:@"rooms_blue"];
        }
        self.navigationItem.title = roomsLocString;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionBecomeActive:) name:ChannelingConnectionBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionBecomeInactive:) name:ChannelingConnectionBecomeInactiveNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasChangedAppModeOrResetApp:) name:ConnectionControllerHasProcessedChangeOfApplicationModeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasChangedAppModeOrResetApp:) name:ConnectionControllerHasProcessedResetOfApplicationNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localUserDidJoinRoom:) name:LocalUserDidJoinRoomNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localUserDidReceiveDefaultRoomDisabledError:) name:LocalUserDidReceiveDisabledDefaultRoomErrorNotification object:nil];
    }
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    _currentRoomName = [UsersManager defaultManager].currentUser.room.name;
    _roomList = [UsersManager defaultManager].currentUser.roomsList;
    
    self.noRoomNotificationView.backgroundColor = kGrayColor_e5e5e5;
    self.noRoomNotificationLabel.font = [UIFont systemFontOfSize:kInformationTextFontSize];
    self.noRoomNotificationLabel.textColor = kSMTableViewHeaderTextColor;
    self.noRoomNotificationLabel.backgroundColor = kGrayColor_e5e5e5;
    
    self.disconnectedNotificationView.backgroundColor = kGrayColor_e5e5e5;
    self.disconnectedNotificationLabel.font = [UIFont systemFontOfSize:kInformationTextFontSize];
    self.disconnectedNotificationLabel.textColor = kSMTableViewHeaderTextColor;
    self.disconnectedNotificationLabel.backgroundColor = kGrayColor_e5e5e5;
    
    self.noRoomNotificationLabel.text = NSLocalizedStringWithDefaultValue(@"label_no-rooms",
                                                                          nil, [NSBundle mainBundle],
                                                                          @"Press + to add and visit new rooms",
                                                                          @"Press + to add and visit new rooms");
    
#if SPREEDME
    self.disconnectedNotificationLabel.text = NSLocalizedStringWithDefaultValue(@"description_disconnected-from-spreedbox",
                                                                                nil, [NSBundle mainBundle],
                                                                                @"You are not connected to your Spreedbox. \n\nGo to 'Spreedbox settings' to setup your connection.",
                                                                                @"Multiline");
#else
    self.disconnectedNotificationLabel.text = NSLocalizedStringWithDefaultValue(@"description_disconnected-from-server",
                                                                                nil, [NSBundle mainBundle],
                                                                                @"You are disconnected. \nIf you want to reconnect please go to 'Server settings'.",
                                                                                @"Multiline");
#endif
    
    self.addBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addBarButtonPressed)];
    self.editBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editTableButtonPressed)];
    self.doneBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneBarButtonPressed)];
    
    self.navigationItem.rightBarButtonItem = _addBarButtonItem;
    self.navigationItem.leftBarButtonItem = _editBarButtonItem;
    
    self.roomsTableView.allowsSelectionDuringEditing = NO;
    
    [self setOfflineUI];
}


- (void)viewWillAppear:(BOOL)animated
{
    _currentRoomName = [UsersManager defaultManager].currentUser.room.name;
    [self.roomsTableView reloadData];
    
    [self checkRoomList];
}


- (void)viewDidAppear:(BOOL)animated
{
    if ([SMConnectionController sharedInstance].appLoginState == kSMAppLoginStatePromptUserToLogin) {
        [[UserInterfaceManager sharedInstance] presentLoginViewController];
    }
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


#pragma mark - Channeling connection notifications

- (void)connectionBecomeActive:(NSNotification *)notification
{
    _isOnline = YES;
    [self resetRoomList];
    [self setOnlineUI];
}


- (void)connectionBecomeInactive:(NSNotification *)notification
{
    _isOnline = NO;
    [self setOfflineUI];
}


#pragma mark - General notifications

- (void)userHasChangedAppModeOrResetApp:(NSNotification *)notification
{
    [self resetRoomList];
    [self.navigationController popToRootViewControllerAnimated:YES];
}


#pragma mark - Rooms notifications

- (void)localUserDidJoinRoom:(NSNotification *)notification
{
    SMRoom *newRoom = [notification.userInfo objectForKey:kRoomUserInfoKey];
    if ([newRoom.name isEqualToString:_tryingToConnectRoomName]) {
        _tryingToConnectRoomName = nil;
    }
    
    _currentRoomName = [UsersManager defaultManager].currentUser.room.name;
    
    [self checkRoomList];
    [self.roomsTableView reloadData];
}


- (void)localUserDidReceiveDefaultRoomDisabledError:(NSNotification *)notification
{
    //    [self setNoDefaultRoomUI];
}


#pragma mark - UI update methods

- (void)setOnlineUI
{
    self.navigationItem.leftBarButtonItem.enabled = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    self.navigationItem.titleView = nil;
    
    self.disconnectedNotificationView.hidden = YES;
    
    [self.roomsTableView reloadData];
}


- (void)setOfflineUI
{
    _tryingToConnectRoomName = nil;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    if ([UsersManager defaultManager].currentUser.wasConnected) {
        self.navigationItem.leftBarButtonItem.enabled = YES;
        self.navigationItem.titleView = [self connectingView];
        self.disconnectedNotificationView.hidden = YES;
    } else {
        self.navigationItem.leftBarButtonItem.enabled = NO;
        self.navigationItem.titleView = nil;
        self.disconnectedNotificationView.hidden = NO;
    }
    
    [self.roomsTableView reloadData];
}


- (void)checkRoomList
{
    if ([_roomList count] < 1) {
        self.noRoomNotificationView.hidden = NO;
        self.navigationItem.leftBarButtonItem = nil;
    } else {
        self.noRoomNotificationView.hidden = YES;
        self.navigationItem.leftBarButtonItem = (self.editing) ? _doneBarButtonItem : _editBarButtonItem;
        if (_isOnline) {
            self.navigationItem.leftBarButtonItem.enabled = YES;
        }
    }
}


- (UIView *)connectingView
{
    const CGFloat kConnectingViewHeight = 30.0f;
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, kConnectingViewHeight, kConnectingViewHeight)];
    spinner.color = kSpreedMeNavigationBarTitleColor;
    [spinner startAnimating];
    
    UILabel *connectingLabel = [[UILabel alloc] init];
    connectingLabel.text = kSMLocalStringConnectingLabel;
    connectingLabel.textColor = kSpreedMeNavigationBarTitleColor;
    connectingLabel.backgroundColor = [UIColor clearColor];
    connectingLabel.font = [UIFont systemFontOfSize:17];
    [connectingLabel sizeToFit];
    connectingLabel.frame = CGRectMake(spinner.frame.size.width,
                                       (kConnectingViewHeight - connectingLabel.frame.size.height) / 2,
                                       connectingLabel.frame.size.width,
                                       connectingLabel.frame.size.height);
    
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f,
                                                                      spinner.frame.size.width + connectingLabel.frame.size.width,
                                                                      kConnectingViewHeight)];
    
    UIView *connectingView = [[UIView alloc] initWithFrame:contentView.bounds];
    
    contentView.backgroundColor = kSpreedMeNavigationBarBackgroundColor;
    connectingView.backgroundColor = kSpreedMeNavigationBarBackgroundColor;
    
    spinner.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    connectingLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    contentView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    
    [contentView addSubview:spinner];
    [contentView addSubview:connectingLabel];
    
    [connectingView addSubview:contentView];
    
    return connectingView;
}


#pragma mark - Rooms functionality


- (void)roomSelectedAtIndexPath:(NSIndexPath *)indexPath
{
    SMRoom *room = [_roomList objectAtIndex:indexPath.row];
    
    [self changeToRoom:room];
}


- (BOOL)isCurrentRoomAtIndexPath:(NSIndexPath *)indexPath
{
    SMRoom *room = [_roomList objectAtIndex:indexPath.row];
    
    if ([_currentRoomName isEqualToString:room.name]) {
        return YES;
    }
    return NO;
}


- (void)saveUserRooms
{
    NSMutableArray *valueToSave = [NSMutableArray arrayWithArray:_roomList];
    [UsersManager defaultManager].currentUser.roomsList = valueToSave;
    [[UsersManager defaultManager] saveCurrentUser];
}


- (void)resetRoomList
{
    _roomList = [UsersManager defaultManager].currentUser.roomsList;
    [self.roomsTableView reloadData];
}


- (void)changeToRoom:(SMRoom *)room
{
    SMRoomViewControllerState state = kSMRoomViewControllerStateDisconnectedFromServer;
    BOOL roomChangeNeeded = ![room.name isEqualToString:[UsersManager defaultManager].currentUser.room.name];
    
    if (_isOnline) {
        state = (roomChangeNeeded) ? kSMRoomViewControllerStateConnecting : kSMRoomViewControllerStateConnected;
    }
    
    SMRoomViewController *roomUsersVC = [[SMRoomViewController alloc] initWithRoom:room withState:state];
    [self.navigationController pushViewController:roomUsersVC animated:YES];
    
    [UserInterfaceManager sharedInstance].currentRoomViewController = roomUsersVC;
    
    if (roomChangeNeeded) {
        _tryingToConnectRoomName = room.name;
        [[SMConnectionController sharedInstance].channelingManager changeRoomTo:room.name];
    }
}

- (void)saveNewRoom:(SMRoom *)newRoom
{
    BOOL savedRoom = NO;
        
    for (SMRoom *room in _roomList) {
        if ([room.name isEqualToString:newRoom.name]) {
            savedRoom = YES;
        }
    }
    
    if (!savedRoom) {
        [_roomList insertObject:newRoom atIndex:0];
        [self saveUserRooms];
    }
}


#pragma mark - RoomChangeViewController delegate

- (void)userWantsToChangeToRoom:(SMRoom *)room
{
    [self.navigationController dismissViewControllerAnimated:YES completion:^{
        [self changeToRoom:room];
        [self saveNewRoom:room];
    }];
}


#pragma mark - Actions

- (void)presentRoomChangeViewController
{
    RoomChangeViewController *roomChangeViewController = [[RoomChangeViewController alloc] initWithNibName:@"RoomChangeViewController" bundle:nil];
    roomChangeViewController.delegate = self;
    ChildRotationNavigationController *addRoomNavController = [[ChildRotationNavigationController alloc] initWithRootViewController:roomChangeViewController];
    [self.navigationController presentViewController:addRoomNavController animated:YES completion:nil];
}


- (void)addBarButtonPressed
{
    [self presentRoomChangeViewController];
}


- (void)editTableButtonPressed
{
    if(!self.editing) {
        [super setEditing:YES animated:YES];
        [self.roomsTableView setEditing:YES animated:YES];
        [self.roomsTableView reloadData];
        self.navigationItem.leftBarButtonItem = _doneBarButtonItem;
    }
}


- (void)doneBarButtonPressed
{
    if(self.editing) {
        [super setEditing:NO animated:NO];
        [self.roomsTableView setEditing:NO animated:NO];
        [self.roomsTableView reloadData];
        self.navigationItem.leftBarButtonItem = _editBarButtonItem;
    }
}


#pragma mark - UITableView Datasource and Delegate

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SMRoom *room = [_roomList objectAtIndex:indexPath.row];
    
    BuddyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RoomCellIdentifier"];
    if (!cell) {
        cell = [[BuddyTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"RoomCellIdentifier"];
    }
    
    NSString *roomName = room.displayName;
    UIImage *groupImage = [UIImage imageNamed:@"group_icon"];
    UIImage *roundedImage = [groupImage roundCornersWithRadius:kViewCornerRadius];
    
    [cell setupWithTitle:roomName
                subtitle:nil
                   image:roundedImage
         displayUserType:kSMDisplayUserTypeAnonymous
        shouldShowStatus:NO
            groupedUsers:0];
    
    cell.accessoryView = nil;
    cell.detailTextLabel.attributedText = [[NSAttributedString alloc] initWithString:@""];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    if ([room.name isEqualToString:_currentRoomName]) {
        NSMutableAttributedString *currentRoomIcon = [[NSMutableAttributedString alloc] initWithString:[NSString fontAwesomeIconStringForEnum:FACheckCircle]];
        UIColor *iconColor = (_isOnline) ? kSMGreenButtonColor : kSMRedButtonColor;
        [currentRoomIcon addAttribute:NSForegroundColorAttributeName value:iconColor range:NSMakeRange(0,1)];
        [currentRoomIcon addAttribute:NSFontAttributeName value:[UIFont fontWithName:kFontAwesomeFamilyName size:22] range:NSMakeRange(0, 1)];
        
        cell.detailTextLabel.attributedText = currentRoomIcon;
        
    } else if ([room.name isEqualToString:_tryingToConnectRoomName]) {
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0f, 30.0f)];
        spinner.color = kSpreedMeNavigationBarTitleColor;
        [spinner startAnimating];
        
        cell.accessoryView = spinner;
    }
    
    return cell;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_roomList count];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_isOnline) {
        [self roomSelectedAtIndexPath:indexPath];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [BuddyTableViewCell cellHeight];
}


- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isCurrentRoomAtIndexPath:indexPath]) {
        return UITableViewCellEditingStyleNone;
    }
    return UITableViewCellEditingStyleDelete;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_roomList removeObjectAtIndex:indexPath.row];
        [self.roomsTableView reloadData];
    }
    
    [self saveUserRooms];
    [self checkRoomList];
}


- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    SMRoom *movingRow = [_roomList objectAtIndex:sourceIndexPath.row];
    [_roomList removeObjectAtIndex:sourceIndexPath.row];
    [_roomList insertObject:movingRow atIndex:destinationIndexPath.row];
    [self saveUserRooms];
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}


@end
