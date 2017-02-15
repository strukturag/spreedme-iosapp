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

#import "STChatViewController.h"

#import "ChildRotationNavigationController.h"
#import "CommonUIDefinitions.h"

//Cells
#import "STChatGeneralTableViewCell.h"

#import "STChatFileTableViewCell.h"
#import "STChatGeolocationViewCell.h"
#import "STChatImageTableViewCell.h"
#import "STChatServiceTableViewCell.h"
#import "STChatTextTableViewCell.h"

// Input View (Textfield and control buttons)
#import "STChatInputView.h"

// Keyboard control library
#import "DAKeyboardControl.h"

// File sharing
#import "FileBrowserControllerViewController.h"
#import <FileSharingManagerObjC.h>

// Fonts
#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"

// Audio
#import "AudioManager.h"

// Progress view
#import "STProgressView.h"

// Localization
#import "SMLocalizedStrings.h"

static NSString *serviceCellIdentifier = @"_Service_cellIdentifier";
static NSString *textCellIdentifier = @"_Text_cellIdentifier";
static NSString *imageCellIdentifier = @"_Image_cellIdentifier";
static NSString *fileDownloadCellIdentifier = @"_FileDownload_cellIdentifier";
static NSString *geolocationCellIdentifier = @"_Geolocation_cellIdentifier";

#define kChatViewControllerClearChatAlertViewTag			1
#define kChatViewControllerStopSharingFileAlertViewTag		2

@interface STChatViewController () <UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate,
									STChatInputViewDelegate, STChatFileTableViewCellDelegate, STChatGeolocationViewCellDelegate, 
									UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate, FileBrowserViewControllerDelegate>
{
	BOOL _userActivityDisabled;
    BOOL _typingNotificationIsShown;
    BOOL _keyboardIsShown;
    BOOL _keyboardShouldBePresented;
    
    NSInteger _unreadMessages;
    NSIndexPath *_lastReadIndexPath;
    NSIndexPath *_lastSentReadIndexPath;
    NSTimer *_readMessagesNotificationTimer;
    
    NSInteger _fileToBeRemovedIndex;
    	
	UIActionSheet *_actionsActionSheet;
    UIActionSheet *_sharingFilesOptionsActionSheet;
	UIActionSheet *_confirmShareFileActionSheet;
	
	UIPopoverController *_popover;
	BOOL _isImagePickerInPopover;
    
    AVAudioPlayer *_audioPlayer;
    
    FileBrowserControllerViewController *_fileBrowserViewController;
}


@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet STChatInputView *inputToolBarView;

@property (nonatomic, strong) IBOutlet UIView *footerTypingNotificationsView;
@property (nonatomic, strong) UILabel *typingNotificationLabel;

@property (nonatomic, strong) IBOutlet UIView *unreadMessagesNotificationsView;
@property (nonatomic, strong) UILabel *unreadMessagesLabel;

@property (nonatomic, strong) UIView *sendingCurrentLocationView;

@property (nonatomic, strong) UIPopoverController *presentingPopover;

@end

@implementation STChatViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _lastSentReadIndexPath = [NSIndexPath indexPathForRow:-1 inSection:0];
        _lastReadIndexPath = [NSIndexPath indexPathForRow:-1 inSection:0];
    }
    return self;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.inputToolBarView.delegate = self;
	self.navigationItem.title = self.chatName;
	
	if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
		self.edgesForExtendedLayout = UIRectEdgeNone;
	}
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
		self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    self.view.backgroundColor = kGrayColor_e5e5e5;
	
	[self.tableView registerClass:[STChatFileTableViewCell class] forCellReuseIdentifier:fileDownloadCellIdentifier];
    [self.tableView registerClass:[STChatGeolocationViewCell class] forCellReuseIdentifier:geolocationCellIdentifier];
	[self.tableView registerClass:[STChatImageTableViewCell class] forCellReuseIdentifier:imageCellIdentifier];
	[self.tableView registerClass:[STChatServiceTableViewCell class] forCellReuseIdentifier:serviceCellIdentifier];
	[self.tableView registerClass:[STChatTextTableViewCell class] forCellReuseIdentifier:textCellIdentifier];
	
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.tableView.allowsSelection = NO;
	self.tableView.allowsSelectionDuringEditing = YES;
    [self.tableView setBackgroundColor:[UIColor whiteColor]];
	
	CGSize tbSize = CGSizeZero;
    if (self.tabBarController.tabBar) {
        tbSize = self.tabBarController.tabBar.frame.size;
    }
	CGRect tableViewFrame = self.tableView.frame;
	tableViewFrame.size.height = self.inputToolBarView.frame.origin.y - self.tableView.frame.origin.y + tbSize.height - self.inputToolBarView.frame.size.height;
	self.tableView.frame = tableViewFrame;
    
    UIButton *clearChatBarButton = [UIButton buttonWithType: UIButtonTypeCustom];
    clearChatBarButton.titleLabel.font = [UIFont fontWithName:kFontAwesomeFamilyName size:20];
    [clearChatBarButton setTitle:[NSString fontAwesomeIconStringForEnum:FAEraser] forState:UIControlStateNormal];
    [clearChatBarButton setTitleColor:kSMBarButtonColor forState:UIControlStateNormal];
    [clearChatBarButton setTitleColor:kSMBarButtonHighlightedColor forState:UIControlStateHighlighted];
    [clearChatBarButton addTarget:self action:@selector(askUserToClearChatMessages) forControlEvents:UIControlEventTouchUpInside];
    clearChatBarButton.frame = CGRectMake(0, 0, 30, 30);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView: clearChatBarButton];
    
	[self createFooterForTypingNotifications];
    [self createUnreadMessagesNotification];
    [self createSendingLocationView];
	
	[self.tableView reloadData];
	
	if (_userActivityDisabled) {
		[self setUserActivityEnabled:NO];
	}
}


// This method should be called only once on viewDidLoad
- (void)createFooterForTypingNotifications
{
	self.typingNotificationLabel = [[UILabel alloc] initWithFrame:self.footerTypingNotificationsView.bounds];
    self.typingNotificationLabel.autoresizingMask = self.footerTypingNotificationsView.autoresizingMask;
	self.typingNotificationLabel.backgroundColor = [UIColor whiteColor];
	[self.footerTypingNotificationsView addSubview:self.typingNotificationLabel];
    self.typingNotificationLabel.hidden = YES;
    [self.footerTypingNotificationsView setHidden:YES];
}


// This method should be called only once on viewDidLoad
- (void)createUnreadMessagesNotification
{
	self.unreadMessagesLabel = [[UILabel alloc] initWithFrame:self.unreadMessagesNotificationsView.bounds];
    self.unreadMessagesLabel.autoresizingMask = self.unreadMessagesNotificationsView.autoresizingMask;
    self.unreadMessagesLabel.backgroundColor = kSpreedMeBlueColorAlpha06;
    self.unreadMessagesLabel.textAlignment = NSTextAlignmentCenter;
	[self.unreadMessagesNotificationsView addSubview:self.unreadMessagesLabel];
    self.unreadMessagesLabel.hidden = YES;
    [self.unreadMessagesNotificationsView setHidden:YES];
}


// This method should be called only once on viewDidLoad
- (void)createSendingLocationView
{
	self.sendingCurrentLocationView = [[STProgressView alloc] initWithWidth:240.0f
																	message:NSLocalizedStringWithDefaultValue(@"label_sending-current-location",
																											  nil, [NSBundle mainBundle],
																											  @"Sending current location",
																											  @"Text for activity indicator")
																	   font:nil
														   cancelButtonText:nil
																   userInfo:nil];
	self.sendingCurrentLocationView.frame = CGRectMake(40.0f, 92.0f,
													   self.sendingCurrentLocationView.frame.size.width,
													   self.sendingCurrentLocationView.frame.size.height);
    
    self.sendingCurrentLocationView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                                        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	
	[self.view addSubview:self.sendingCurrentLocationView];
	
	
    self.sendingCurrentLocationView.layer.cornerRadius = 5.0;
    self.sendingCurrentLocationView.backgroundColor = [[UIColor alloc] initWithRed:0.0 green:0.0 blue:0.0 alpha:0.6];
    self.sendingCurrentLocationView.hidden = YES;
}


- (void)viewWillAppear:(BOOL)animated
{
    [self setupKeyboardPanGestureControl];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeShown:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [self checkMessagesWhenChatWillAppear];
}


- (void)viewDidAppear:(BOOL)animated
{
    [self setWasSeen:YES];
    
	if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewControllerDidAppear:)]) {
		[self.delegate chatViewControllerDidAppear:self];
	}
    
    [self checkIfKeyboardShouldBePresented];
}


- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    if (self.isViewLoaded && self.view.window) {
        [self checkMessagesWhenChatWillAppear];
    }
}


- (void)viewWillDisappear:(BOOL)animated
{
    [self disposeOfKeyboardPanGestureControl];
    
    if ([_readMessagesNotificationTimer isValid]) {
        [self checkSentReadMessagesNotification];
        [_readMessagesNotificationTimer invalidate];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - UIScrollView Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGPoint translation = [scrollView.panGestureRecognizer translationInView:scrollView.superview];
    
    if(translation.y < 0){
        [self checkReadMessages];
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


#pragma mark - Keyboard handling

// Every call to this method should be balanced with call to 'disposeOfKeyboardPanGestureControl'
- (void)setupKeyboardPanGestureControl
{
    self.view.keyboardTriggerOffset = _inputToolBarView.frame.size.height;
    
    CGSize tbSize = CGSizeZero;
    if (self.tabBarController.tabBar) {
        tbSize = self.tabBarController.tabBar.frame.size;
    }
    
    UIView *selfView = self.view;
    UITableView *tableView = _tableView;
    STChatInputView *inputToolBarView = _inputToolBarView;
	UIView *footerTypingNotificationsView = _footerTypingNotificationsView;
    UIView *unreadMessagesNotificationsView = _unreadMessagesNotificationsView;
    
    [self.view addKeyboardPanningWithActionHandler:^(CGRect keyboardFrameInView, BOOL opening, BOOL closing) {
        CGRect inputToolBarViewFrame = inputToolBarView.frame;
        CGRect footerNotificationFrame = footerTypingNotificationsView.frame;
        CGRect unreadNotificationFrame = unreadMessagesNotificationsView.frame;
        CGRect tableViewFrame = tableView.frame;
        
        if (keyboardFrameInView.origin.y < selfView.frame.size.height) {
            inputToolBarViewFrame.origin.y = keyboardFrameInView.origin.y - inputToolBarViewFrame.size.height;
        } else {
            inputToolBarViewFrame.origin.y = selfView.frame.size.height - inputToolBarViewFrame.size.height;
        }
        
        footerNotificationFrame.origin.y = inputToolBarViewFrame.origin.y - footerNotificationFrame.size.height;
        unreadNotificationFrame.origin.y = inputToolBarViewFrame.origin.y - unreadNotificationFrame.size.height;
        inputToolBarView.frame = inputToolBarViewFrame;
        footerTypingNotificationsView.frame = footerNotificationFrame;
        unreadMessagesNotificationsView.frame = unreadNotificationFrame;
        
        tableViewFrame.size.height = inputToolBarViewFrame.origin.y - tableView.frame.origin.y;
        tableView.frame = tableViewFrame;
    }];
}


- (void)disposeOfKeyboardPanGestureControl
{
    [self.view removeKeyboardControl];
}


- (void)keyboardWillBeShown:(NSNotification *)notification
{
    NSUInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
	_keyboardIsShown = YES;
	
	if (numberOfRows > 0) {
		
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:numberOfRows-1 inSection:0];
		
		if ([self isChatViewScrolledToTheBottom] && numberOfRows>0) {
			[self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
		}
	}
}


- (void)keyboardWillBeHidden:(NSNotification *)notification
{
    _keyboardIsShown = NO;
}


- (void)keyboardDidShow:(NSNotification *)notification
{
    if (_keyboardShouldBePresented) {
        _keyboardShouldBePresented = NO;
        CGFloat scrollViewHeight = self.tableView.frame.size.height;
        CGFloat scrollContentSizeHeight = self.tableView.contentSize.height;
        
        NSUInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
        
        if (numberOfRows > 0 && _lastReadIndexPath.row > 0 && scrollContentSizeHeight > scrollViewHeight) {
            [[self tableView] scrollToRowAtIndexPath:_lastReadIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    }
}


#pragma mark - Setters/Getters implementation

- (void)setChatController:(id<STChatViewControllerDataSource,STChatViewControllerDelegate>)chatController
{
	if (_chatController != chatController) {
		_chatController = chatController;
		self.delegate = chatController;
		self.datasource = chatController;
	}
}


#pragma mark - Unread message send notification

- (void)readNotificationTimerTicked:(NSTimer*)timer
{
    [self checkSentReadMessagesNotification];
}


- (void)checkSentReadMessagesNotification
{
    if (_lastReadIndexPath.row > _lastSentReadIndexPath.row) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(sendMessageReadNotification:untilIndex:)]) {
            [self.delegate sendMessageReadNotification:self untilIndex:_lastReadIndexPath.row];
            _lastSentReadIndexPath = _lastReadIndexPath;
        }
    }
}


#pragma mark - Cells setup

- (void)setupCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath withChatMessage:(id<STChatMessage>)message messageType:(STChatMessageVisualType)messageType
{
	switch (messageType) {
		case kSTChatMessageVisualTypeText:
			[self setupTextCell:(STChatTextTableViewCell *)cell
				   forIndexPath:indexPath
				withChatMessage:(id<STTextChatMessage>)message];
			break;
		case kSTChatMessageVisualTypeImage:
			[self setupImageCell:(STChatImageTableViewCell *)cell
					forIndexPath:indexPath
				 withChatMessage:(id<STImageChatMessage>)message];
			break;
		case kSTChatMessageVisualTypeFileDownload:
			[self setupFileDownloadCell:(STChatFileTableViewCell *)cell
						   forIndexPath:indexPath
						withChatMessage:(id<STFileTransferChatMesage>)message];
			break;
        case kSTChatMessageVisualTypeGeolocation:
            [self setupGeolocationCell:(STChatGeolocationViewCell *)cell
						  forIndexPath:indexPath
					   withChatMessage:(id<STGeolocationChatMessage>)message];
            break;
		case kSTChatMessageVisualTypeServiceMessage:
			[self setupServiceCell:(STChatServiceTableViewCell *)cell
					  forIndexPath:indexPath
				   withChatMessage:(id<STServiceChatMessage>)message];
			break;
			
		default:
			break;
	}
}


- (void)setupFileDownloadCell:(STChatFileTableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath withChatMessage:(id<STFileTransferChatMesage>)chatMessage
{
	[cell setupCellWithMessage:chatMessage];
	[cell setDelegate:self withCellIndex:indexPath.row];
	
	if ([chatMessage isSentByLocalUser]) {
        cell.backgroundTintColor = kSMLocalChatMessageBackgroundColor;
    } else {
        cell.backgroundTintColor = kSMRemoteChatMessageBackgroundColor;
    }
}


- (void)setupGeolocationCell:(STChatGeolocationViewCell *)cell forIndexPath:(NSIndexPath *)indexPath withChatMessage:(id<STGeolocationChatMessage>)chatMessage
{
	[cell setupCellWithMessage:chatMessage];
	[cell setDelegate:self withCellIndex:indexPath.row];
	
	if ([chatMessage isSentByLocalUser]) {
        cell.backgroundTintColor = kSMLocalChatMessageBackgroundColor;
    } else {
        cell.backgroundTintColor = kSMRemoteChatMessageBackgroundColor;
    }
}


- (void)setupImageCell:(STChatImageTableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath withChatMessage:(id<STImageChatMessage>)chatMessage
{
	
}


- (void)setupServiceCell:(STChatServiceTableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath withChatMessage:(id<STServiceChatMessage>)chatMessage
{
	switch ([chatMessage serviceMessageType]) {
		case kSTChatServiceMessageTypeMissedCall:
			cell.textLabel.attributedText = [chatMessage attributedTextForMissedCallFrom:[chatMessage missedCallFrom]];
            cell.detailTextLabel.attributedText = [chatMessage attributedTextForMissedCallDate:[chatMessage missedCallWhen]];
		break;
		case kSTChatServiceMessageTypeReceivedCall:
			cell.textLabel.text = NSLocalizedStringWithDefaultValue(@"label_received-call",
																	nil, [NSBundle mainBundle],
																	@"Received call",
																	@"Received as adjective");
		break;
		case kSTChatServiceMessageTypeUnspecified:
		default:
			NSAssert(NO, @"Service message type must be specified!");
		break;
	}
}


- (void)setupTextCell:(STChatTextTableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath withChatMessage:(id<STTextChatMessage>)chatMessage
{
	[cell setupCellWithMessage:chatMessage];
		
    if ([chatMessage isSentByLocalUser]) {
        cell.backgroundTintColor = kSMLocalChatMessageBackgroundColor;
    } else {
        cell.backgroundTintColor = kSMRemoteChatMessageBackgroundColor;
    }
}


- (void)updateVisibleCells
{
	NSArray *visibleCells = [self.tableView visibleCells];
	for (UITableViewCell *cell in visibleCells) {
		[cell setNeedsLayout];
	}
}


- (void)updateCellAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
	if (cell) {
		id<STChatMessage> message = [self.datasource chatViewController:self chatMessageForIndex:indexPath.row];
		STChatMessageVisualType messageType = [message messageVisualType];
		[self setupCell:cell forIndexPath:indexPath withChatMessage:message messageType:messageType];
		[cell setNeedsDisplay];
	}
}


#pragma mark - Private methods

- (void)sendTextMessageWithText:(NSString *)text
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewController:sendTextMessage:)]) {
        [self.delegate chatViewController:self sendTextMessage:text];
    }
}


- (void)startDownloadFileButtonPressedAtIndex:(NSInteger)index
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewController:startDownloadFileButtonPressedAtIndex:)]) {
		[self.delegate chatViewController:self startDownloadFileButtonPressedAtIndex:index];
	}
}


- (void)pauseDownloadFileButtonPressedAtIndex:(NSInteger)index
{
 	if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewController:pauseDownloadFileButtonPressedAtIndex:)]) {
		[self.delegate chatViewController:self pauseDownloadFileButtonPressedAtIndex:index];
	}
}


- (void)cancelTransferFileButtonPressedAtIndex:(NSInteger)index
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewController:cancelTransferFileButtonPressedAtIndex:)]) {
		[self.delegate chatViewController:self cancelTransferFileButtonPressedAtIndex:index];
	}
}


- (void)openDownloadedFileButtonPressedAtIndex:(NSInteger)index
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewController:openDownloadedFileButtonPressedAtIndex:)]) {
		[self.delegate chatViewController:self openDownloadedFileButtonPressedAtIndex:index];
	}
}


- (void)showLocationButtonPressedAtIndex:(NSInteger)index
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewController:showLocationButtonPressedAtIndex:)]) {
		[self.delegate chatViewController:self showLocationButtonPressedAtIndex:index];
	}
}


- (void)enableUserActivity
{
	_userActivityDisabled = NO;
	self.inputToolBarView.enabled = YES;
}


- (void)disableUserActivity
{
	_userActivityDisabled = YES;
	self.inputToolBarView.enabled = NO;
	[self.inputToolBarView.textView resignFirstResponder];
}


- (void)checkReadMessages
{
	NSIndexPath *lastVisibleIndexPath = [[self.tableView indexPathsForVisibleRows]lastObject];
    
    if(lastVisibleIndexPath.row > _lastReadIndexPath.row){
        self.unreadMessagesNotificationsView.hidden = YES;
        
        _unreadMessages = ([self.tableView numberOfRowsInSection:0] - 1) - lastVisibleIndexPath.row;
        _lastReadIndexPath = lastVisibleIndexPath;
        
        if (_unreadMessages > 0) {
            [self writeUnreadMessagesNotification:_unreadMessages];
        } else {
            
        }
    }
}


- (void)checkMessagesWhenChatWillAppear
{
    _readMessagesNotificationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(readNotificationTimerTicked:) userInfo:nil repeats:YES];
    _lastSentReadIndexPath = _lastReadIndexPath;
    [self setupUnreadMessagesNotification];
    [self checkReadMessages];
}


- (void)checkIfKeyboardShouldBePresented
{
    if (_keyboardShouldBePresented) {
        [self.inputToolBarView.textView becomeFirstResponder];
    }
}


- (BOOL)isChatViewScrolledToTheBottom
{
    CGFloat kGapHeight = 15.0; /*This constant defines the gap from bottom of scroll view
                                that we allow to still scrolling as if the scroll view were
                                at the very bottom*/
    
    NSUInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
    
	if (numberOfRows == 0) {
		return YES; // Since we don't have any rows we are at the bottom
	}

	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:numberOfRows-1 inSection:0];
    
    CGFloat scrollViewHeight = [self.tableView.layer.presentationLayer frame].size.height;
    CGFloat scrollContentSizeHeight = self.tableView.contentSize.height;
    CGFloat scrollOffset = self.tableView.contentOffset.y;
    CGFloat typingNotifHeight = self.footerTypingNotificationsView.frame.size.height;
    CGFloat newCellHeight = [self tableView:self.tableView heightForRowAtIndexPath:indexPath];
    
    CGFloat scrollGap = kGapHeight + newCellHeight + (_typingNotificationIsShown ? typingNotifHeight : 0);
    
    if (scrollOffset + scrollViewHeight >= scrollContentSizeHeight - scrollGap) {
        if (self.isViewLoaded && self.view.window) {
            return YES;
        }
    }
    return NO;
}


- (void)scrollChatViewToTheBottom
{
    NSUInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:numberOfRows-1 inSection:0];
    
    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}


- (void)reloadChatAfterNewChatMessage:(BOOL)localMessage atIndex:(NSIndexPath *)indexPath
{
    if (localMessage) {
        [self scrollChatViewToTheBottom];
    } else if (![self isChatViewScrolledToTheBottom]) {
        _unreadMessages = _unreadMessages +1;
        [self writeUnreadMessagesNotification:_unreadMessages];
    } else {
        [self scrollChatViewToTheBottom];
    }
    
    if (_typingNotificationIsShown && !localMessage) {
        [self hideTypingNotificationWhenNewMessageReceived:YES];
    }
    
    if (self.isViewLoaded && self.view.window) {
        [self willPlayNewMessageSound:!localMessage];
    }
}


- (void)willPlayNewMessageSound:(BOOL)yesNo
{
    if (yesNo) {
        [[AudioManager defaultManager] playSoundForIncomingMessageInChat];
    }
}


- (void)clearChat
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(clearMessagesInChatViewController:)]) {
        [self.delegate clearMessagesInChatViewController:self];
    }
    
    [self.tableView reloadData];
}


- (void)askUserToClearChatMessages
{
    NSString *alertTitle = NSLocalizedStringWithDefaultValue(@"message_title_clear-chat-messages",
                                                             nil, [NSBundle mainBundle],
                                                             @"Clear chat",
                                                             @"Clear(verb) chat");
    NSString *alertMessage = NSLocalizedStringWithDefaultValue(@"message_body_clear-chat-messages",
                                                               nil, [NSBundle mainBundle],
                                                               @"Do you want to remove all messages in this chat?",
                                                               @"Do you want to remove all messages in this chat?");
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:alertTitle
                                                        message:alertMessage
                                                       delegate:self
                                              cancelButtonTitle:kSMLocalStringCancelButton
                                              otherButtonTitles:kSMLocalStringConfirmButton, nil];
    
    alertView.tag = kChatViewControllerClearChatAlertViewTag;
    
    [alertView show];
}


- (void)askUserToStopSharingFileAtIndex:(NSInteger)index
{
    NSString *alertTitle = NSLocalizedStringWithDefaultValue(@"message_title_stop-sharing-file",
                                                             nil, [NSBundle mainBundle],
                                                             @"Stop sharing file",
                                                             @"Stop sharing file");
    NSString *alertMessage = NSLocalizedStringWithDefaultValue(@"message_body_stop-sharing-file",
                                                               nil, [NSBundle mainBundle],
                                                               @"Do you want to stop sharing this file?",
                                                               @"Do you want to stop sharing this file?");
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:alertTitle
                                                        message:alertMessage
                                                       delegate:self
                                              cancelButtonTitle:kSMLocalStringCancelButton
                                              otherButtonTitles:kSMLocalStringConfirmButton, nil];
    
    alertView.tag = kChatViewControllerStopSharingFileAlertViewTag;
    
    _fileToBeRemovedIndex = index;
    
    [alertView show];
}


#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(alertView.tag == kChatViewControllerClearChatAlertViewTag) {
        if (buttonIndex == 1)
        {
            [self clearChat];
        }
    } else if(alertView.tag == kChatViewControllerStopSharingFileAlertViewTag) {
        if (buttonIndex == 1 && _fileToBeRemovedIndex >= 0)
        {
            [self cancelTransferFileButtonPressedAtIndex:_fileToBeRemovedIndex];
        }
        
        _fileToBeRemovedIndex = -1;
    }
}


#pragma mark - Public methods

- (void)addNewChatMessage:(id<STChatMessage>)message
{
	NSUInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:numberOfRows inSection:0];
    
    //Hide the typing notification before the new row insertion
    if (_typingNotificationIsShown && ![message isSentByLocalUser]) {
        self.typingNotificationLabel.hidden = YES;
        self.footerTypingNotificationsView.hidden = YES;
    }
    
    [CATransaction begin];
    [CATransaction setCompletionBlock: ^{
        if (self.isViewLoaded && self.view.window && [[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground) {
            [self.tableView reloadData];
            [self reloadChatAfterNewChatMessage:[message isSentByLocalUser] atIndex:indexPath];
            [self checkReadMessages];
        }
    }];

    [self.tableView beginUpdates];
    [self updateCellAtIndexPath:[NSIndexPath indexPathForRow:numberOfRows - 1 inSection:0]];
	[self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:[message isSentByLocalUser] ? UITableViewRowAnimationRight : UITableViewRowAnimationLeft];
    [self.tableView endUpdates];
    
    [CATransaction commit];
}


- (void)removeChatMessage:(id<STChatMessage>)message atIndex:(NSUInteger)index
{
	if (index < [self.tableView numberOfRowsInSection:0]) {
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
		[self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
	}
}


- (void)updateChatMessageStateAtIndex:(NSUInteger)index
{
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
	[self updateCellAtIndexPath:indexPath];
}


- (void)setupTypingNotificationFromUserNames:(NSArray *)userNames
{
    NSString *tnicon = [NSString fontAwesomeIconStringForEnum:FAPencil];
    UIFont *font=[UIFont fontWithName:kFontAwesomeFamilyName size:14];
    UIFont *font2=[UIFont systemFontOfSize:14.0f];
    
	NSString *typingUsersNames = @"";
	
	NSString *typingFormatStringLocPlural = NSLocalizedStringWithDefaultValue(@"label-arg1_are-typing-ellipsis",
																			  nil, [NSBundle mainBundle],
																			  @"%@ are typing…",
																			  @"Full String is composed like: Username1, username2 are typing… You can change position of %@ in the string but you should keep it");
	NSString *typingFormatStringLocSingular = NSLocalizedStringWithDefaultValue(@"label-arg1_is-typing-ellipsis",
																				nil, [NSBundle mainBundle],
																				@"%@ is typing…",
																				@"Full String is composed like: Username is typing… You can change position of %@ in the string but you should keep it");
	
	NSString *typingLocFormatString = [userNames count] > 1 ? typingFormatStringLocPlural : typingFormatStringLocSingular;
	
	if ([userNames count] > 1) {
		for (NSString *userName in userNames) {
			typingUsersNames = [typingUsersNames stringByAppendingFormat:@"%@, ", userName];
		}
	} else if ([userNames count] == 1) {
		typingUsersNames = [typingUsersNames stringByAppendingFormat:@"%@", [userNames firstObject]];
	} else {
		typingUsersNames = NSLocalizedStringWithDefaultValue(@"label_some-ghost",
															 nil, [NSBundle mainBundle],
															 @"hmm… some ghost",
															 @"This string is used in critical case as a user name when for some reason we couldn't get user name. It shouldn't ever happen in normal working app. hmm… some ghost is typing");
	}
	
	
	
	typingUsersNames = [NSString stringWithFormat:typingLocFormatString, typingUsersNames];
    
    NSString *finalString = [NSString stringWithFormat:@"   %@ %@", tnicon, typingUsersNames];
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:finalString];
    
    [attrString addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, 4)];
    [attrString addAttribute:NSFontAttributeName value:font2 range:NSMakeRange(4, [attrString length]-4)];
    [attrString addAttribute:NSForegroundColorAttributeName value:[UIColor darkGrayColor] range:NSMakeRange(0,[attrString length])];
    
    [self.typingNotificationLabel setAttributedText:attrString];
}


- (void)setTypingNotificationFooterHidden:(BOOL)hidden
{
	self.typingNotificationLabel.hidden = hidden;
	self.footerTypingNotificationsView.hidden = hidden;
	if (!hidden) {
		[self.footerTypingNotificationsView setNeedsDisplay];
	}
}


- (void)showTypingNotificationFromUserNames:(NSArray *)userNames
{
    CGFloat scrollViewHeight = self.tableView.frame.size.height;
    CGFloat scrollContentSizeHeight = self.tableView.contentSize.height;
    CGFloat typingNotifHeight = self.footerTypingNotificationsView.frame.size.height;
    
    if (!_typingNotificationIsShown) {
        self.tableView.contentInset = UIEdgeInsetsMake(self.tableView.contentInset.top, self.tableView.contentInset.left, self.tableView.contentInset.bottom + self.typingNotificationLabel.frame.size.height, self.tableView.contentInset.right);
        
        if ([self isChatViewScrolledToTheBottom] && scrollContentSizeHeight + typingNotifHeight > scrollViewHeight) {
            [self.tableView setContentOffset:CGPointMake(self.tableView.contentOffset.x, self.tableView.contentOffset.y + self.typingNotificationLabel.frame.size.height) animated:YES];
        }
        
        [self setTypingNotificationFooterHidden:NO];
        _typingNotificationIsShown = YES;
        
        double delayInSeconds = 0.3;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self setupTypingNotificationFromUserNames:userNames];
        });
    }
}


- (void)hideTypingNotificationWhenNewMessageReceived:(BOOL)yesNo
{
	[self setTypingNotificationFooterHidden:YES];
    
    CGFloat scrollViewHeight = self.tableView.frame.size.height;
    CGFloat scrollContentSizeHeight = self.tableView.contentSize.height;
    CGFloat typingNotifHeight = self.footerTypingNotificationsView.frame.size.height;
    
    NSUInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:numberOfRows-1 inSection:0];
    
    if (_typingNotificationIsShown) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];
        self.tableView.contentInset = UIEdgeInsetsMake(self.tableView.contentInset.top, self.tableView.contentInset.left, self.tableView.contentInset.bottom - self.typingNotificationLabel.frame.size.height, self.tableView.contentInset.right);
        [UIView commitAnimations];
        
        if (yesNo && [self isChatViewScrolledToTheBottom] && scrollContentSizeHeight + typingNotifHeight > scrollViewHeight) {
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
        
        _typingNotificationIsShown = NO;
    }
}


- (void)showSendingCurrentLocationMessage
{
    self.sendingCurrentLocationView.hidden = NO;
}


- (void)hideSendingCurrentLocationMessage
{
    self.sendingCurrentLocationView.hidden = YES;
}


- (void)setupUnreadMessagesNotification
{
    CGFloat scrollViewHeight = self.tableView.frame.size.height;
    CGFloat scrollContentSizeHeight = self.tableView.contentSize.height;
    
    NSUInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
	NSIndexPath *lastMessageIndexPath = [NSIndexPath indexPathForRow:numberOfRows-1 inSection:0];
    
    _lastReadIndexPath = [NSIndexPath indexPathForRow:[self.delegate indexOfLastActivitySeenByUserInChatViewController:self] inSection:0];
    _unreadMessages = lastMessageIndexPath.row - _lastReadIndexPath.row;
    
    if (![self wasSeen] && numberOfRows > 0 && _lastReadIndexPath.row > 0 && scrollContentSizeHeight > scrollViewHeight) {
        [[self tableView] scrollToRowAtIndexPath:_lastReadIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
    if ( _unreadMessages > 0 && numberOfRows > 0) {
        [self writeUnreadMessagesNotification:_unreadMessages];
    }
}


- (void)writeUnreadMessagesNotification:(NSInteger)numberOfUnreadMessages
{
    NSString *tnicon = [NSString fontAwesomeIconStringForEnum:FAArrowDown];
    UIFont *font=[UIFont fontWithName:kFontAwesomeFamilyName size:14];
    UIFont *font2=[UIFont systemFontOfSize:14.0f];
    
	NSString *unreadMesages = @"";
	
	NSString *formatStringUnreadMessagesPlu = NSLocalizedStringWithDefaultValue(@"label-arg1_unread-messages-plural",
																				nil, [NSBundle mainBundle],
																				@"%d unread messages",
																				@"Full String is composed like: 10 unread messages. You can change position of %d in the string but you should keep it");
	NSString *formatStringUnreadMessagesSing = NSLocalizedStringWithDefaultValue(@"label-arg1_unread-messages-singular",
																				 nil, [NSBundle mainBundle],
																				 @"%d unread message",
																				 @"Full String is composed like: 1 unread messages. You can change position of %d in the string but you should keep it");
	
	
	NSString *formatUnreadMessages = numberOfUnreadMessages > 1 ? formatStringUnreadMessagesPlu : formatStringUnreadMessagesSing;
	
	unreadMesages = [NSString stringWithFormat:formatUnreadMessages, numberOfUnreadMessages];
    
    NSString *finalString = [NSString stringWithFormat:@"%@   %@   %@", tnicon, unreadMesages, tnicon];
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:finalString];
    
    [attrString addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, 1)];
    [attrString addAttribute:NSFontAttributeName value:font2 range:NSMakeRange(4, [attrString length]-8)];
    [attrString addAttribute:NSFontAttributeName value:font range:NSMakeRange([attrString length]-1, 1)];
    [attrString addAttribute:NSForegroundColorAttributeName value:[UIColor darkGrayColor] range:NSMakeRange(0,[attrString length])];
    
    self.unreadMessagesLabel.attributedText = attrString;
    [self.unreadMessagesNotificationsView setHidden:NO];
    [self.unreadMessagesNotificationsView setNeedsDisplay];
    self.unreadMessagesLabel.hidden = NO;
}


- (void)setUserActivityEnabled:(BOOL)yesNo
{
	if (yesNo) {
		[self enableUserActivity];
	} else {
		[self disableUserActivity];
	}
}


- (void)presentFileShareDialog
{
	NSString *shareFileLocButtonTitle = kSMLocalStringShareFileButton;
	NSString *shareLocationLocButtonTitle = kSMLocalStringShareLocationButton;
    
    [self.view endEditing:YES]; // Hide keyboard if it is visible
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        UIAlertController *actionSheetController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *shareFileAction = [UIAlertAction actionWithTitle:shareFileLocButtonTitle
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) { [self presentFileShareOptionsDialog]; } ];
        
        UIAlertAction *shareLocationAction = [UIAlertAction actionWithTitle:shareLocationLocButtonTitle
                                                                      style:UIAlertActionStyleDefault
                                                                    handler:^(UIAlertAction * action) { [self shareUserCurrentLocation]; } ];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:kSMLocalStringCancelButton
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                        [actionSheetController dismissViewControllerAnimated:YES completion:nil];
                                                       }];
        
        [actionSheetController addAction:shareFileAction];
        [actionSheetController addAction:shareLocationAction];
        [actionSheetController addAction:cancel];
        
        UIPopoverPresentationController *popover = actionSheetController.popoverPresentationController;
        if (popover)
        {
            popover.sourceView = self.inputToolBarView.sendPhotoButton;
            popover.sourceRect = self.inputToolBarView.sendPhotoButton.bounds;
            popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        }
        
        [self presentViewController:actionSheetController animated:YES completion:nil];
    } else {
        _actionsActionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                          delegate:self
                                                 cancelButtonTitle:kSMLocalStringCancelButton
                                            destructiveButtonTitle:nil
                                                 otherButtonTitles:shareFileLocButtonTitle, shareLocationLocButtonTitle, nil];
        
        if (self.tabBarController) {
            [_actionsActionSheet showFromTabBar:self.tabBarController.tabBar];
        } else {
            [_actionsActionSheet showInView:self.view];
        }
    }
}


- (void)presentFileShareOptionsDialog
{
    [self.view endEditing:YES]; // Hide keyboard if it is visible
	
    NSString *shareFileFromTitle = kSMLocalStringShareFileMessageTitle;
	NSString *photoLibLocButtonTitle = kSMLocalStringPhotoLibraryLabel;
	NSString *documentsDirLocButtonTitle = kSMLocalStringInAppDocumentDirectory;
    NSString *cancelButtonTitle = kSMLocalStringCancelButton;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        UIAlertController *actionSheetController = [UIAlertController alertControllerWithTitle:shareFileFromTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *photoLibraryAction = [UIAlertAction actionWithTitle:photoLibLocButtonTitle
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * action) {
                                                                       [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
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
            popover.sourceView = self.inputToolBarView.sendPhotoButton;
            popover.sourceRect = self.inputToolBarView.sendPhotoButton.bounds;
            popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        }
        
        [self presentViewController:actionSheetController animated:YES completion:nil];
    } else {
        _sharingFilesOptionsActionSheet = [[UIActionSheet alloc] initWithTitle:shareFileFromTitle
                                                                      delegate:self
                                                             cancelButtonTitle:cancelButtonTitle
                                                        destructiveButtonTitle:nil
                                                             otherButtonTitles:photoLibLocButtonTitle, documentsDirLocButtonTitle, nil];
        
        if (self.tabBarController) {
            [_sharingFilesOptionsActionSheet showFromTabBar:self.tabBarController.tabBar];
        } else {
            [_sharingFilesOptionsActionSheet showInView:self.view];
        }
    }
}


- (void)presentChatInputViewKeyBoard
{
    _keyboardShouldBePresented = YES;
}


- (void)shareUserCurrentLocation
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewControllerSendGeolocation:)]) {
        [self.delegate chatViewControllerSendGeolocation:self];
    }
}


- (void)shareUserSelectedFileWithInfo:(NSDictionary *)info
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewController:wantsToShareMediaWithInfo:)]) {
        [self.delegate chatViewController:self wantsToShareMediaWithInfo:info];
    }
}


- (void)shareUserSelectedFileAtPath:(NSString *)path
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewController:wantsToShareFileAtPath:)]) {
        [self.delegate chatViewController:self wantsToShareFileAtPath:path];
    }
}


#pragma mark - UITableViewDatasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if ([self.datasource respondsToSelector:@selector(numberOfMessagesInChatViewController:)]) {
		return [self.datasource numberOfMessagesInChatViewController:self];
	}
	return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	id<STChatMessage> message = [self.datasource chatViewController:self chatMessageForIndex:indexPath.row];
	STChatMessageVisualType messageType = [message messageVisualType];
	
	UITableViewCell *cell = nil;
	NSString *selectedIdentifier = nil;
	
	switch (messageType) {
		case kSTChatMessageVisualTypeUnspecified:
			NSAssert(NO, @"This should not happen. Every message has to have visual message type!");
		break;
		case kSTChatMessageVisualTypeText:
			selectedIdentifier = textCellIdentifier;
		break;
		case kSTChatMessageVisualTypeImage:
			selectedIdentifier = imageCellIdentifier;
		break;
		case kSTChatMessageVisualTypeFileDownload:
			selectedIdentifier = fileDownloadCellIdentifier;
		break;
        case kSTChatMessageVisualTypeGeolocation:
            selectedIdentifier = geolocationCellIdentifier;
		break;
		case kSTChatMessageVisualTypeServiceMessage:
			selectedIdentifier = serviceCellIdentifier;
		break;
			
		default:
		break;
	}
	
	cell = [tableView dequeueReusableCellWithIdentifier:selectedIdentifier];
	
	// We assume that cell has correct class.
	[self setupCell:cell forIndexPath:indexPath withChatMessage:message messageType:messageType];
	
	return cell;	
}


#pragma mark - UITableView Delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	id<STChatMessage> message = [self.datasource chatViewController:self chatMessageForIndex:indexPath.row];
	STChatMessageVisualType messageType = [message messageVisualType];
	
	CGFloat height = 44.0f;
	
	switch (messageType) {
		
		case kSTChatMessageVisualTypeText:
			height = [STChatTextTableViewCell neededHeightForCellWithTextChatMessage:(id<STTextChatMessage>)message
																		  topMessage:[message isStartOfGroup]
																	   bottomMessage:[message isEndOfGroup]
																   restrictedToWidth:self.view.frame.size.width
													  withDeliveryStatusNotification:YES];
					
			break;
		case kSTChatMessageVisualTypeImage:
			break;
		case kSTChatMessageVisualTypeFileDownload:
			height = [STChatFileTableViewCell neededHeightForCellWithFileChatMessage:(id<STFileTransferChatMesage>)message
																		  topMessage:[message isStartOfGroup]
																	   bottomMessage:[message isEndOfGroup]
																   restrictedToWidth:self.view.frame.size.width];
			break;
        case kSTChatMessageVisualTypeGeolocation:
            height = [STChatGeolocationViewCell neededHeightForCellWithGeolocationChatMessage:(id<STGeolocationChatMessage>)message
                                                                                   topMessage:[message isStartOfGroup]
                                                                                bottomMessage:[message isEndOfGroup]
                                                                            restrictedToWidth:self.view.frame.size.width];
            break;
		case kSTChatMessageVisualTypeServiceMessage:
			height = [STChatServiceTableViewCell height];
			break;
			
		case kSTChatMessageVisualTypeUnspecified:
		default:
			NSAssert(NO, @"This should not happen. Every message has to have visual message type!");
		break;
	}
	
	return height;
}


- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}


#pragma mark - STChatInputView Delegate

- (void)chatInputView:(STChatInputView *)inputView sendTextMessageWithText:(NSString *)text
{
    NSString *textToSend = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([textToSend length] > 0) {
        inputView.textView.text = @"";
        [self sendTextMessageWithText:textToSend];
    }
}


- (void)chatInputView:(STChatInputView *)inputView willResizeWithHeight:(CGFloat)height
{
    CGRect newFrame = self.tableView.frame;
    newFrame.size.height -= height;
    self.tableView.frame = newFrame;
    
    NSUInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
	if (numberOfRows > 0) {
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:numberOfRows-1 inSection:0];
		if ([self isChatViewScrolledToTheBottom] && numberOfRows>0) {
			[self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
		}
	}
    
    CGRect newNotificationFrame = self.footerTypingNotificationsView.frame;
    newNotificationFrame.origin.y -= height;
    
    self.footerTypingNotificationsView.frame = newNotificationFrame;
    self.unreadMessagesNotificationsView.frame = newNotificationFrame;
}


- (void)chatInputView:(STChatInputView *)inputView userIsTyping:(BOOL)yesOrNo
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewController:sendTypingNotification:)]) {
        [self.delegate chatViewController:self sendTypingNotification:(yesOrNo)?@"start":@"stop"];
    }
}


- (void)chatInputViewPhotoButtonWasPressed:(STChatInputView *)inputView
{
	[self actionsButtonPressed:nil];
}


#pragma mark - STChatFileTableViewCellDelegate implementation

- (void)fileTableViewCell:(STChatFileTableViewCell *)cell actionButtonWasPressedWithAction:(STChatFileTableViewCellActionType)actionType atIndex:(NSInteger)index
{
	if (index > -1) {
		switch (actionType) {
			case kSTChatFileTableViewCellActionTypeCancelTransfer:
				[self askUserToStopSharingFileAtIndex:index];
			break;
			
			case kSTChatFileTableViewCellActionTypeStartDownload:
				[self startDownloadFileButtonPressedAtIndex:index];
			break;
			
			case kSTChatFileTableViewCellActionTypePauseDownload:
				[self pauseDownloadFileButtonPressedAtIndex:index];
			break;
			
			case kSTChatFileTableViewCellActionTypeOpenDownloadedFile:
				[self openDownloadedFileButtonPressedAtIndex:index];
			break;
			default:
				break;
		}
	}
}


#pragma mark - STChatGeolocationTableViewCellDelegate implementation

- (void)geolocationTableViewCell:(STChatGeolocationViewCell *)cell showLocationButtonWasPressedAtIndex:(NSInteger)index
{
    [self showLocationButtonPressedAtIndex:index];
}


#pragma mark - ActionSheet Action

- (void)actionsButtonPressed:(id)sender
{
    [self presentFileShareDialog];
}


#pragma mark - UIActionSheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (actionSheet == _actionsActionSheet) {
		
		if (buttonIndex == 0) {
            [self presentFileShareOptionsDialog];
		} else if (buttonIndex == 1) {
            [self shareUserCurrentLocation];
        }
		
		_actionsActionSheet = nil;
		
    } else if (actionSheet == _sharingFilesOptionsActionSheet) {
        if (buttonIndex == 0) {
            [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        } else if (buttonIndex == 1){
            [self presentFileBrowserViewController];
        }
        _sharingFilesOptionsActionSheet = nil;
        
    } else if (actionSheet == _confirmShareFileActionSheet) {
		if (buttonIndex == 0) { // index == 0 for "Set" button
			[self hideImagePicker];
		} else { // index == 1 for "Cancel" button
			[self hideImagePicker];
		}
		_confirmShareFileActionSheet = nil;
        
	} else if (NO) {
		// For future use
		
		if (0 == buttonIndex) { // index == 0 for "Take Photo" button
			[self showImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera];
		} else if (1 == buttonIndex) { // index == 1 for "Choose Existing" button
			[self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
		} // else index == 2 for "Cancel" button
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


- (void)showImagePickerWithSourceType:(UIImagePickerControllerSourceType)sourceType
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
				[_popover presentPopoverFromRect:[self.inputToolBarView convertRect:self.inputToolBarView.sendPhotoButton.frame toView:self.view]
										  inView:self.view
						permittedArrowDirections:UIPopoverArrowDirectionDown
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
	[self showImagePickerWithSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
}


#pragma mark - UIImagePickerViewControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
	[self hideImagePicker];
}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	[self hideImagePicker];
    [self shareUserSelectedFileWithInfo:info];
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
    [self shareUserSelectedFileAtPath:path];
}


- (BOOL)fileBrowser:(STFileBrowserViewController *)fileBrowser shouldPresentDocumentsControllerForFileAtPath:(NSString *)path
{
    return NO;
}


@end
