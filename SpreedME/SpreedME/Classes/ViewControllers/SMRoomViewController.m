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

#import "SMRoomViewController.h"

#import "BuddyTableViewCell.h"
#import "BuddyViewController.h"
#import "ChildRotationNavigationController.h"
#import "GenerateTemporaryPasswordViewController.h"
#import "OutlinedLabel.h"
#import "RecentChatsViewController.h"
#import "RoundedRectButton.h"
#import "SettingsController.h"
#import "SMConnectionController.h"
#import "SMLocalizedStrings.h"
#import "STNoUsersInRoomTableViewCell.h"
#import "UserInterfaceManager.h"
#import "UsersManager.h"

#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"


@interface SMRoomViewController () <UITableViewDataSource, UITableViewDelegate, UserUpdatesProtocol, UIActionSheetDelegate, GenerateTempPassViewControllerDelegate>
{
    NSMutableArray *_userList;
    SMRoom *_room;
    
    UIActionSheet *_roomActionSheet;
    UIActionSheet *_shareRoomActionSheet;
        
    RoundedRectButton *_shareRoomButton;
    
    //Localization
    NSString *_connectingExplanationStringOwnSpreed;
    NSString *_connectingExplanationStringSpreedMe;
    NSString *_disconnectedExplanationString;
}

@property (nonatomic, strong) IBOutlet UITableView *roomUsersTableView;
@property (nonatomic, strong) UIBarButtonItem *actionsBarButton;

@end

@implementation SMRoomViewController

- (id)initWithRoom:(SMRoom *)room withState:(SMRoomViewControllerState)state
{
    self = [super initWithNibName:@"SMRoomViewController" bundle:nil];
    if (self) {
        _room = room;
        _state = state;
        
        self.navigationItem.title = room.displayName;
        
        _connectingExplanationStringOwnSpreed = NSLocalizedStringWithDefaultValue(@"description_connecting-to-server-own-spreed-mode",
                                                                                  nil, [NSBundle mainBundle],
                                                                                  @"Connecting to the server. \nPlease, check if you have the correct server URL in 'Server settings' or your Internet connection.",
                                                                                  @"Multiline");
        
        _connectingExplanationStringSpreedMe = NSLocalizedStringWithDefaultValue(@"description_connecting-to-server-spreed-me-mode",
                                                                                 nil, [NSBundle mainBundle],
                                                                                 @"Connecting to the server. \nPlease, check your Internet connection.",
                                                                                 @"Multiline");
        
        _disconnectedExplanationString = NSLocalizedStringWithDefaultValue(@"description_disconnected-from-server",
                                                                           nil, [NSBundle mainBundle],
                                                                           @"You are disconnected. \nIf you want to reconnect please go to 'Server settings'.",
                                                                           @"Multiline");
        
        [[UsersManager defaultManager] subscribeForUpdates:self];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionBecomeActive:) name:ChannelingConnectionBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionBecomeInactive:) name:ChannelingConnectionBecomeInactiveNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localUserDidJoinRoom:) name:LocalUserDidJoinRoomNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localUserDidReceiveDefaultRoomDisabledError:) name:LocalUserDidReceiveDisabledDefaultRoomErrorNotification object:nil];
    }
    return self;
}


- (void)dealloc
{
    [[UsersManager defaultManager] unsubscribeForUpdates:self];
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
    
    self.actionsBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(presentRoomActions)];
    
    // Exit from a room is not possible to implement if you do not change to another room.
    self.navigationItem.rightBarButtonItem = nil;
}


- (void)viewWillAppear:(BOOL)animated
{
    [self setUIForState:self.state];
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


#pragma mark - Getters/setters

- (void)setState:(SMRoomViewControllerState)state
{
    if (state != _state) {
        _state = state;
        [self setUIForState:_state];
    }
}


#pragma mark - Channeling connection notifications

- (void)connectionBecomeActive:(NSNotification *)notification
{
    self.state = kSMRoomViewControllerStateConnected;
    
    if ([[UsersManager defaultManager].currentUser.room.name isEqualToString:DefaultRoomId] &&
        ![[[SettingsController sharedInstance].serverConfig objectForKey:kServerConfigDefaultRoomEnabledKey] boolValue]) {
//        [self setNoDefaultRoomUI];
    }
}


- (void)connectionBecomeInactive:(NSNotification *)notification
{
    self.state = kSMRoomViewControllerStateDisconnectedFromServer;
    
    [self.navigationController popToRootViewControllerAnimated:YES];
}


#pragma mark - Rooms notifications

- (void)localUserDidJoinRoom:(NSNotification *)notification
{
    self.state = kSMRoomViewControllerStateConnected;
}


- (void)localUserDidReceiveDefaultRoomDisabledError:(NSNotification *)notification
{
//    [self setNoDefaultRoomUI];
}


#pragma mark - BuddyUpdates Protocol

- (void)roomUsersListUpdated
{
    [self setUIForState:_state];
    
    if (self.isViewLoaded && self.view.window) {
        [self.roomUsersTableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        [self.roomUsersTableView reloadData];
    }
}


- (void)displayUserHasBeenUpdated:(SMDisplayUser *)displayUser
{
    NSArray *visibleCells = [self.roomUsersTableView indexPathsForVisibleRows];
    for (NSIndexPath *indexPath in visibleCells) {
        
        BuddyTableViewCell *cell = (BuddyTableViewCell *)[self.roomUsersTableView cellForRowAtIndexPath:indexPath];
        SMDisplayUser *dispUserForCell = [[UsersManager defaultManager] roomDisplayUserForIndex:indexPath.row];
        
        if ([displayUser.Id isEqualToString:dispUserForCell.Id]) {
            [cell setupWithDisplayUser:dispUserForCell];
        }
    }
}


#pragma mark - UI update methods

- (void)setUIForState:(SMRoomViewControllerState)state
{
    [self setTableHeaderViewWithState:state];
    self.navigationItem.title = _room.displayName;
    self.navigationItem.titleView = nil;
    
    switch (state) {
        case kSMRoomViewControllerStateConnected:
            if ([[UsersManager defaultManager] roomDisplayUsersCount] > 0) {
                self.roomUsersTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
            } else {
                self.roomUsersTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
            }
            break;
            
        case kSMRoomViewControllerStateConnecting:
            if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
                self.navigationItem.titleView = [self connectingView];
            } else {
                self.navigationItem.title = kSMLocalStringConnectingEllipsisLabel;
            }
            self.roomUsersTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
            break;
            
        case kSMRoomViewControllerStateDisconnectedFromServer:
            break;
            
        default:
            break;
    }
}


#pragma mark - GenerateTempPassViewController Delegate

- (void)userHasGeneratedATempPass:(NSString *)TP
{
    NSString *encodedTP = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                  NULL,
                                                                                  (CFStringRef)TP,
                                                                                  NULL,
                                                                                  CFSTR("!*'();:@&=+$,/?%#[]\" "),
                                                                                  kCFStringEncodingUTF8));

    [self dismissViewControllerAnimated:YES completion:^{
        [self shareRoomWithTemporaryPass:encodedTP];
    }];
}


#pragma mark - Actions

- (void)shareRoom
{
    if ([SettingsController sharedInstance].ownCloudMode &&
        ([UsersManager defaultManager].currentUser.isAdmin || [UsersManager defaultManager].currentUser.isSpreedMeAdmin)) {
        [self presentShareRoomDialog];
    } else {
        [self shareRoomWithTemporaryPass:nil];
    }
}

- (void)shareRoomWithTemporaryPass:(NSString *)TP
{
    NSString *meetMeHereSpreedMeString = NSLocalizedStringWithDefaultValue(@"message_body_share-room",
                                                                           nil, [NSBundle mainBundle],
                                                                           @"Meet me here: https://spreed.me/",
                                                                           @"Meet me here: https://spreed.me/");
    
    NSString *meetMeHereString = NSLocalizedStringWithDefaultValue(@"message_subject_share-room",
                                                                   nil, [NSBundle mainBundle],
                                                                   @"Meet me here",
                                                                   @"Meet me here");
    
    
    NSString *shareRoomMessage = [NSString stringWithFormat:@"%@: ", meetMeHereString];
    NSString *sharedURL = [self getURLforSharingRoom];
    NSString *room = @"";
    
    if (![_room.displayName isEqualToString:[SMRoom defaultRoomName]]) {
        room = _room.displayName;
    }
    
    if ([SMConnectionController sharedInstance].spreedMeMode) {
        shareRoomMessage = [NSString stringWithFormat:@"%@%@", meetMeHereSpreedMeString, room];
    } else if ([SMConnectionController sharedInstance].ownCloudMode) {
        shareRoomMessage = [NSString stringWithFormat:@"%@%@/", shareRoomMessage, sharedURL];
        if (TP) {
            shareRoomMessage = [NSString stringWithFormat:@"%@?tp=%@", shareRoomMessage, TP];
        }
        if ([room length] != 0) {
            shareRoomMessage = [NSString stringWithFormat:@"%@#%@", shareRoomMessage, room];
        }
    } else {
        shareRoomMessage = [NSString stringWithFormat:@"%@%@/%@", shareRoomMessage, sharedURL, room];
    }
    
    NSMutableArray *sharingItems = [NSMutableArray new];
    [sharingItems addObject:shareRoomMessage];
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:sharingItems applicationActivities:nil];
    if([activityController respondsToSelector:@selector(popoverPresentationController)] ) {
        activityController.popoverPresentationController.sourceView = _shareRoomButton;
        activityController.popoverPresentationController.sourceRect = _shareRoomButton.bounds;
        activityController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
    }
    [activityController setValue:shareRoomMessage forKey:@"subject"];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        activityController.excludedActivityTypes = @[UIActivityTypeAirDrop, UIActivityTypeCopyToPasteboard];
    } else {
        activityController.excludedActivityTypes = @[UIActivityTypeCopyToPasteboard];
    }
    
    [self presentViewController:activityController animated:YES completion:nil];
}


- (NSString *)getURLforSharingRoom
{
    NSString *sharedURL = [SMConnectionController sharedInstance].currentRESTAPIEndpoint;
    
    if ([sharedURL hasSuffix:kRESTAPIEndpoint]) {
        sharedURL = [sharedURL substringToIndex:[sharedURL length] - [kRESTAPIEndpoint length]];
    }
    
    if ([SMConnectionController sharedInstance].ownCloudMode) {
        sharedURL = [SMConnectionController sharedInstance].currentServer;
    }
    
    NSURL *serverURL = [NSURL URLWithString:sharedURL];
    int port = [[serverURL port] intValue];
    NSString *scheme = [serverURL scheme];
    
    if (([scheme isEqualToString:@"https"] && port == 443) ||
        ([scheme isEqualToString:@"http"] && port == 80)) {
        NSRange replaceRange = [sharedURL rangeOfString:[NSString stringWithFormat:@":%i", port]];
        if (replaceRange.location != NSNotFound){
            sharedURL = [sharedURL stringByReplacingCharactersInRange:replaceRange withString:@""];
        }
    }
    
    return sharedURL;
}

- (void)presentGenerateTPViewController
{
    GenerateTemporaryPasswordViewController *generateTPVC = [[GenerateTemporaryPasswordViewController alloc] initWithNibName:@"GenerateTemporaryPasswordViewController" bundle:nil];
    generateTPVC.delegate = self;
    ChildRotationNavigationController *addRoomNavController = [[ChildRotationNavigationController alloc] initWithRootViewController:generateTPVC];
    [self.navigationController presentViewController:addRoomNavController animated:YES completion:nil];
}


- (void)presentShareRoomDialog
{
    NSString *shareWithSpreedboxUserTitle = NSLocalizedStringWithDefaultValue(@"button_share-room-spreedboxuser",
                                                                              nil, [NSBundle mainBundle],
                                                                              @"Share with a user of this Spreedbox",
                                                                              @"Share with a user of this Spreedbox");
    
    NSString *shareWithAFriendTitle = NSLocalizedStringWithDefaultValue(@"button_share-room-friend",
                                                                        nil, [NSBundle mainBundle],
                                                                        @"Share with a friend",
                                                                        @"Share with a friend");
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        UIAlertController *actionSheetController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *shareWithSpreedboxUserAction = [UIAlertAction actionWithTitle:shareWithSpreedboxUserTitle
                                                                               style:UIAlertActionStyleDefault
                                                                             handler:^(UIAlertAction * action) { [self shareRoomWithTemporaryPass:nil]; } ];
        
        UIAlertAction *shareWithAFriendAction = [UIAlertAction actionWithTitle:shareWithAFriendTitle
                                                                         style:UIAlertActionStyleDefault
                                                                       handler:^(UIAlertAction * action) { [self presentGenerateTPViewController]; } ];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:kSMLocalStringCancelButton
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                           [actionSheetController dismissViewControllerAnimated:YES completion:nil];
                                                       }];
        
        [actionSheetController addAction:shareWithSpreedboxUserAction];
        [actionSheetController addAction:shareWithAFriendAction];
        [actionSheetController addAction:cancel];
        
        UIPopoverPresentationController *popover = actionSheetController.popoverPresentationController;
        if (popover)
        {
            popover.sourceView = _shareRoomButton;
            popover.sourceRect = _shareRoomButton.bounds;
            popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        }
        
        [self presentViewController:actionSheetController animated:YES completion:nil];
    } else {
        _shareRoomActionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                          delegate:self
                                                 cancelButtonTitle:kSMLocalStringCancelButton
                                            destructiveButtonTitle:nil
                                                 otherButtonTitles:shareWithSpreedboxUserTitle, shareWithAFriendTitle, nil];
        
        if (self.tabBarController) {
            [_shareRoomActionSheet showFromTabBar:self.tabBarController.tabBar];
        } else {
            [_shareRoomActionSheet showInView:self.view];
        }
    }
}


- (void)presentRoomChat
{
    if ([_room.name isEqualToString:[UsersManager defaultManager].currentUser.room.name] || [_room.name isEqualToString:[SMRoom defaultRoomName]]) {
        RecentChatsViewController *recentsVC = [UserInterfaceManager sharedInstance].recentChatsViewController;
        if ([_room.name isEqualToString:[SMRoom defaultRoomName]]) {
            _room.name = DefaultRoomId;
        }
        [recentsVC presentChatViewControllerForUserSessionId:_room.name];
        [self.tabBarController setSelectedIndex:[UserInterfaceManager sharedInstance].recentChatsViewControllerTabbarIndex];
    } else {
        spreed_me_log("Unknown roomID %@", _room.name);
        NSAssert(NO, @"Unknown room ID");
    }
}


- (void)presentRoomActions
{
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        UIAlertController *actionSheetController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *exitRoom = [UIAlertAction actionWithTitle:kSMLocalStringExitRoomButton style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action)
                                   {
                                       [self exitRoom];
                                   }];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:kSMLocalStringCancelButton style:UIAlertActionStyleCancel handler:^(UIAlertAction *action)
                                 {
                                     [actionSheetController dismissViewControllerAnimated:YES completion:nil];
                                 }];
        
        [actionSheetController addAction:exitRoom];
        [actionSheetController addAction:cancel];
        
        UIPopoverPresentationController *popover = actionSheetController.popoverPresentationController;
        if (popover)
        {
            UIView *rightBarButtonView = [self.navigationItem.rightBarButtonItem valueForKey:@"view"];
            popover.sourceView = rightBarButtonView;
            popover.sourceRect = rightBarButtonView.frame;
            popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        }
        
        [self presentViewController:actionSheetController animated:YES completion:nil];
    } else {
        _roomActionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:kSMLocalStringCancelButton
                                         destructiveButtonTitle:kSMLocalStringExitRoomButton
                                              otherButtonTitles:nil];
        
        if (self.tabBarController) {
            [_roomActionSheet showFromTabBar:self.tabBarController.tabBar];
        } else {
            [_roomActionSheet showInView:self.view];
        }
    }
}


- (void)exitRoom
{
    [[SMConnectionController sharedInstance].channelingManager exitFromCurrentRoom];
    [UsersManager defaultManager].currentUser.room = nil;
    [[UsersManager defaultManager] saveCurrentUser];
    [self.navigationController popToRootViewControllerAnimated:YES];
}


#pragma mark - Utilities

- (void)setTableHeaderViewWithState:(SMRoomViewControllerState)state
{
    const CGFloat kHeaderHeight         = 50.0f;
    const CGFloat kHorizontalPadding    = 15.0f;
    const CGFloat kButtonTextPadding    = 7.0f;
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.roomUsersTableView.bounds.size.width, kHeaderHeight)];
    CGFloat maxButtonWidth = (headerView.frame.size.width / 2) - (2 * kButtonTextPadding) - (kHorizontalPadding / 2) - kHorizontalPadding;
    
    CGFloat borderHeight = 1.0f / [[UIScreen mainScreen] scale];
    UIView *topBorder = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f,
                                                                 headerView.frame.size.width, borderHeight)];
    UIView *bottomBorder = [[UIView alloc] initWithFrame:CGRectMake(0.0f, headerView.frame.size.height - borderHeight,
                                                                    headerView.frame.size.width, borderHeight)];
    
    topBorder.backgroundColor = kSMTableViewSeparatorsColor;
    bottomBorder.backgroundColor = kSMTableViewSeparatorsColor;
    
    headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    bottomBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    _shareRoomButton = [RoundedRectButton buttonWithType:UIButtonTypeCustom];
    [_shareRoomButton addTarget:self
                         action:@selector(shareRoom)
               forControlEvents:UIControlEventTouchUpInside];
    [_shareRoomButton setTitle:kSMLocalStringShareRoomButton forState:UIControlStateNormal];
    _shareRoomButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [_shareRoomButton setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
    [_shareRoomButton sizeToFit];
    
    if (_shareRoomButton.frame.size.width > maxButtonWidth) {
        CGRect buttonFrame = _shareRoomButton.frame;
        buttonFrame.size.width = maxButtonWidth;
        _shareRoomButton.frame = buttonFrame;
        
        _shareRoomButton.titleLabel.numberOfLines = 1;
        _shareRoomButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        _shareRoomButton.titleLabel.lineBreakMode = NSLineBreakByClipping;
    }
    
    _shareRoomButton.frame = CGRectMake(kHorizontalPadding,
                                       (headerView.frame.size.height - (_shareRoomButton.frame.size.height + 2 * kButtonTextPadding)) / 2,
                                       _shareRoomButton.frame.size.width + 2 * kButtonTextPadding,
                                       _shareRoomButton.frame.size.height + 2 * kButtonTextPadding);
    
    RoundedRectButton *roomChatButton = [RoundedRectButton buttonWithType:UIButtonTypeCustom];
    [roomChatButton addTarget:self
                       action:@selector(presentRoomChat)
             forControlEvents:UIControlEventTouchUpInside];
    [roomChatButton setTitle:kSMLocalStringRoomChatButton forState:UIControlStateNormal];
    roomChatButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [roomChatButton setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
    [roomChatButton sizeToFit];
    
    if (roomChatButton.frame.size.width > maxButtonWidth) {
        CGRect buttonFrame = roomChatButton.frame;
        buttonFrame.size.width = maxButtonWidth;
        roomChatButton.frame = buttonFrame;
        
        roomChatButton.titleLabel.numberOfLines = 1;
        roomChatButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        roomChatButton.titleLabel.lineBreakMode = NSLineBreakByClipping;
    }
    
    roomChatButton.frame = CGRectMake(headerView.frame.size.width - kHorizontalPadding - (roomChatButton.frame.size.width + 2 * kButtonTextPadding),
                                       (headerView.frame.size.height - (roomChatButton.frame.size.height + 2 * kButtonTextPadding)) / 2,
                                       roomChatButton.frame.size.width + 2 * kButtonTextPadding,
                                       roomChatButton.frame.size.height + 2 * kButtonTextPadding);
    
    roomChatButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    
    _shareRoomButton.enabled = (state == kSMRoomViewControllerStateConnected) ? YES : NO;
    roomChatButton.enabled = (state == kSMRoomViewControllerStateConnected) ? YES : NO;
    
    [headerView addSubview:topBorder];
    [headerView addSubview:_shareRoomButton];
    [headerView addSubview:roomChatButton];
    [headerView addSubview:bottomBorder];
    
    self.roomUsersTableView.tableHeaderView = headerView;
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
    
    UIView *connectingView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f,
                                                                   spinner.frame.size.width + connectingLabel.frame.size.width,
                                                                   kConnectingViewHeight)];
    
    connectingView.backgroundColor = kSpreedMeNavigationBarBackgroundColor;
    
    [connectingView addSubview:spinner];
    [connectingView addSubview:connectingLabel];
        
    return connectingView;
}


- (BOOL)existUsersInRoom
{
    NSInteger usersInRoom = [[UsersManager defaultManager] roomDisplayUsersCount];
    
    if ((usersInRoom < 1 && _state == kSMRoomViewControllerStateConnected) || _state == kSMRoomViewControllerStateDisconnectedFromServer) {
        return NO;
    }
    
    return YES;
}


#pragma mark - UITableView Datasource and Delegate

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    if ([self existUsersInRoom]) {
        SMDisplayUser *user = [[UsersManager defaultManager] roomDisplayUserForIndex:indexPath.row];
        
        BuddyTableViewCell *buddyCell = [tableView dequeueReusableCellWithIdentifier:@"RoomUserCellIdentifier"];
        if (!buddyCell) {
            buddyCell = [[BuddyTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"RoomUserCellIdentifier"];
        }
        
        [buddyCell setupWithDisplayUser:user];
        
        cell = buddyCell;
    } else {
        cell = [[STNoUsersInRoomTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"NoUsersCellIdentifier"];
    }
    
    return cell;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger usersInRoom = [[UsersManager defaultManager] roomDisplayUsersCount];
    
    if (![self existUsersInRoom]) {
        return 1;
    }
    
    return usersInRoom;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SMDisplayUser *user = [[UsersManager defaultManager] roomDisplayUserForIndex:indexPath.row];
    if ([user conformsToProtocol:@protocol(SMUserView)]) {
        BuddyViewController *buddyViewController = [[BuddyViewController alloc] initWithUserView:user];
        buddyViewController.buddyViewControllerUserId = [NSString stringWithString:user.Id];
        [self.navigationController pushViewController:buddyViewController animated:YES];
    } else {
        spreed_me_log("Given user does not conform to SMUserView protocol.");
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (![self existUsersInRoom]) {
        STNoUsersInRoomTableViewCell *cell = [[STNoUsersInRoomTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        return [cell cellHeight];
    }
    
    return [BuddyTableViewCell cellHeight];
}


#pragma mark - UIActionSheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (actionSheet == _roomActionSheet) {
        if (buttonIndex == 0) {
            [self exitRoom];
        }
        _roomActionSheet = nil;
    } else if (actionSheet == _shareRoomActionSheet) {
        if (buttonIndex == 0) {
            [self shareRoomWithTemporaryPass:nil];
        } else if (buttonIndex == 1){
            [self presentGenerateTPViewController];
        }
        _shareRoomActionSheet = nil;
        
    }
}

@end
