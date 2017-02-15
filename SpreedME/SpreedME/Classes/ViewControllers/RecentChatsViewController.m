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

#import "RecentChatsViewController.h"

#import "AudioManager.h"
#import "UsersManager.h"
#import "ChannelingManager.h"
#import "ChatController.h"
#import "ChatManager.h"
#import "DateFormatterManager.h"
#import "RoundedNumberView.h"
#import "SMLocalizedStrings.h"
#import "UserActivityManager.h"
#import "UsersActivityController.h"

#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"


@interface SMRCUserInfo : NSObject 

@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *textIcon;

@end

@implementation SMRCUserInfo
@end


@interface RecentChatsViewController () <UITableViewDataSource, UITableViewDelegate, UserRecentActivityControllerUpdatesListener, UserUpdatesProtocol>
{
	NSMutableDictionary *_unreadMessagesDict; // key - userSessionId : value - NSNumber quantity of unread messages
	
	UsersActivityController *_userActivityController;
	
	NSString *_currentlyPresentedChatUserSessionId;
	STChatViewController *_currentlyPresentedChatController;
}

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UILabel *noActivityLabel;

@property (nonatomic, strong) UIBarButtonItem *cancelBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *editBarButtonItem;

@end

@implementation RecentChatsViewController

#pragma mark - Object lifecycle

- (id)initWithUserActivityController:(UsersActivityController *)userActivityController
{
	self = [super initWithNibName:@"RecentChatsViewController" bundle:nil];
    if (self) {
		
		NSString *recentLocString = NSLocalizedStringWithDefaultValue(@"tabbar-item_title_recent",
																	  nil, [NSBundle mainBundle],
																	  @"Recent",
																	  @"Recent chats/events/missed calls. This should be small enough to fit into tab. ~11 Latin symbols fit.");
		
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:recentLocString image:[UIImage imageNamed:@"recentChats_black"] tag:0];
		if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
			self.tabBarItem.selectedImage = [UIImage imageNamed:@"recentChats_white"];
		} else {
			self.tabBarItem.selectedImage = [UIImage imageNamed:@"recentChats_blue"];
		}
		self.navigationItem.title = recentLocString;
		
		_unreadMessagesDict = [[NSMutableDictionary alloc] init];
        
        [self.view setBackgroundColor:kGrayColor_e5e5e5];
		
		_userActivityController = userActivityController;
		[_userActivityController subscribeForUpdates:self];
    }
    return self;
}


- (void)dealloc
{
	[_userActivityController unsubscribeForUpdates:self];
    [[UsersManager defaultManager] unsubscribeForUpdates:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

	if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(chatViewControllerDidAppear:) name:ChatViewControllerDidAppearNotification object:nil];
    [[UsersManager defaultManager] subscribeForUpdates:self];
	
	
	self.noActivityLabel.text = NSLocalizedStringWithDefaultValue(@"label_no-messages-no-missed-calls",
																  nil, [NSBundle mainBundle],
																  @"You have not received any messages or missed calls.",
																  @"You have not received any messages or missed calls.");
    
    self.cancelBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.editBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:kSMLocalStringEditButton
                                                              style:UIBarButtonItemStyleBordered
                                                             target:self
                                                             action:@selector(editTableButtonPressed)];
    
    self.noActivityLabel.font = [UIFont systemFontOfSize:kInformationTextFontSize];
    self.noActivityLabel.textColor = kSMTableViewHeaderTextColor;
	
	[self checkSetupUI];
}


- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self.tableView reloadData];
    [self checkSetupUI];
	/* 
	 We assume that if we present chatViewController it is presented in the way that if it is dissmissed 'self (RecentChatsViewController)' is shown again
	 so we can clear currently presented chat user id safely.
	 */
	_currentlyPresentedChatUserSessionId = nil;
	_currentlyPresentedChatController = nil;
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


#pragma mark - UI methods

- (void)checkSetupUI
{
	if ([_userActivityController.recentUsersSessionIdSorted count] > 0) {
		self.tableView.hidden = NO;
		self.noActivityLabel.hidden = YES;
        if (!self.navigationItem.rightBarButtonItem) {
            self.navigationItem.rightBarButtonItem = _editBarButtonItem;
        }
	} else {
		self.tableView.hidden = YES;
		self.noActivityLabel.hidden = NO;
        if (self.editing) {
            [self editTableButtonPressed];
        }
        self.navigationItem.rightBarButtonItem = nil;
	}
}


#pragma mark - Tabbar related functionality

- (void)updateTabbarBadgeCount
{
	NSUInteger unreadCount = [_unreadMessagesDict count];
	if (unreadCount > 0) {
		self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%d", unreadCount];
	} else {
		self.tabBarItem.badgeValue = nil;
	}
}


#pragma mark - Actions

-(void)cancel
{
    if (self.editing) {
        [self editTableButtonPressed];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)editTableButtonPressed
{
    if(self.editing)
    {
        [super setEditing:NO animated:NO];
        [self.tableView setEditing:NO animated:NO];
        [self.tableView reloadData];
        self.navigationItem.rightBarButtonItem.title = kSMLocalStringEditButton;
        self.navigationItem.leftBarButtonItem = nil;
        
    } else {
        
        [super setEditing:YES animated:YES];
        [self.tableView setEditing:YES animated:YES];
        [self.tableView reloadData];
        self.navigationItem.rightBarButtonItem.title = kSMLocalStringDoneButton;
        self.navigationItem.leftBarButtonItem = self.cancelBarButtonItem;
    }
}


#pragma mark - Private Methods

- (SMRCUserInfo *)getRecentUserInfoForUserSessionId:(NSString *)userSessionId
{
    SMRCUserInfo *userInfo = [[SMRCUserInfo alloc] init];
    userInfo.isActive = YES;
    userInfo.displayName = @"";
    userInfo.textIcon = [NSString fontAwesomeIconStringForEnum:FAUser];
    
    User *buddy = [[UsersManager defaultManager] userForSessionId:userSessionId];
    if (buddy) {
        userInfo.displayName = buddy.displayName;
    } else {
        if ([[UsersManager defaultManager] wasRoomVisited:userSessionId]) {
            userInfo.displayName = userSessionId;
            userInfo.textIcon = [NSString fontAwesomeIconStringForEnum:FAUsers];
            if ([userSessionId isEqualToString:DefaultRoomId]) {
                userInfo.displayName = [SMRoom defaultRoomName]; // TODO: Maybe create a method in ChannelingManager 'roomNameForRoomId:' to generalize rooms naming
            }
            spreed_me_log("Presenting ChatViewController. There is no buddy for userSessionId (%s). We assume this is room chat and set it's name.", [userSessionId cDescription]);
        } else {
            userInfo.isActive = NO;
            userInfo.displayName = NSLocalizedStringWithDefaultValue(@"label_user-is-offline",
																	 nil, [NSBundle mainBundle],
																	 @"Buddy is offline",
																	 @"Buddy is offline");
        }
    }
    
    return userInfo;
}


- (NSAttributedString *)attributedTextForUser:(NSString *)user withIcon:(NSString *)icon
{
    UIFont *font=[UIFont fontWithName:kFontAwesomeFamilyName size:20.0f];
    UIFont *font2=[UIFont systemFontOfSize:20.0f];
    
    NSString *missedCallText = [NSString stringWithFormat:@"%@  %@", icon, user];
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:missedCallText];
    
    [attrString addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, 1)];
    [attrString addAttribute:NSForegroundColorAttributeName value:[UIColor darkGrayColor] range:NSMakeRange(0,1)];
    [attrString addAttribute:NSFontAttributeName value:font2 range:NSMakeRange(1, [attrString length]-1)];
    
    return attrString;
}


- (void)chatViewControllerDidAppear:(NSNotification *)notification
{
	NSString *userSessionId = [notification.userInfo objectForKey:kChatControllerUserSessionIdKey];
	if (userSessionId) {
		if ([_currentlyPresentedChatUserSessionId isEqualToString:userSessionId] && _currentlyPresentedChatController.view.window) {
			[self clearUnreadMessagesForUserSessionId:userSessionId];
		}
	}
}


- (void)clearUnreadMessagesForUserSessionId:(NSString *)userSessionId
{
	[_unreadMessagesDict removeObjectForKey:userSessionId];
	[self updateTabbarBadgeCount];
}


- (void)addRecentUserWithUserSessionId:(NSString *)userSessionId andUnreadMessagesCount:(NSInteger)unreadMessagesCount
{
	NSNumber *unreadMessages = [_unreadMessagesDict objectForKey:userSessionId];
	[_unreadMessagesDict setObject:@([unreadMessages integerValue] + unreadMessagesCount) forKey:userSessionId];
	[self updateTabbarBadgeCount];
}


#pragma mark - Chats related functionality

- (STChatViewController *)presentChatViewControllerForUserSessionId:(NSString *)userSessionId
{
	if (userSessionId) {
		
        SMRCUserInfo *userInfo = [self getRecentUserInfoForUserSessionId:userSessionId];
		NSString *recentName = userInfo.displayName;
		
		STChatViewController *chatViewController = [[STChatViewController alloc] initWithNibName:@"STChatViewController" bundle:nil];
		ChatController *chatController = [[ChatController alloc] initWithUserActivityManager:[[UsersActivityController sharedInstance] userActivityManagerForUserSessionId:userSessionId]];
		chatController.chatViewController = chatViewController;
		chatViewController.chatController = chatController;
		chatViewController.chatName = recentName;
		
		// check if we (root controller) is visible.
		if (self.view.window == nil) {
		
			if (self.navigationController.topViewController != self) {
				[self.navigationController popToRootViewControllerAnimated:NO];
			}
			
			// we need to check if self.navigationController.topViewController != self before doing this check with visibleViewController
			if (self.navigationController.visibleViewController != self) {
				[self.navigationController.visibleViewController dismissViewControllerAnimated:NO completion:NULL];
			}
			
			[self.navigationController pushViewController:chatViewController animated:NO];
		} else {
			[self.navigationController setViewControllers:@[self, chatViewController] animated:YES];
		}
		
		_currentlyPresentedChatUserSessionId = [userSessionId copy];
        _currentlyPresentedChatController = chatViewController;
		return chatViewController;
	}
	
	return nil;
}


#pragma mark - Cell setup

- (void)setupCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
	NSString *userSessionId = [_userActivityController.recentUsersSessionIdSorted objectAtIndex:indexPath.row];
	
    SMRCUserInfo *userInfo = [self getRecentUserInfoForUserSessionId:userSessionId];
    NSAttributedString *recentName = [self attributedTextForUser:userInfo.displayName withIcon:userInfo.textIcon];
	
	cell.textLabel.attributedText = recentName;
    cell.accessoryView = nil;
	
	NSUInteger activitiesCount = [_userActivityController recentActivitiesCountForUserSessionId:userSessionId];
    
	if (activitiesCount) {
		id<UserRecentActivity> activity = [_userActivityController recentActivityAtIndex:(activitiesCount - 1) forUserSessionId:userSessionId];
		NSDateFormatter *dateFormatter = [[DateFormatterManager sharedInstance] defaultLocalizedShortDateTimeStyleFormatter];
		cell.detailTextLabel.text = [dateFormatter stringFromDate:[activity date]];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        [self setupNumberOfUnreadMessagesforCell:cell ofUserSessionId:userSessionId];
	}
}


- (void)setupNumberOfUnreadMessagesforCell:(UITableViewCell *)cell ofUserSessionId:(NSString *)userSessionId
{
    UserActivityManager *userAM = [_userActivityController userActivityManagerForUserSessionId:userSessionId];
    RoundedNumberView *unreadMessagesView = [[RoundedNumberView alloc]init];
    NSInteger numberOfUnreadMessages = [userAM getNumberOfUnreadMessages];
    
    unreadMessagesView.number = numberOfUnreadMessages;
    cell.accessoryView = unreadMessagesView;
    
    if (numberOfUnreadMessages > 0) {
        cell.accessoryView.hidden = NO;
    } else {
        cell.accessoryView.hidden = YES;
    }
    
}


#pragma mark - BuddyUpdates Protocol

- (void)roomUsersListUpdated
{
	[self.tableView reloadData];
}


#pragma mark - UserRecentActivityControllerUpdatesListener delegate

- (void)userActivityController:(UsersActivityController *)controller
				 userSessionId:(NSString *)userSessionId
			   hasBeenActiveAt:(NSString *)dayLimitedDateString
		   movedOnTopFromIndex:(NSUInteger)fromIndex

{
	if (![_currentlyPresentedChatUserSessionId isEqualToString:userSessionId] || !_currentlyPresentedChatController.view.window) {
		[self addRecentUserWithUserSessionId:userSessionId andUnreadMessagesCount:1];
        [[AudioManager defaultManager] playSoundForIncomingMessage];
	}
	
	// if fromIndex == 0 it means that no changes in order of users happened but the change happened in first cell;
	if (fromIndex == 0) {
		[self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
		return;
	}
	
	if (fromIndex != NSNotFound) {
		NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:fromIndex inSection:0];
		NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
		UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:fromIndexPath];
		if (cell) {
			[self setupCell:cell atIndexPath:toIndexPath];
			[cell setNeedsDisplay];
		}
		[self.tableView moveRowAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
	} else {
		[self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
	}
	
	[self checkSetupUI];
}


- (void)userActivityControllerDidPurgeAllHistory:(UsersActivityController *)controller
{
    [_unreadMessagesDict removeAllObjects];
    [self updateTabbarBadgeCount];
    
    [self.navigationController popToRootViewControllerAnimated:NO];
    
    _currentlyPresentedChatUserSessionId = nil;
    _currentlyPresentedChatController = nil;
    
    [self checkSetupUI];
    
    [self.tableView reloadData];
}


#pragma mark - UITableView Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_userActivityController.recentUsersSessionIdSorted count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"RecentChatCellIdentifier";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	
    if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
	}
	
	[self setupCell:cell atIndexPath:indexPath];
	
	return cell;
}


//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//{
//	return [_userActivityController.recentUsersIdSorted objectAtIndex:section];
//}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *userSessionId = [_userActivityController.recentUsersSessionIdSorted objectAtIndex:indexPath.row];
	[self clearUnreadMessagesForUserSessionId:userSessionId];
	_currentlyPresentedChatController = [self presentChatViewControllerForUserSessionId:userSessionId];
}


- (UITableViewCellEditingStyle)tableView:(UITableView *)aTableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.editing) {
        return UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleNone;
}


- (void)tableView:(UITableView *)aTableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *userSessionId = [_userActivityController.recentUsersSessionIdSorted objectAtIndex:indexPath.row];
        [_userActivityController removeAllUserActivitiesFromHistoryForUserSessionId:userSessionId];
        [self.tableView reloadData];
        [self checkSetupUI];
    }
}


@end
