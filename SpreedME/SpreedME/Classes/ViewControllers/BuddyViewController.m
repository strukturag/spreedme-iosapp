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

#import "BuddyViewController.h"

#import "BuddyFullInfoViewController.h"
#import "ChannelingManager.h"
#import "ChildRotationNavigationController.h"
#import "UsersManager.h"
#import "PeerConnectionController.h"
#import "RecentChatsViewController.h"
#import "SpreedMeRoundedButton.h"
#import "SMLocalizedStrings.h"
#import "SMSessionsRowModel.h"
#import "STChatViewController.h"
#import "STProgressView.h"
#import "STSectionModel.h"
#import "STRowModel.h"
#import "STUserViewHeaderTableViewCell.h"
#import "STUserViewTableViewCell.h"
#import "UserInterfaceManager.h"

// File sharing
#import "FileBrowserControllerViewController.h"
#import <FileSharingManagerObjC.h>

#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"


typedef enum : NSUInteger {
    kBuddyViewSectionHeader = 0,
    kBuddyViewSectionCall,
    kBuddyViewSectionChat,
    kBuddyViewSectionInCall,
    kBuddyViewSectionCount
} BuddyViewSections;


typedef enum : NSUInteger {
    kCallSectionVideoCall = 0,
    kCallSectionAudioCall
} CallSectionRows;

typedef enum : NSUInteger {
    kChatSectionSendMessage = 0,
    kChatSectionSendFile,
    kChatSectionShareLocation
} ChatSectionRows;

typedef enum : NSUInteger {
    kInCallSectionAddToCall = 0,
    kInCallSectionUserInCall
} InCallSectionRows;

typedef enum : NSUInteger {
    kHeaderSectionUserHeader = 0,
    kHeaderSectionUserHeaderDisclosed,
    kHeaderSectionUserSession
} HeaderSectionRows;


@interface BuddyViewController () <UserUpdatesProtocol, UITextFieldDelegate , UITableViewDataSource,
                                    UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                                    UIActionSheetDelegate, FileBrowserViewControllerDelegate, SMUserViewUpdates>
{
	id<SMUserView> _userView;
    id<SMUserView> _userWithPendingAction;
    User *_userSessionWithPendingAction;
    NSString *_filePathToSend;
    NSDictionary *_fileInfoToSend;
    
    NSMutableArray *_datasource;
    STSectionModel *_headerSection;
    STSectionModel *_callSection;
    STSectionModel *_chatSection;
    STSectionModel *_inCallSection;
    
    //header section
    STRowModel *_headerRow;
    STRowModel *_retrievingSessionsRow;
    
    //call section
    STRowModel *_videoCallRow;
    STRowModel *_audioCallRow;
    
    //chat section
    STRowModel *_sendMessageRow;
    STRowModel *_sendFileRow;
    STRowModel *_shareLocationRow;
    
    UIAlertController *_allActionaSheetController;
    UIActionSheet *_allActionsActionSheet;
    NSMutableDictionary *_allActionsDict;
    UIActionSheet *_shareFilesOptionsActionSheet;
    UIActionSheet *_confirmShareFileActionSheet;
    
    UIPopoverController *_popover;
    BOOL _isImagePickerInPopover;
    
    FileBrowserControllerViewController *_fileBrowserViewController;
}

@property (nonatomic, strong) IBOutlet UITableView *actionsTableView;
@property (nonatomic, strong) UIPopoverController *presentingPopover;

@end

@implementation BuddyViewController

#pragma mark - Object lifecycle

- (id)initWithUserView:(id<SMUserView>)userView
{
	self = [super initWithNibName:@"BuddyViewController" bundle:nil];
	if (self) {
		_userView = userView;
        
        [self initializeActionsTableView];
        
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHungUp:) name:UserHasLeftCallNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callIsFinished:) name:CallIsFinishedNotification object:nil];
		
		[[UsersManager defaultManager] subscribeForUpdates:self];
        if ([_userView respondsToSelector:@selector(subscribeForUpdates:)]) {
            [_userView subscribeForUpdates:self];
        }
    }
	
    return self;
}


- (void)initializeActionsTableView
{
    _datasource = [[NSMutableArray alloc] init];
    
    NSString *callSectionTitle = NSLocalizedStringWithDefaultValue(@"label_user-view_call",
                                                                   nil, [NSBundle mainBundle],
                                                                   @"Call",
                                                                   @"Table view section title for calling related operations performed by user.");
    
    NSString *chatSectionTitle = NSLocalizedStringWithDefaultValue(@"label_user-view_chat",
                                                                   nil, [NSBundle mainBundle],
                                                                   @"Chat",
                                                                   @"Table view section title for chatting related operations performed by user.");
    
    // Header Section
    _headerSection = [STSectionModel new];
    _headerSection.type = kBuddyViewSectionHeader;
    
    _headerRow = [SMSessionsRowModel new];
    _headerRow.type = kHeaderSectionUserHeader;
    _headerRow.rowHeight = [STUserViewHeaderTableViewCell cellHeight];
    [_headerSection.items addObject:_headerRow];
    
    [_datasource addObject:_headerSection];
    
    // Call Section
    _callSection = [STSectionModel new];
    _callSection.type = kBuddyViewSectionCall;
    _callSection.title =  callSectionTitle;
    
    _videoCallRow = [STRowModel new];
    _videoCallRow.type = kCallSectionVideoCall;
    _videoCallRow.rowHeight = [STUserViewTableViewCell cellHeight];
    _audioCallRow = [STRowModel new];
    _audioCallRow.type = kCallSectionAudioCall;
    _audioCallRow.rowHeight = [STUserViewTableViewCell cellHeight];
    
    [_callSection.items addObject:_videoCallRow];
    [_callSection.items addObject:_audioCallRow];
    
    [_datasource addObject:_callSection];
    
    // Chat Section
    _chatSection = [STSectionModel new];
    _chatSection.type = kBuddyViewSectionChat;
    _chatSection.title = chatSectionTitle;
    
    _sendMessageRow = [STRowModel new];
    _sendMessageRow.type = kChatSectionSendMessage;
    _sendMessageRow.rowHeight = [STUserViewTableViewCell cellHeight];
    _sendFileRow = [STRowModel new];
    _sendFileRow.type = kChatSectionSendFile;
    _sendFileRow.rowHeight = [STUserViewTableViewCell cellHeight];
    _shareLocationRow = [STRowModel new];
    _shareLocationRow.type = kChatSectionShareLocation;
    _shareLocationRow.rowHeight = [STUserViewTableViewCell cellHeight];
    
    [_chatSection.items addObject:_sendMessageRow];
    [_chatSection.items addObject:_sendFileRow];
    [_chatSection.items addObject:_shareLocationRow];
    
    [_datasource addObject:_chatSection];
    
    // InCall Section
    _inCallSection = [STSectionModel new];
    _inCallSection.type = kBuddyViewSectionInCall;
    _inCallSection.title =  callSectionTitle;
}


- (void)dealloc
{
	[[UsersManager defaultManager] unsubscribeForUpdates:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    if ([_userView respondsToSelector:@selector(unsubscribeForUpdates:)]) {
        [_userView unsubscribeForUpdates:self];
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


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self reloadHeaderSection];
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.view.backgroundColor = kGrayColor_e5e5e5;
    self.actionsTableView.contentInset = UIEdgeInsetsMake(-1.0f, 0.0f, 0.0f, 0.0); // Workaround to hide the first section header
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.actionsTableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.actionsTableView.backgroundView = nil;
    }
}


- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self checkCallSectionUI];
    
    [self.actionsTableView reloadData];
}


#pragma mark - Utils

- (BOOL)setUserSessionsOnHeaderSection
{
    [self hideHeaderSectionSessions];
    
    for (User *session in _userView.userSessions) {
        if (![[session sessionId] isEqualToString:[_userView sessionId]]) {
            SMSessionsRowModel *row = [SMSessionsRowModel new];
            row.title = [session displayName];
            row.subtitle = [session statusMessage];
            row.type = kHeaderSectionUserSession;
            row.image = [session iconImage];
            row.session = session;
            row.rowHeight = [STUserViewTableViewCell cellHeight];
            [_headerSection.items addObject:row];
        }
    }
    // The header is already one item in the header section
    if ([_headerSection.items count] > 1) {
        return YES;
    }
    return NO;
}


- (void)setHeaderSectionHeaderCellDisclosed:(BOOL)yesNo
{
    STRowModel *header = [_headerSection.items objectAtIndex:kHeaderSectionUserHeader];
    header.type = (yesNo) ? kHeaderSectionUserHeaderDisclosed : kHeaderSectionUserHeader;
}


- (BOOL)isHeaderSectionHeaderCellDisclosed
{
    STRowModel *header = [_headerSection.items objectAtIndex:kHeaderSectionUserHeader];
    return (header.type == kHeaderSectionUserHeaderDisclosed) ? YES : NO;
}


- (void)presentUserSessions
{
    if ([self setUserSessionsOnHeaderSection]) {
        [self setHeaderSectionHeaderCellDisclosed:YES];
        [self reloadHeaderSection];
    } else {
        [self reloadHeaderSection];
    }
}


- (void)hideHeaderSectionSessions
{
    [self setHeaderSectionHeaderCellDisclosed:NO];
    
    [_headerSection.items removeAllObjects];
    [_headerSection.items addObject:_headerRow];
    
    [self reloadHeaderSection];
    
    if (_allActionsActionSheet) {
        [_allActionsActionSheet dismissWithClickedButtonIndex:0 animated:YES];
    }
    if (_allActionaSheetController) {
        [_allActionaSheetController dismissViewControllerAnimated:YES completion:nil];
    }
}


- (void)reloadHeaderSection
{
    if ([_datasource containsObject:_headerSection]) {
        [self.actionsTableView reloadSections:[NSIndexSet indexSetWithIndex:[_datasource indexOfObject:_headerSection]]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}


#pragma mark - InCall UI

- (void)setUserInCallCell
{
    STRowModel *row = [STRowModel new];
    row.type = kInCallSectionUserInCall;
    row.rowHeight = [STUserViewTableViewCell cellHeight];
    [_inCallSection.items removeAllObjects];
    [_inCallSection.items addObject:row];
}


- (void)setAddToCallCell
{
    STRowModel *row = [STRowModel new];
    row.type = kInCallSectionAddToCall;
    row.rowHeight = [STUserViewTableViewCell cellHeight];
    [_inCallSection.items removeAllObjects];
    [_inCallSection.items addObject:row];
}


- (void)checkCallSectionUI
{
    [_datasource removeObject:_callSection];
    [_datasource removeObject:_inCallSection];
    
    if ([PeerConnectionController sharedInstance].inCall) {
        if (_userView.sessionId) {
            if (![[PeerConnectionController sharedInstance] isUserSessionIdInCall:_userView.sessionId]) {
                [self setAddToCallCell];
            } else {
                [self setUserInCallCell];
            }
            [_datasource insertObject:_inCallSection atIndex:kBuddyViewSectionCall];
        }
    } else {
        [_datasource insertObject:_callSection atIndex:kBuddyViewSectionCall];
    }
    
    [self.actionsTableView reloadData];
}


#pragma mark - Users update

- (void)userHasBeenUpdated:(User *)user
{
	if ([user.sessionId isEqualToString:_userView.sessionId]) {
        [self reloadHeaderSection];
        if ([self isHeaderSectionHeaderCellDisclosed]) {
            [self presentUserSessions];
        }
	}
}


- (void)userSessionHasJoinedRoom:(User *)user
{
    if ([user.sessionId isEqualToString:_userView.sessionId]) {
        [self reloadHeaderSection];
        if ([self isHeaderSectionHeaderCellDisclosed]) {
            [self presentUserSessions];
        }
    }
}


#pragma mark - Notifications

- (void)userHungUp:(NSNotification *)notification
{
	NSString *userSessionId = [notification.userInfo objectForKey:kUserSessionIdKey];
	
	if ([userSessionId isEqualToString:_userView.sessionId]) {
		[self checkCallSectionUI];
	}
}


- (void)callIsFinished:(NSNotification *)notification
{
	[self checkCallSectionUI];
}


- (void)userSessionHasLeft:(User *)user disconnectedFromServer:(BOOL)yesNo
{
    BOOL isVisible = (self.isViewLoaded && self.view.window);
    
    if (!_userView.userId) { // BuddyViewController's User doesn't have any sessions so we check against the reminder.
        if ([_buddyViewControllerUserId isEqualToString:user.userId]) {
            [[UserInterfaceManager sharedInstance] popToCurrentRoomViewControllerAnimated:isVisible];
        }
    } else if ([_userView.userId isEqualToString:user.userId]) {
        [self reloadHeaderSection];
        if ([self isHeaderSectionHeaderCellDisclosed]) {
            [self presentUserSessions];
        }
    } else if ([_userView.userId isEqualToString:user.sessionId]) { // An anonymous user has left the room
        [[UserInterfaceManager sharedInstance] popToCurrentRoomViewControllerAnimated:isVisible];
    }
}


#pragma mark - BuddyViewController Actions

- (STChatViewController *)presentChatWithUserSessionId:(NSString *)userSessionId
{
    RecentChatsViewController *recentsVC = [UserInterfaceManager sharedInstance].recentChatsViewController;
    STChatViewController *chatViewController = [recentsVC presentChatViewControllerForUserSessionId:userSessionId];
    [self.tabBarController setSelectedIndex:[UserInterfaceManager sharedInstance].recentChatsViewControllerTabbarIndex];
    return chatViewController;
}


- (void)presentChatToSendAMessageToUser:(id<SMUserView>)user
{
    [self presentChatToSendAMessageToUserSession:[[user userSessions] objectAtIndex:0]];
}


- (void)presentChatToSendAMessageToUserSession:(User *)session
{
    STChatViewController *chatViewController = [self presentChatWithUserSessionId:session.sessionId];
    [chatViewController presentChatInputViewKeyBoard];
}


- (void)presentChatAndSendLocationToUser:(id<SMUserView>)user
{
    [self presentChatAndSendLocationToUserSession:[[user userSessions] objectAtIndex:0]];
}


- (void)presentChatAndSendLocationToUserSession:(User *)session
{
    STChatViewController *chatViewController = [self presentChatWithUserSessionId:session.sessionId];
    [chatViewController shareUserCurrentLocation];
}


- (void)presentChatWithUser:(id<SMUserView>)user toShareFileWithPath:(NSString *)path
{
    [self presentChatWithUserSession:[[user userSessions] objectAtIndex:0] toShareFileWithPath:path];
}


- (void)presentChatWithUserSession:(User *)session toShareFileWithPath:(NSString *)path
{
    STChatViewController *chatViewController = [self presentChatWithUserSessionId:session.sessionId];
    [chatViewController shareUserSelectedFileAtPath:path];
}


- (void)presentChatWithUser:(id<SMUserView>)user toShareFileWithInfo:(NSDictionary *)info
{
    [self presentChatWithUserSession:[[user userSessions] objectAtIndex:0] toShareFileWithInfo:info];
}


- (void)presentChatWithUserSession:(User *)session toShareFileWithInfo:(NSDictionary *)info
{
    STChatViewController *chatViewController = [self presentChatWithUserSessionId:session.sessionId];
    [chatViewController shareUserSelectedFileWithInfo:info];
}


- (void)callToUser:(id<SMUserView>)user withVideo:(BOOL)withVideo
{
    [self callToUserSession:[[user userSessions] objectAtIndex:0] withVideo:withVideo];
}


- (void)callToUserSession:(User *)session withVideo:(BOOL)withVideo
{
    [[PeerConnectionController sharedInstance] callToBuddy:session withVideo:withVideo];
}


- (void)addUserToCall:(id<SMUserView>)user
{
    [self addUserSessionToCall:[[user userSessions] objectAtIndex:0]];
}


- (void)addUserSessionToCall:(User *)session
{

    [[UserInterfaceManager sharedInstance] presentCurrentModalCallingViewController];
    [[PeerConnectionController sharedInstance] addUserToCall:session withVideo:YES];
    
    [self checkCallSectionUI];
}


- (void)presentFileShareOptionsDialogForUser:(id<SMUserView>)user atIndexPath:(NSIndexPath *)indexPath
{
    _userWithPendingAction = user;
    _userSessionWithPendingAction = nil;
    [self presentFileShareOptionsDialogAtIndexPath:indexPath];
}


- (void)presentFileShareOptionsDialogForUserSession:(User *)session atIndexPath:(NSIndexPath *)indexPath
{
    _userSessionWithPendingAction = session;
    _userWithPendingAction = nil;
    [self presentFileShareOptionsDialogAtIndexPath:indexPath];
}


- (void)presentFileShareOptionsDialogAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *shareFileFromTitle = kSMLocalStringShareFileMessageTitle;
    NSString *photoLibLocButtonTitle = kSMLocalStringPhotoLibraryLabel;
    NSString *documentsDirLocButtonTitle = kSMLocalStringInAppDocumentDirectory;
    NSString *cancelButtonTitle = kSMLocalStringCancelButton;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        UIAlertController *actionSheetController = [UIAlertController alertControllerWithTitle:shareFileFromTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *photoLibraryAction = [UIAlertAction actionWithTitle:photoLibLocButtonTitle
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * action) {
                                                                       [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary atIndexPath:indexPath];
                                                                   }];
        
        UIAlertAction *documentsAction = [UIAlertAction actionWithTitle:documentsDirLocButtonTitle
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) {
                                                                    [self presentFileBrowserViewController];
                                                                }];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:cancelButtonTitle
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                           [actionSheetController dismissViewControllerAnimated:YES completion:nil];
                                                       }];
        
        [actionSheetController addAction:photoLibraryAction];
        [actionSheetController addAction:documentsAction];
        [actionSheetController addAction:cancel];
        
        UIPopoverPresentationController *popover = actionSheetController.popoverPresentationController;
        if (popover)
        {
            UITableViewCell *cell = [self.actionsTableView cellForRowAtIndexPath:indexPath];
            popover.sourceView = cell;
            popover.sourceRect = cell.bounds;
            popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        }
        
        [self presentViewController:actionSheetController animated:YES completion:nil];
        
    } else {
        _shareFilesOptionsActionSheet = [[UIActionSheet alloc] initWithTitle:shareFileFromTitle
                                                                    delegate:self
                                                           cancelButtonTitle:cancelButtonTitle
                                                      destructiveButtonTitle:nil
                                                           otherButtonTitles:photoLibLocButtonTitle, documentsDirLocButtonTitle, nil];
        
        if (self.tabBarController) {
            [_shareFilesOptionsActionSheet showFromTabBar:self.tabBarController.tabBar];
        } else {
            [_shareFilesOptionsActionSheet showInView:self.view];
        }
    }
}


- (void)presentAllActionsDialogForUserSession:(User *)session atIndexPath:(NSIndexPath *)indexPath
{
    NSString *videocallButtonTitle = kSMLocalStringVideoCallButton;
    NSString *voicecallButtonTitle = kSMLocalStringVoiceCallButton;
    NSString *addToCallButtonTitle = kSMLocalStringAddToCallButton;
    NSString *sendMessageButtonTitle = kSMLocalStringSendMessageButton;
    NSString *shareFileButtonTitle = kSMLocalStringShareFileButton;
    NSString *shareLocationButtonTitle = kSMLocalStringShareLocationButton;
    NSString *cancelButtonTitle = kSMLocalStringCancelButton;
    
    _userSessionWithPendingAction = session;
    _userWithPendingAction = nil;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        _allActionaSheetController = [UIAlertController alertControllerWithTitle:[session displayName] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *videocallAction = [UIAlertAction actionWithTitle:videocallButtonTitle
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) {
                                                                        [self callToUserSession:session withVideo:YES];
                                                                }];
        
        UIAlertAction *voicecallAction = [UIAlertAction actionWithTitle:voicecallButtonTitle
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) {
                                                                    [self callToUserSession:session withVideo:NO];
                                                                }];
        
        UIAlertAction *sendMessageAction = [UIAlertAction actionWithTitle:sendMessageButtonTitle
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * action) {
                                                                      [self presentChatToSendAMessageToUserSession:session];
                                                                  }];
        
        UIAlertAction *shareFileAction = [UIAlertAction actionWithTitle:shareFileButtonTitle
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) {
                                                                    [self presentFileShareOptionsDialogForUserSession:session atIndexPath:indexPath];
                                                                }];
        
        UIAlertAction *shareLocationAction = [UIAlertAction actionWithTitle:shareLocationButtonTitle
                                                                      style:UIAlertActionStyleDefault
                                                                    handler:^(UIAlertAction * action) {
                                                                        [self presentChatAndSendLocationToUserSession:session];
                                                                    }];
        
        UIAlertAction *addToCallAction = [UIAlertAction actionWithTitle:addToCallButtonTitle
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) {
                                                                    [self addUserSessionToCall:session];
                                                                }];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:cancelButtonTitle
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                           [_allActionaSheetController dismissViewControllerAnimated:YES completion:nil];
                                                       }];
        
        if ([PeerConnectionController sharedInstance].inCall) {
            if (![[PeerConnectionController sharedInstance] isUserSessionIdInCall:session.sessionId]) {
                [_allActionaSheetController addAction:addToCallAction];
            }
        } else {
            [_allActionaSheetController addAction:videocallAction];
            [_allActionaSheetController addAction:voicecallAction];
        }
        
        [_allActionaSheetController addAction:sendMessageAction];
        [_allActionaSheetController addAction:shareFileAction];
        [_allActionaSheetController addAction:shareLocationAction];
        [_allActionaSheetController addAction:cancel];
        
        UIPopoverPresentationController *popover = _allActionaSheetController.popoverPresentationController;
        if (popover)
        {
            UITableViewCell *cell = [self.actionsTableView cellForRowAtIndexPath:indexPath];
            popover.sourceView = cell;
            popover.sourceRect = cell.bounds;
            popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        }
        
        [self presentViewController:_allActionaSheetController animated:YES completion:nil];
        
    } else {
        _allActionsActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
        _allActionsDict = [[NSMutableDictionary alloc] init];
        __weak BuddyViewController* weakSelf = self;
        
        if ([PeerConnectionController sharedInstance].inCall) {
            if (![[PeerConnectionController sharedInstance] isUserSessionIdInCall:session.sessionId]) {
                [_allActionsDict setObject:^{__strong BuddyViewController*strongSelf = weakSelf; [strongSelf addUserSessionToCall:session];}
                                    forKey:@([_allActionsActionSheet addButtonWithTitle:addToCallButtonTitle])];
            }
        } else {
            [_allActionsDict setObject:^{__strong BuddyViewController*strongSelf = weakSelf; [strongSelf callToUserSession:session withVideo:YES];}
                                forKey:@([_allActionsActionSheet addButtonWithTitle:videocallButtonTitle])];
            
            [_allActionsDict setObject:^{__strong BuddyViewController*strongSelf = weakSelf; [strongSelf callToUserSession:session withVideo:NO];}
                                forKey:@([_allActionsActionSheet addButtonWithTitle:voicecallButtonTitle])];
        }
        
        [_allActionsDict setObject:^{__strong BuddyViewController*strongSelf = weakSelf; [strongSelf presentChatToSendAMessageToUserSession:session];}
                            forKey:@([_allActionsActionSheet addButtonWithTitle:sendMessageButtonTitle])];
        
        [_allActionsDict setObject:^{__strong BuddyViewController*strongSelf = weakSelf; [strongSelf presentFileShareOptionsDialogForUserSession:session atIndexPath:indexPath];}
                            forKey:@([_allActionsActionSheet addButtonWithTitle:shareFileButtonTitle])];
        
        [_allActionsDict setObject:^{__strong BuddyViewController*strongSelf = weakSelf; [strongSelf presentChatAndSendLocationToUserSession:session];}
                            forKey:@([_allActionsActionSheet addButtonWithTitle:shareLocationButtonTitle])];
        
        _allActionsActionSheet.cancelButtonIndex = [_allActionsActionSheet addButtonWithTitle:cancelButtonTitle];
        
        if (self.tabBarController) {
            [_allActionsActionSheet showFromTabBar:self.tabBarController.tabBar];
        } else {
            [_allActionsActionSheet showInView:self.view];
        }
    }
}


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    switch (sectionModel.type) {
            
        case kBuddyViewSectionHeader:
            switch (rowModel.type) {
                case kHeaderSectionUserHeader:
                    [self presentUserSessions];
                    break;
                case kHeaderSectionUserHeaderDisclosed:
                    [self hideHeaderSectionSessions];
                    break;
                case kHeaderSectionUserSession:
                    [self presentAllActionsDialogForUserSession:[(SMSessionsRowModel *)[_headerSection.items objectAtIndex:indexPath.row] session] atIndexPath:indexPath];
                    break;
                    
                default:
                    break;
            }
            break;
            
        case kBuddyViewSectionCall:
            switch (rowModel.type) {
                case kCallSectionVideoCall:
                    [self callToUser:_userView withVideo:YES];
                    break;
                    
                case kCallSectionAudioCall:
                    [self callToUser:_userView withVideo:NO];
                    break;
                    
                default:
                    break;
            }
            break;
            
        case kBuddyViewSectionChat:
            switch (rowModel.type) {
                case kChatSectionSendMessage:
                    [self presentChatToSendAMessageToUser:_userView];
                    break;
                    
                case kChatSectionSendFile:
                    [self presentFileShareOptionsDialogForUser:_userView atIndexPath:indexPath];
                    break;
                    
                case kChatSectionShareLocation:
                    [self presentChatAndSendLocationToUser:_userView];
                    break;
                    
                default:
                    break;
            }
            break;
        
        case kBuddyViewSectionInCall:
            switch (rowModel.type) {
                case kInCallSectionAddToCall:
                    [self addUserToCall:_userView];
                    break;
                    
                default:
                    break;
            }
            break;
            
        default:
            break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    return rowModel.rowHeight;
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
    
    numberOfRows = sectionModel.items.count;
    
    return numberOfRows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    STUserViewTableViewCell *cell = nil;
    
    static NSString *UserViewHeaderCellIdentifier = @"UserViewHeaderCellIdentifier";
    static NSString *VideoCallCellIdentifier = @"VideoCallCellIdentifier";
    static NSString *AudioCallCellIdentifier = @"AudioCallCellIdentifier";
    static NSString *SendMessageCellIdentifier = @"SendMessageCellIdentifier";
    static NSString *SendFileCellIdentifier = @"SendFileCellIdentifier";
    static NSString *ShareLocationCellIdentifier = @"ShareLocationCellIdentifier";
    static NSString *UserSessionCellIdentifier = @"UserSessionCellIdentifier";
    static NSString *AddToCallCellIdentifier = @"AddToCallCellIdentifier";
    static NSString *UserInCallCellIdentifier = @"UserInCallCellIdentifier";
    
    
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    switch (sectionModel.type) {
        case kBuddyViewSectionCall:
        {
            switch (rowModel.type) {
                case kCallSectionVideoCall:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:VideoCallCellIdentifier];
                    if (!cell) {
                        cell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:VideoCallCellIdentifier];
                    }
                    
                    [cell setupWithTitle:kSMLocalStringVideoCallButton subtitle:nil
                                iconText:[NSString fontAwesomeIconStringForEnum:FAVideoCamera]
                           iconTextColor:kSMGreenButtonColor];
                }
                    break;
                    
                case kCallSectionAudioCall:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:AudioCallCellIdentifier];
                    if (!cell) {
                        cell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:AudioCallCellIdentifier];
                    }
                    
                    [cell setupWithTitle:kSMLocalStringVoiceCallButton subtitle:nil
                                iconText:[NSString fontAwesomeIconStringForEnum:FAPhone]
                           iconTextColor:kSMGreenButtonColor];
                }
                    break;
                    
                default:
                    break;
            }
            
            
        }
            break;
            
        case kBuddyViewSectionChat:
        {
            switch (rowModel.type) {
                case kChatSectionSendMessage:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:SendMessageCellIdentifier];
                    if (!cell) {
                        cell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SendMessageCellIdentifier];
                    }
                    
                    [cell setupWithTitle:kSMLocalStringSendMessageButton subtitle:nil
                                iconText:[NSString fontAwesomeIconStringForEnum:FAComments]
                           iconTextColor:kSMBlueButtonColor];
                }
                    break;
                    
                case kChatSectionSendFile:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:SendFileCellIdentifier];
                    if (!cell) {
                        cell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SendFileCellIdentifier];
                    }
                    
                    [cell setupWithTitle:kSMLocalStringShareFileButton subtitle:nil
                                iconText:[NSString fontAwesomeIconStringForEnum:FAFilesO]
                           iconTextColor:kSMBlueButtonColor];
                }
                    break;
                
                case kChatSectionShareLocation:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:ShareLocationCellIdentifier];
                    if (!cell) {
                        cell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ShareLocationCellIdentifier];
                    }
                    
                    [cell setupWithTitle:kSMLocalStringShareLocationButton subtitle:nil
                                iconText:[NSString fontAwesomeIconStringForEnum:FALocationArrow]
                           iconTextColor:kSMBlueButtonColor];
                }
                    break;
                    
                default:
                    break;
            }
        }
            break;
            
        case kBuddyViewSectionInCall:
        {
            switch (rowModel.type) {
                case kInCallSectionAddToCall:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:AddToCallCellIdentifier];
                    if (!cell) {
                        cell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:AddToCallCellIdentifier];
                    }
                    
                    [cell setupWithTitle:kSMLocalStringAddToCallButton subtitle:nil
                                iconText:[NSString fontAwesomeIconStringForEnum:FAPlus]
                           iconTextColor:kSMGreenButtonColor];
                }
                    break;
                    
                case kInCallSectionUserInCall:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:UserInCallCellIdentifier];
                    if (!cell) {
                        cell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:UserInCallCellIdentifier];
                    }
                    
                    [cell setupWithTitle:kSMLocalStringUserInCallMessageTitle subtitle:nil
                                iconText:[NSString fontAwesomeIconStringForEnum:FAPhone]
                           iconTextColor:[UIColor lightGrayColor]];
                    
                    cell.userInteractionEnabled = NO;
                    cell.titleLabel.enabled = NO;
                }
                    break;
                    
                default:
                    break;
            }
        }
            break;
            
        case kBuddyViewSectionHeader:
        {
            switch (rowModel.type) {
                case kHeaderSectionUserHeader:
                {
                    STUserViewHeaderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UserViewHeaderCellIdentifier];
                    if (!cell) {
                        cell = [[STUserViewHeaderTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:UserViewHeaderCellIdentifier];
                    }
                    
                    [cell setupWithUserView:_userView disclosed:NO];
                    
                    return cell;
                }
                case kHeaderSectionUserHeaderDisclosed:
                {
                    STUserViewHeaderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UserViewHeaderCellIdentifier];
                    if (!cell) {
                        cell = [[STUserViewHeaderTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:UserViewHeaderCellIdentifier];
                    }
                    
                    [cell setupWithUserView:_userView disclosed:YES];
                    
                    return cell;
                }
                    break;
                    
                case kHeaderSectionUserSession:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:UserSessionCellIdentifier];
                    if (!cell) {
                        cell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:UserSessionCellIdentifier];
                    }
                    
                    [cell setupWithTitle:rowModel.title subtitle:rowModel.subtitle iconImage:rowModel.image];
                }
                    break;
                    
                default:
                    break;
            }
        }
            break;
            
        default:
            break;
    }
    
    return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == kBuddyViewSectionHeader) {
        return nil;
    }
    
    STSectionModel *sectionModel = _datasource[section];
    NSString *title = sectionModel.title;
    return title;
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == kBuddyViewSectionHeader) {
        return 1.0f; // Workaround to hide header section. In ViewDidLoad we hide it changing tableview insets.
    }
    
    return kTableViewHeaderHeight;
}


- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return kTableViewFooterHeight;
}


#pragma mark - UIActionSheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (actionSheet == _shareFilesOptionsActionSheet) {
        if (buttonIndex == 0) {
            [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary atIndexPath:nil];
        } else if (buttonIndex == 1){
            [self presentFileBrowserViewController];
        }
        _shareFilesOptionsActionSheet = nil;
        
    } else if (actionSheet == _confirmShareFileActionSheet) {
        if (buttonIndex == 0) { // index == 0 for "Set" button
            [self hideImagePicker];
        } else { // index == 1 for "Cancel" button
            [self hideImagePicker];
        }
        _confirmShareFileActionSheet = nil;
        
    } else if (actionSheet == _allActionsActionSheet) {
        void(^actionBlock)() = [_allActionsDict objectForKey:@(buttonIndex)];
        if (actionBlock) {
            actionBlock();
        } else {
            [_allActionsActionSheet dismissWithClickedButtonIndex:buttonIndex animated:YES];
        }
        _allActionsActionSheet = nil;
    }
}


#pragma mark - File Sharing Actions

- (void)presentFileBrowserViewController
{
    NSString *directory = [[FileSharingManagerObjC defaultManager] fileLocation];
    _fileBrowserViewController = [[FileBrowserControllerViewController alloc] initWithDirectoryPath:directory];
    _fileBrowserViewController.hasDismissButton = YES;
    _fileBrowserViewController.delegate = self;
    ChildRotationNavigationController *navController = [[ChildRotationNavigationController alloc] initWithRootViewController:_fileBrowserViewController];
    [self.navigationController presentViewController:navController animated:YES completion:nil];
}


- (void)showImagePickerWithSourceType:(UIImagePickerControllerSourceType)sourceType atIndexPath:(NSIndexPath *)indexPath
{
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    
    if (imagePicker) {
        imagePicker.delegate = self;
        imagePicker.sourceType = sourceType;
        imagePicker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:
                                  sourceType];
        if (sourceType == UIImagePickerControllerSourceTypeCamera) {
            [self presentViewController:imagePicker animated:YES completion:nil];
            _isImagePickerInPopover = NO;
            
        } else if (sourceType == UIImagePickerControllerSourceTypePhotoLibrary || sourceType == UIImagePickerControllerSourceTypeSavedPhotosAlbum) {
            
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && !self.presentingPopover) {
                _popover = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
                if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
                    imagePicker.navigationBar.tintColor = [UIColor grayColor];
                    imagePicker.navigationBar.barTintColor = kGrayColor_f5f5f5;
                }
                UITableViewCell *cell = [self.actionsTableView cellForRowAtIndexPath:indexPath];
                [_popover presentPopoverFromRect:cell.frame
                                          inView:self.actionsTableView
                        permittedArrowDirections:UIPopoverArrowDirectionAny
                                        animated:YES];
                
                _isImagePickerInPopover = YES;
            } else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && self.presentingPopover)  {
                [self.presentingPopover setContentViewController:imagePicker animated:YES];
                _isImagePickerInPopover = YES;
            } else {
                [self presentViewController:imagePicker animated:YES completion:nil];
                _isImagePickerInPopover = NO;
            }
        }
    } else {
        // Problem with camera, alert user
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:kSMLocalStringNoCameraMessageTitle
                                                        message:kSMLocalStringNoCameraMessageBody
                                                       delegate:nil
                                              cancelButtonTitle:kSMLocalStringSadOKButton
                                              otherButtonTitles:nil];
        [alert show];
    }
}


- (void)hideImagePicker
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && !self.presentingPopover) {
        [_popover dismissPopoverAnimated:YES];
    } else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && self.presentingPopover)  {
        if (_isImagePickerInPopover) {
            [self.presentingPopover setContentViewController:self animated:YES];
        } else {
            [self dismissViewControllerAnimated:YES completion:NULL];
        }
    } else {
        [self dismissViewControllerAnimated:YES completion:NULL];
    }
}


- (void)pickUpMovieOrImageToShare:(id)sender
{
    [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum atIndexPath:nil];
}


#pragma mark - UIImagePickerViewControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self hideImagePicker];
}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self hideImagePicker];
    
    if (_userWithPendingAction) {
        [self presentChatWithUser:_userWithPendingAction toShareFileWithInfo:info];
        _userWithPendingAction = nil;
    }
    
    if (_userSessionWithPendingAction) {
        [self presentChatWithUserSession:_userSessionWithPendingAction toShareFileWithInfo:info];
        _userSessionWithPendingAction = nil;
    }
}


#pragma mark - UINavigationController Delegate for UIImagePickerController

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        if ([navigationController isKindOfClass:[UIImagePickerController class]]) {
            navigationController.navigationBar.topItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                                                         target:self
                                                                                                                         action:@selector(imagePickerControllerDidCancel:)];
        }
    }
}


#pragma mark - FileBrowserViewController Delegate

- (void)fileBrowser:(STFileBrowserViewController *)fileBrowser didPickFileAtPath:(NSString *)path
{
    [_fileBrowserViewController dismiss];
    
    if (_userWithPendingAction) {
        [self presentChatWithUser:_userWithPendingAction toShareFileWithPath:path];
        _userWithPendingAction = nil;
    }
    
    if (_userSessionWithPendingAction) {
        [self presentChatWithUserSession:_userSessionWithPendingAction toShareFileWithPath:path];
        _userSessionWithPendingAction = nil;
    }
}


- (BOOL)fileBrowser:(STFileBrowserViewController *)fileBrowser shouldPresentDocumentsControllerForFileAtPath:(NSString *)path
{
    return NO;
}


@end
