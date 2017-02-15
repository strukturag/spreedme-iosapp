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

#import "RoomViewController.h"

#import "RecentChatsViewController.h"
#import "RoomChangeViewController.h"
#import "SMConnectionController.h"
#import "SMLocalizedStrings.h"
#import "STSectionModel.h"
#import "STRoomViewHeaderTableViewCell.h"
#import "STUserViewTableViewCell.h"
#import "UserInterfaceManager.h"
#import "UsersManager.h"

#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"


typedef enum : NSUInteger {
    kRoomViewSectionHeader = 0,
    kRoomViewSectionRoomChat,
    kRoomViewSectionShareRoom,
    kRoomViewSectionExitRoom,
    kRoomViewSectionCount
} RoomViewSections;


@interface RoomViewController ()
{
    SMRoom *_room;
}

@property (nonatomic, strong) IBOutlet UITableView *actionsTableView;

@end

@implementation RoomViewController

- (id)initWithRoom:(SMRoom *)room
{
    self = [super initWithNibName:@"RoomViewController" bundle:nil];
    if (self) {
        _room = room;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.actionsTableView.contentInset = UIEdgeInsetsMake(-1.0f, 0.0f, 0.0f, 0.0); // Workaround to hide the first section header
    
    self.view.backgroundColor = kGrayColor_e5e5e5;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.actionsTableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.actionsTableView.backgroundView = nil;
    }
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Actions

- (void)roomChatRowPressed
{
    [self presentRoomChat];
}


- (void)shareRoomRowPressed
{
    [self shareRoom];
}


- (void)exitRoomRowPressed
{
    [self exitRoom];
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
            
        case kRoomViewSectionHeader:
            break;
            
        case kRoomViewSectionRoomChat:
            [self roomChatRowPressed];
            break;
        
        case kRoomViewSectionShareRoom:
            [self shareRoomRowPressed];
            break;
            
        case kRoomViewSectionExitRoom:
            [self exitRoomRowPressed];
            break;
            
        default:
            break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kRoomViewSectionHeader) {
        return [STRoomViewHeaderTableViewCell cellHeight];
    }
    
    return [STUserViewTableViewCell cellHeight];
}


#pragma mark - UITableView Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kRoomViewSectionCount;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    STUserViewTableViewCell *cell = nil;
    
    static NSString *RoomViewHeaderCellIdentifier = @"RoomViewHeaderCellIdentifier";
    static NSString *RoomChatCellIdentifier = @"RoomChatCellIdentifier";
    static NSString *ShareRoomCellIdentifier = @"ShareRoomCellIdentifier";
    static NSString *ExitRoomCellIdentifier = @"ExitRoomCellIdentifier";
    
    switch (indexPath.section) {
        
        case kRoomViewSectionHeader:
        {
            STRoomViewHeaderTableViewCell *headerCell = [tableView dequeueReusableCellWithIdentifier:RoomViewHeaderCellIdentifier];
            if (!headerCell) {
                headerCell = [[STRoomViewHeaderTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:RoomViewHeaderCellIdentifier];
            }
            
            [headerCell setupWithRoom:_room];
            
            return headerCell;
        }
            
        case kRoomViewSectionRoomChat:
        {
            cell = [tableView dequeueReusableCellWithIdentifier:RoomChatCellIdentifier];
            if (!cell) {
                cell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:RoomChatCellIdentifier];
            }
            
            [cell setupWithTitle:kSMLocalStringRoomChatButton
                        subtitle:nil
                        iconText:[NSString fontAwesomeIconStringForEnum:FAComments]
                   iconTextColor:kSMBlueButtonColor];
        }
            break;
            
        case kRoomViewSectionShareRoom:
        {
            cell = [tableView dequeueReusableCellWithIdentifier:ShareRoomCellIdentifier];
            if (!cell) {
                cell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ShareRoomCellIdentifier];
            }
            
            [cell setupWithTitle:kSMLocalStringShareRoomButton
                        subtitle:nil
                        iconText:[NSString fontAwesomeIconStringForEnum:FAshareAlt]
                   iconTextColor:kSMGrayButtonColor];
        }
            break;
            
        case kRoomViewSectionExitRoom:
        {
            cell = [tableView dequeueReusableCellWithIdentifier:ExitRoomCellIdentifier];
            if (!cell) {
                cell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ExitRoomCellIdentifier];
            }
            
            [cell setupWithTitle:kSMLocalStringExitRoomButton
                        subtitle:nil
                        iconText:[NSString fontAwesomeIconStringForEnum:FASignOut]
                   iconTextColor:kSMRedButtonColor];
        }
            break;
            
        default:
            break;
    }
    
    return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == kRoomViewSectionHeader) {
        return 1.0f; // Workaround to hide header section. In ViewDidLoad we hide it changing tableview insets.
    }
    
    return 0.0f;
}


- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return kTableViewFooterHeight;
}


#pragma mark - Share room options

- (void)shareRoom
{
    NSMutableArray *sharingItems = [NSMutableArray new];
    NSString *shareMessage = NSLocalizedStringWithDefaultValue(@"message_body_share-room",
                                                               nil, [NSBundle mainBundle],
                                                               @"Meet me here: https://spreed.me/",
                                                               @"Meet me here: https://spreed.me/");
    
    NSString *shareMessageSubject = NSLocalizedStringWithDefaultValue(@"message_subject_share-room",
                                                                      nil, [NSBundle mainBundle],
                                                                      @"Meet me here",
                                                                      @"Meet me here");
    NSString *shareRoomMessage = [NSString stringWithFormat:@"%@%@", shareMessage, _room.displayName];
    [sharingItems addObject:shareRoomMessage];
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:sharingItems applicationActivities:nil];
    [activityController setValue:shareMessageSubject forKey:@"subject"];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        activityController.excludedActivityTypes = @[UIActivityTypeAirDrop, UIActivityTypeCopyToPasteboard];
    } else {
        activityController.excludedActivityTypes = @[UIActivityTypeCopyToPasteboard];
    }
    
    [self presentViewController:activityController animated:YES completion:nil];
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


- (void)exitRoom
{
    [[SMConnectionController sharedInstance].channelingManager exitFromCurrentRoom];
    [UsersManager defaultManager].currentUser.room = nil;
    [[UsersManager defaultManager] saveCurrentUser];
    [self.navigationController popToRootViewControllerAnimated:YES];
}


@end
