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

#import "CallingViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import "AudioManager.h"
#import "UsersManager.h"
#import "BuddyCollectionViewCell.h"
#import "BuddyListViewController.h"
#import "ChannelingManager.h"
#import "CallWidget.h"
#import "MKNumberBadgeView.h"
#import "NSString+FontAwesome.h"
#import "OutlinedLabel.h"
#import "PopUpListView.h"
#import "PopUpView.h"
#import "RoundedRectButton.h"
#import "SMLocalizedStrings.h"
#import "SpreedMeRoundedButton.h"
#import "SoftAlert.h"
#import "STProgressView.h"
#import "UIDevice+Hardware.h"
#import "UIFont+FontAwesome.h"
#import "UserInterfaceManager.h"
#import "UsersActivityController.h"


typedef enum CallingViewState
{
	kCallingViewStateStandBy = 0,
	kCallingViewStatePendingOutgoingCall,
    kCallingViewStatePendingOutgoingVideoCall,
	kCallingViewStatePendingIncomingCall,
	kCallingViewStateEstablishingFirstConnection, // can be incoming or outgoing
	kCallingViewStateInCall,
	kCallingViewStateCallIsFinished,
	kCallingViewStateRemoteUserRejectedCall,
	kCallingViewStateNoAnswerFromRemoteUser,
	kCallingViewStateConnectionLost,
}
CallingViewState;


@interface CallingViewController () <UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource,
									BuddyListViewControllerDelegate, PopUpListViewDelegate, UserUpdatesProtocol, UserRecentActivityControllerUpdatesListener>
{
    MPVolumeView *_systemVolumeSlider;
	
	BuddyListViewController *_currentBuddyListViewController;
    BuddyListViewController *_currentScreensharingListViewController;
    
    NSString *_currentScreenSharerSessionId;
    
    UIView  *_soundControlContainerView;
    PopUpView *_soundControlPopupView;
    PopUpView *_videoOptionsPopupView;
    PopUpListView *_moreOptionsPopupView;
	
	UIPopoverController *_addBuddyPopover;
    UIPopoverController *_selectScreensharingPopover;
    
    UsersActivityController *_userActivityController;
    NSMutableDictionary *_unreadMessagesDict; // key - userSessionId : value - NSNumber quantity of unread messages
    NSInteger _uncheckedScreenSharers;
    
    MKNumberBadgeView *_badgeNumberView;
    
	BOOL _shouldShowVideo;
	NSString *_devicePlatform;
	
	NSTimer *_buttonContainerTimer;
	
	NSTimer *_callTimeTimer;
	NSTimeInterval _callTime;
	BOOL _callHasStarted;
	
	BOOL _soundMuted;
	
	BOOL _remoteScreenSharingStarted;
}

@property (nonatomic, strong) IBOutlet UICollectionView *collectionView;
@property (nonatomic, strong) IBOutlet UICollectionViewFlowLayout *flowLayout;

@property (nonatomic, strong) IBOutlet OutlinedLabel *timeLabel;

@property (nonatomic, strong) IBOutlet UIView *buttonContainer;
@property (nonatomic, strong) IBOutlet UIView *airplayView;
@property (nonatomic, strong) IBOutlet RoundedRectButton *hangUpButton;
@property (nonatomic, strong) IBOutlet RoundedRectButton *videoOptionsButton;
@property (nonatomic, strong) IBOutlet RoundedRectButton *muteButton;
@property (nonatomic, strong) IBOutlet RoundedRectButton *moreOptionsButton;

@property (nonatomic, strong) IBOutlet UIView *callAcceptionButtonContainer;
@property (nonatomic, strong) IBOutlet SpreedMeRoundedButton *pickUpButton;
@property (nonatomic, strong) IBOutlet SpreedMeRoundedButton *pickUpVideoButton;
@property (nonatomic, strong) IBOutlet SpreedMeRoundedButton *rejectCallButton;
@property (nonatomic, strong) IBOutlet SpreedMeRoundedButton *cancelOutgoingCallButton;

@property (nonatomic, strong) UIView *startingScreenSharingNotificationView;

- (IBAction)hangUpButtonPressed:(id)sender;
- (IBAction)rejectIncomingCallButtonPressed:(id)sender;
- (IBAction)cancelOutgoingCallButtonPressed:(id)sender;
- (IBAction)pickUpButtonPressed:(id)sender;
- (IBAction)pickUpVideoButtonPressed:(id)sender;

- (IBAction)muteButtonPressed:(id)sender;

- (IBAction)moreOptionsButtonPressed:(id)sender;
- (IBAction)videoOptionsButtonPressed:(id)sender;


@property (nonatomic, strong) NSMutableArray *buddiesOnCall; // Override readonly for internal use

@property (nonatomic, assign) CallingViewState state;

@property (nonatomic, strong) NSString *pendingIncomingCallUserSessionId;

@property (nonatomic, strong) UIView *localVideoRenderView;
@property (nonatomic, assign) CGFloat localVideoRenderViewAspectRatio;

@property (nonatomic, strong) UIWindow *secondaryWindow;
@property (nonatomic, strong) UIView *screenSharingContainerView;
@property (nonatomic, strong) UIScrollView *screenSharingScrollView;
@property (nonatomic, strong) UIView *screenSharingRenderView;
@property (nonatomic, assign) CGFloat screenSharingVideoRendererAspectRatio;

@property (nonatomic, strong) UIView *mutedVideoInfoView;

@end


#pragma mark - 


@implementation CallingViewController


#pragma mark - Object Lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
		_buddiesOnCall = [[NSMutableArray alloc] init];
		_shouldShowVideo = YES;
        
        UIColor *background = [[UIColor alloc] initWithPatternImage:[UIImage imageNamed:@"bg-tiles.png"]];
        self.view.backgroundColor = background;
        self.collectionView.backgroundColor = background;
        
        _unreadMessagesDict = [[NSMutableDictionary alloc] init];
        _uncheckedScreenSharers = 0;
        
        _userActivityController = [UsersActivityController sharedInstance];
        [_userActivityController subscribeForUpdates:self];

		[[UsersManager defaultManager] subscribeForUpdates:self];
	}
	return self;
}


- (void)dealloc
{
    [_userActivityController unsubscribeForUpdates:self];
	[[UsersManager defaultManager] unsubscribeForUpdates:self];
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
	
    [self.view setBackgroundColor:[UIColor blackColor]];
		
	[self setupUIWithCallingState:self.state];
	
	[self.collectionView registerNib:[UINib nibWithNibName:@"BuddyCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"BuddyCollectionViewCell"];
	
	self.buttonContainer.hidden = YES;
    
    self.collectionView.alpha = 0.0f;
    
    [self.muteButton setImage:[UIImage imageNamed:@"Microphone_active"] forState:UIControlStateNormal];
	[self.muteButton setImage:[UIImage imageNamed:@"Microphone_disabled"] forState:UIControlStateSelected];
    [self.muteButton setCornerRadius:22.0f];
    [self.muteButton setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
    [self.muteButton setBackgroundColor:kSMRedButtonColor forState:UIControlStateSelected];
    
	[self.videoOptionsButton setImage:[UIImage imageNamed:@"Webcam_active"] forState:UIControlStateNormal];
	[self.videoOptionsButton setImage:[UIImage imageNamed:@"Webcam_disabled"] forState:UIControlStateSelected];
    [self.videoOptionsButton setCornerRadius:22.0f];
    [self.videoOptionsButton setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
    [self.videoOptionsButton setBackgroundColor:kSMRedButtonColor forState:UIControlStateSelected];
    
    [self.pickUpButton configureButtonWithButtonType:kSpreedMeButtonTypeAcceptNoVideo];
    [self.pickUpVideoButton configureButtonWithButtonType:kSpreedMeButtonTypeAcceptWithVideo];
	[self.rejectCallButton configureButtonWithButtonType:kSpreedMeButtonTypeRejectCall];
	[self.cancelOutgoingCallButton configureButtonWithButtonType:kSpreedMeButtonTypeCancelOutgoingCall];
    
    [self.hangUpButton setCornerRadius:22.0f];
    [self.hangUpButton setBackgroundColor:kSMRedButtonColor forState:UIControlStateNormal];
    
    [self.moreOptionsButton setCornerRadius:22.0f];
    [self.moreOptionsButton setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
    
    CGRect airplayButtonRect = CGRectMake(0, 0, self.airplayView.frame.size.width, self.airplayView.frame.size.height);
    MPVolumeView *volumeView = [ [MPVolumeView alloc] initWithFrame:airplayButtonRect];
    [volumeView setShowsVolumeSlider:NO];
    volumeView.transform = CGAffineTransformMakeScale(1.2, 1.2);
    [self.airplayView addSubview:volumeView];
	
	UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(checkHideShowButtonContainer:)];
	
	[self.startingScreenSharingNotificationView removeFromSuperview];
	self.startingScreenSharingNotificationView = [[STProgressView alloc] initWithWidth:240.0f
																			   message:NSLocalizedStringWithDefaultValue(@"label_loading-screensharing",
																														 nil, [NSBundle mainBundle],
																														 @"Loading screensharing",
																														 @"Text for activity indicator")
																				  font:nil
																	  cancelButtonText:nil
																			  userInfo:nil];
	self.startingScreenSharingNotificationView.frame = CGRectMake(40.0f, 92.0f,
																  self.startingScreenSharingNotificationView.frame.size.width,
																  self.startingScreenSharingNotificationView.frame.size.height);
    
    self.startingScreenSharingNotificationView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                                                    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    
	[self.view addSubview:self.startingScreenSharingNotificationView];
	
    self.startingScreenSharingNotificationView.layer.cornerRadius = 5.0;
    self.startingScreenSharingNotificationView.backgroundColor = [[UIColor alloc] initWithRed:0.0 green:0.0 blue:0.0 alpha:0.3];
    self.startingScreenSharingNotificationView.hidden = YES;
	
	[self.collectionView addGestureRecognizer:tapGesture];

	self.timeLabel.outlineColor = [UIColor darkGrayColor];
	
	self.mutedVideoInfoView = [[UIView alloc] initWithFrame:self.view.frame];
	self.mutedVideoInfoView.autoresizesSubviews = YES;
	self.mutedVideoInfoView.backgroundColor = [UIColor blackColor];
	self.mutedVideoInfoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	UILabel *mutedVideoInfoLabel = [[UILabel alloc] initWithFrame:self.mutedVideoInfoView.bounds];
	mutedVideoInfoLabel.textAlignment = NSTextAlignmentCenter;
	mutedVideoInfoLabel.numberOfLines = 0;
	mutedVideoInfoLabel.backgroundColor = [UIColor clearColor];
	mutedVideoInfoLabel.textColor = [UIColor lightGrayColor];
	mutedVideoInfoLabel.font = [UIFont systemFontOfSize:17.0f];
	mutedVideoInfoLabel.text = NSLocalizedStringWithDefaultValue(@"label_video-is-turned-off",
																 nil, [NSBundle mainBundle],
																 @"Video is turned off",
																 @"User has 'muted' his video and doesn't send it. Probably it can be 'muted' by the app in some cases.");
	mutedVideoInfoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.mutedVideoInfoView addSubview:mutedVideoInfoLabel];
}


- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
    [self updateVideoVisualState];
    
    // We are hidding the collection view until viewDidAppear because on iOS8 we don't get
    // correct view frames until these views appear. Until then, we get sizes setted in xib files.
    // As xib files have been implemented for iPhones and not iPads, we experimented incorrect cell
    // size setup due to sizes of CollectionView whenever CallingViewController was presented.
    // We decided to make this workaround to fix this issue.
    
    [UIView animateWithDuration:0.3 animations:^{
        self.collectionView.alpha = 1.0f;
    }];
}


- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}


#pragma mark - Device orientation

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self hideAllOptionsOfButtonContainer];
	[self updateVideoVisualState];
    
    if (_badgeNumberView) {
        [self updateMoreOptionsButtonBadgeNumbers];
    }
}


#pragma mark - User management

- (BuddyVisual *)buddyVisualForBuddySessionId:(NSString *)userSessionId
{
	BuddyVisual *resultBuddy = nil;
	for (BuddyVisual *buddyVisual in self.buddiesOnCall) {
		if ([buddyVisual.buddy.sessionId isEqualToString:userSessionId]) {
			resultBuddy = buddyVisual;
		}
	}
	return resultBuddy;
}


- (void)addToCallUserSessionId:(NSString *)userSessionId withVisualState:(UserCallVisualState)visualState
{
	BuddyVisual *buddyVisual = [self buddyVisualForBuddySessionId:userSessionId];
	
	if (!buddyVisual) {
		buddyVisual = [[BuddyVisual alloc] init];
		User *buddy = [[UsersManager defaultManager] userForSessionId:userSessionId];
		if (buddy) {
			buddyVisual.buddy = buddy;
			[_buddiesOnCall addObject:buddyVisual];
		}
	}
	
	buddyVisual.visualState = visualState;
	
	[self updateUIForBuddyVisual:buddyVisual];
	
	[self.collectionView reloadData];
	
	[self updateVideoVisualState];
}


- (void)setVisualState:(UserCallVisualState)visualState forUserSessionId:(NSString *)userSessionId
{
	BuddyVisual *buddyVisual = [self buddyVisualForBuddySessionId:userSessionId];
	if (buddyVisual) {
		buddyVisual.visualState = visualState;
		[self updateUIForBuddyVisual:buddyVisual];
	}
}


- (void)removeFromCallUserSessionId:(NSString *)userSessionId
{
	BuddyVisual *buddyVisual = [self buddyVisualForBuddySessionId:userSessionId];
	[self.buddiesOnCall removeObject:buddyVisual];
	
	[self.collectionView reloadData];
	
	[self updateVideoVisualState];
}


#pragma mark - Appearance

- (void)updateUIForBuddyVisual:(BuddyVisual *)buddyVisual
{
	NSArray *visibleCells = [self.collectionView visibleCells];
	for (BuddyCollectionViewCell *cell in visibleCells) {
		if ([cell.buddyVisual isEqual:buddyVisual]) {
			
			[cell updateUI];
			break;
		}
	}
}


- (void)setDisconnectedVisualStateForAllVisibleCells
{
    NSArray *visibleCells = [self.collectionView visibleCells];
    for (BuddyCollectionViewCell *cell in visibleCells) {
        cell.buddyVisual.visualState = kUCVSDisconnected;
        [cell updateUI];
    }
    
    [self.collectionView reloadData];
}


- (void)setupUIWithCallingState:(CallingViewState)state
{
	self.state = state;
	
	if (![self isViewLoaded]) {
		return;
	}
	
	switch (state) {
			
		case kCallingViewStateStandBy:
			[self setUIForStandBy];
			[[AudioManager defaultManager] stopPlaying];
		break;
			
		case kCallingViewStatePendingIncomingCall:
			[self setUIForIncomingCall];
			[[AudioManager defaultManager] playSoundForIncomingCall];
		break;
			
		case kCallingViewStatePendingOutgoingCall:
			[self setUIForOutgoingCall];
			[[AudioManager defaultManager] playSoundForOutgoingCallWithVideo:NO];
		break;
            
        case kCallingViewStatePendingOutgoingVideoCall:
            [self setUIForOutgoingCall];
            [[AudioManager defaultManager] playSoundForOutgoingCallWithVideo:YES];
        break;
			
		case kCallingViewStateEstablishingFirstConnection:
			[self setUIForEstablishingFirstConnection];
		break;
			
		case kCallingViewStateInCall:
			[self setUIForInCall];
			[[AudioManager defaultManager] stopPlaying];
		break;
					
		case kCallingViewStateCallIsFinished:
			[self setUIForCallIsFinished];
			[[AudioManager defaultManager] playSoundOnCallIsFinished];
		break;
			
		case kCallingViewStateRemoteUserRejectedCall:
			[self setUIForRemoteUserRejectedCall];
			[[AudioManager defaultManager] playSoundForRemoteUserRejected];
		break;
			
		case kCallingViewStateNoAnswerFromRemoteUser:
			[self setUIForNoAnswerFromRemoteUser];
			[[AudioManager defaultManager] stopPlaying];
		break;
			
		case kCallingViewStateConnectionLost:
			[self setUIForConnectionLost];
//			[[AudioManager defaultManager] stopPlaying];
		break;
			
		default:
		break;
	}
}

- (void)showStartScreenSharingNotification
{
    [self.startingScreenSharingNotificationView setHidden:NO];
    
    [self.view bringSubviewToFront:self.startingScreenSharingNotificationView];
}


- (void)hideStartScreenSharingNotification
{
    [self.startingScreenSharingNotificationView setHidden:YES];
}


- (void)setUIForStandBy
{
	[self hideCallAcceptionContainer];
	[self hideButtonContainerAnimated:NO];
}


- (void)setUIForIncomingCall
{
	[self showCallAcceptionContainerForIncomingCall:YES];
	[self hideButtonContainerAnimated:NO];
}


- (void)setUIForOutgoingCall
{
	[self showCallAcceptionContainerForIncomingCall:NO];
	[self hideButtonContainerAnimated:NO];
}


- (void)setUIForEstablishingFirstConnection
{
	[self hideCallAcceptionContainer];
	[self hideButtonContainerAnimated:NO];
}


- (void)setUIForInCall
{
	[self hideCallAcceptionContainer];
	[self showButtonContainerAnimated:YES];
	[self invalidateButtonContainerHideTimer];
	_buttonContainerTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(hideButtonContainer:) userInfo:nil repeats:NO];
}


- (void)setUIForCallIsFinished
{
	[self hideCallAcceptionContainer];
	[self hideButtonContainerAnimated:YES];
}


- (void)setUIForRemoteUserRejectedCall
{
	[self hideCallAcceptionContainer];
	[self hideButtonContainerAnimated:YES];
}


- (void)setUIForNoAnswerFromRemoteUser
{
	[self hideCallAcceptionContainer];
	[self hideButtonContainerAnimated:YES];
}


- (void)setUIForConnectionLost
{
	[self hideCallAcceptionContainer];
	[self showButtonContainerAnimated:YES];
}


- (void)updateVideoVisualState
{
    if (!self.view.window) {
        return;
    }
    
	int buddiesOnCallCount = (int)[_buddiesOnCall count]; // we assume that we won't have more than INT_MAX participants ever
		
	self.flowLayout.minimumInteritemSpacing = 5.0f;
	self.flowLayout.minimumLineSpacing = 5.0f;
    self.flowLayout.sectionInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f); // as decided with Vanessa on 5/11/14, we removed insets from calling collection views.
	
	CGSize cellSize = [self cellSizeForParticipantsCount:buddiesOnCallCount
									  collectionViewSize:self.collectionView.frame.size
										interitemSpacing:self.flowLayout.minimumInteritemSpacing
											 lineSpacing:self.flowLayout.minimumLineSpacing
											sectionInset:self.flowLayout.sectionInset];
	
	self.flowLayout.itemSize = cellSize;
	
	[self.collectionView performBatchUpdates:^{
		[self.collectionView setCollectionViewLayout:self.flowLayout animated:NO];
	} completion:^(BOOL finished) {
		NSArray *visibleCells = self.collectionView.visibleCells;
		for (BuddyCollectionViewCell *cell in visibleCells) {
			[cell updateUI];
		}
	}];
	
	if (self.localVideoRenderView) {
		
		CGRect visibleViewRect = self.view.bounds;
		if (!CGRectContainsRect(visibleViewRect, self.localVideoRenderView.frame)) {
			self.localVideoRenderView.frame = CGRectMake(self.collectionView.frame.size.width - self.localVideoRenderView.frame.size.width,
														 self.collectionView.frame.size.height - self.localVideoRenderView.frame.size.height - self.buttonContainer.frame.size.height,
														 self.localVideoRenderView.frame.size.width, self.localVideoRenderView.frame.size.height);
		}
	}
}


- (BOOL)shouldShowVideoForParticipantsCount:(int)participantsCount
{
	BOOL shouldShowVideo = NO;
	
	// If we have more than 4 participants do not show video regardles of device
	if (participantsCount < 0) {
		return shouldShowVideo;
	}
	
	int maxNumberOfVideoConnections = [[PeerConnectionController sharedInstance] calculateMaxNumberOfVideoConnections];
	
	shouldShowVideo = participantsCount <= maxNumberOfVideoConnections;
	
	return shouldShowVideo;
}


- (CGSize)cellSizeForParticipantsCount:(int)participantsCount collectionViewSize:(CGSize)viewSize interitemSpacing:(CGFloat)interitemSpacing lineSpacing:(CGFloat)lineSpacing sectionInset:(UIEdgeInsets)sectionInset
{
	CGSize cellSize = CGSizeZero;
	if (participantsCount <= 0) {
		return cellSize;
	}
	
	int cellsInRow = 2;
	int cellsInColumn = 3;
	
	switch (participantsCount) {
		case 1:
			cellsInRow = 1;
			cellsInColumn = 1;
		break;
		
		case 2:
			if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
				cellsInRow = 2;
				cellsInColumn = 1;
			} else {
				cellsInRow = 1;
				cellsInColumn = 2;
			}
		break;
			
		case 3:
			if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
				if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
					cellsInRow = 2;
					cellsInColumn = 2;
				} else {
					cellsInRow = 2;
					cellsInColumn = 2;
				}
			} else if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
				if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
					cellsInRow = 2;
					cellsInColumn = 2;
				} else {
					cellsInRow = 1;
					cellsInColumn = 3;
				}
			} else {
				// for future use
			}
			
			
		break;
		case 4:
			if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
				if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
					cellsInRow = 2;
					cellsInColumn = 2;
				} else {
					cellsInRow = 2;
					cellsInColumn = 2;
				}
			} else if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
				if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
					cellsInRow = 2;
					cellsInColumn = 2;
				} else {
					cellsInRow = 1;
					cellsInColumn = 4;
				}
			} else {
				// for future use
			}
		break;
			
		default:
		{
			cellsInRow = 2;
			cellsInColumn = 3;
		}
		break;
						
	}
	
	cellSize = CGSizeMake((viewSize.width - sectionInset.left - sectionInset.right - interitemSpacing * (cellsInRow - 1)) / (CGFloat)cellsInRow,
						  (viewSize.height - sectionInset.bottom - sectionInset.top - lineSpacing * (cellsInColumn - 1)) / (CGFloat)cellsInColumn);


	cellSize.width = floorf(cellSize.width);
	cellSize.height = floorf(cellSize.height);
	
	return cellSize;
}


#pragma mark -

- (void)checkHideShowButtonContainer:(UITapGestureRecognizer *)tapGesture
{
	if (self.buttonContainer.hidden && self.callAcceptionButtonContainer.hidden) {
		[self showButtonContainerAnimated:YES];
		
		[self invalidateButtonContainerHideTimer];
		_buttonContainerTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(hideButtonContainer:) userInfo:nil repeats:NO];
	} else {
		
		[self hideButtonContainerAnimated:YES];
		
		[self invalidateButtonContainerHideTimer];
	}
}


#pragma mark -

- (void)showCallAcceptionContainerForIncomingCall:(BOOL)isIncomingCall
{
	self.pickUpButton.hidden = !isIncomingCall;
	self.pickUpVideoButton.hidden = !isIncomingCall;
	self.cancelOutgoingCallButton.hidden = isIncomingCall;
	self.rejectCallButton.hidden = !isIncomingCall;
	
	self.callAcceptionButtonContainer.hidden = NO;
}


- (void)hideCallAcceptionContainer
{
	self.callAcceptionButtonContainer.hidden = YES;
}


#pragma mark -

- (void)invalidateButtonContainerHideTimer
{
	[_buttonContainerTimer invalidate];
	_buttonContainerTimer = nil;
}


- (void)setBadgeNumberAtMoreOptionsButton:(NSUInteger)number
{
    if (_badgeNumberView) {
        [self removeBadgeNumberAtMoreOptionsButton];
    }
    
    if (_moreOptionsPopupView) {
        // if the more options menu is already open, we do not set the badge number
        return;
    }
    
    _badgeNumberView = [[MKNumberBadgeView alloc]initWithFrame:CGRectMake(self.moreOptionsButton.frame.origin.x + (self.moreOptionsButton.frame.size.width - 25),
                                                                          self.moreOptionsButton.frame.origin.y - 12,
                                                                          44, 40)];
    _badgeNumberView.fillColor = kSpreedMeBlueColor;
    _badgeNumberView.hideWhenZero = NO;
    _badgeNumberView.shine = NO;
    _badgeNumberView.value = number;
    _badgeNumberView.userInteractionEnabled = NO;
    _badgeNumberView.exclusiveTouch = NO;
    [self.buttonContainer addSubview:_badgeNumberView];
}


- (void)removeBadgeNumberAtMoreOptionsButton
{
    [_badgeNumberView removeFromSuperview];
    _badgeNumberView = nil;
}


- (void)showButtonContainerAnimated:(BOOL)animated
{
	// Check if call has video and set video button accordingly
	self.videoOptionsButton.enabled = [PeerConnectionController sharedInstance].hasVideo;
	
	if (!self.buttonContainer.hidden) {
		return;
	}
	
	if (animated) {
		
		if (_callTime > 0.01) {
			self.timeLabel.alpha = 0.0f;
			self.timeLabel.hidden = NO;
		}
		
		
		self.buttonContainer.alpha = 0.0f;
		self.buttonContainer.hidden = NO;
        self.airplayView.alpha = 0.0f;
        self.airplayView.hidden = NO;
		[UIView animateWithDuration:0.3 animations:^{
			self.buttonContainer.alpha = 1.0f;
            self.airplayView.alpha = 1.0f;
			self.timeLabel.alpha = 1.0f;
		} completion:^(BOOL finished) {}];
	} else {
		
		if (_callTime > 0.01) {
			self.timeLabel.hidden = YES;
		}
		
		self.buttonContainer.alpha = 1.0f;
		self.buttonContainer.hidden = NO;
        self.airplayView.alpha = 1.0f;
        self.airplayView.hidden = NO;
	}
}


- (void)hideButtonContainerAnimated:(BOOL)animated
{
	if (self.buttonContainer.hidden) {
		return;
	}
	
	if (animated) {
		[UIView animateWithDuration:0.3 animations:^{
			self.buttonContainer.alpha = 0.0f;
            self.airplayView.alpha = 0.0f;
			self.timeLabel.alpha = 0.0f;
		} completion:^(BOOL finished) {
			self.buttonContainer.hidden = YES;
            self.airplayView.hidden = YES;
			self.timeLabel.hidden = YES;
		}];
	} else {
		self.buttonContainer.alpha = 0.0f;
		self.buttonContainer.hidden = YES;
        self.airplayView.alpha = 0.0f;
        self.airplayView.hidden = YES;
		self.timeLabel.alpha = 0.0f;
		self.timeLabel.hidden = YES;
	}
    
    [self hideAllOptionsOfButtonContainer];
}


- (void)hideButtonContainer:(NSTimer *)timer
{
	[self hideButtonContainerAnimated:YES];
}


- (void)hideAllOptionsOfButtonContainer
{
    if (_soundControlPopupView) {
        [_soundControlPopupView removeFromSuperview];
        _soundControlPopupView = nil;
    }
    if (_videoOptionsPopupView) {
        [_videoOptionsPopupView removeFromSuperview];
        _videoOptionsPopupView = nil;
    }
    if (_moreOptionsPopupView) {
        [_moreOptionsPopupView removeFromSuperview];
        _moreOptionsPopupView = nil;
    }
}


#pragma mark -

- (void)startCountingCallTime
{
	self.timeLabel.text = @"00:00";
	self.timeLabel.hidden = NO;
	_callTime = 0.0;
	[_callTimeTimer invalidate];
	_callTimeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(incrementCallTime:) userInfo:nil repeats:YES];
}


- (void)stopCountingCallTime
{
	[_callTimeTimer invalidate];
	_callTimeTimer = nil;
}


- (void)incrementCallTime:(NSTimer *)timer
{
	_callTime += timer.timeInterval; //this will work only if timer is 'repeating'
	
	int timeIntervalSeconds = (int)_callTime;
	
	const int oneHourInSeconds = 3600;
	const int oneMinuteInSeconds = 60;
	
	int hours = timeIntervalSeconds / oneHourInSeconds;
	
	int minutes = (timeIntervalSeconds - hours * oneHourInSeconds) / oneMinuteInSeconds;
	
	int seconds = timeIntervalSeconds - hours * oneHourInSeconds - minutes * oneMinuteInSeconds;
	
#warning TODO: maybe localize
	NSString *time = [NSString stringWithFormat:@"%d:%.2d:%.2d", hours, minutes, seconds];
	if (hours == 0) {
		time = [NSString stringWithFormat:@"%.2d:%.2d", minutes, seconds];
	}
	
	self.timeLabel.text = time;
}


#pragma mark - Actions

- (void)pickUpCallWithVideo:(BOOL)withVideo
{
	if (self.pendingIncomingCallUserSessionId) {
		[self invalidateButtonContainerHideTimer];
		if (self.userActionsDelegate && [self.userActionsDelegate respondsToSelector:@selector(callingViewController:userAcceptedIncomingCall:withVideo:)]) {
			User *pendingCallBuddy = [[UsersManager defaultManager] userForSessionId:self.pendingIncomingCallUserSessionId];
			if (pendingCallBuddy) {
				[self.userActionsDelegate callingViewController:self userAcceptedIncomingCall:pendingCallBuddy withVideo:withVideo];
				[self setVisualState:kUCVSConnecting forUserSessionId:pendingCallBuddy.sessionId];
			} else {
				spreed_me_log("Buddy which is calling us is no longer in UsersManager's list. This is wrong. End call");
				[self rejectIncomingCall];
			}
			self.pendingIncomingCallUserSessionId = nil;
			
			[self setupUIWithCallingState:kCallingViewStateInCall];
		}
	} else {
		spreed_me_log("self.pendingIncomingCallUserSessionId == nil");
	}

}


- (void)hangUp
{
	[self invalidateButtonContainerHideTimer];
	if (self.userActionsDelegate && [self.userActionsDelegate respondsToSelector:@selector(userHangUpInCallingViewController:)]) {
		[self.userActionsDelegate userHangUpInCallingViewController:self];
	}
}


- (void)rejectIncomingCall
{
	[self invalidateButtonContainerHideTimer];
	if (self.userActionsDelegate && [self.userActionsDelegate respondsToSelector:@selector(callingViewController:userRejectedIncomingCall:)]) {
		[self.userActionsDelegate callingViewController:self userRejectedIncomingCall:[[UsersManager defaultManager] userForSessionId:self.pendingIncomingCallUserSessionId]];
	}
}


- (void)cancelOutgoingCall
{
	[self invalidateButtonContainerHideTimer];
	if (self.userActionsDelegate && [self.userActionsDelegate respondsToSelector:@selector(userCanceledOutgoingCall:)]) {
		[self.userActionsDelegate userCanceledOutgoingCall:self];
	}
}


#pragma mark - UI Actions

- (IBAction)hangUpButtonPressed:(id)sender
{
	[self hangUp];
}


- (IBAction)pickUpButtonPressed:(id)sender
{
	[self pickUpCallWithVideo:NO];
}


- (IBAction)pickUpVideoButtonPressed:(id)sender
{
	[self pickUpCallWithVideo:YES];
}


- (IBAction)rejectIncomingCallButtonPressed:(id)sender
{
	[self rejectIncomingCall];
}


- (IBAction)cancelOutgoingCallButtonPressed:(id)sender
{
	[self cancelOutgoingCall];
}


- (IBAction)muteButtonPressed:(id)sender
{
	[self invalidateButtonContainerHideTimer];
	
	if ([sender isKindOfClass:[UIButton class]] && sender == self.muteButton) {
		self.muteButton.selected = !self.muteButton.selected;
	}
	if (self.userActionsDelegate && [self.userActionsDelegate respondsToSelector:@selector(callingViewController:userSetSoundMuted:)]) {
		BOOL shouldMute = self.muteButton.selected;
		[self.userActionsDelegate callingViewController:self userSetSoundMuted:shouldMute];
	}
}


- (IBAction)videoOptionsButtonPressed:(id)sender
{
	[self invalidateButtonContainerHideTimer];
	
	if ([sender isKindOfClass:[UIButton class]] && sender == self.videoOptionsButton) {
		self.videoOptionsButton.selected = !self.videoOptionsButton.selected;
	}
	if (self.userActionsDelegate && [self.userActionsDelegate respondsToSelector:@selector(callingViewController:userSetVideoMuted:)]) {
		BOOL shouldMute = self.videoOptionsButton.selected;
		[self.userActionsDelegate callingViewController:self userSetVideoMuted:shouldMute];
		self.mutedVideoInfoView.hidden = !shouldMute;
	}
	
    if (!_videoOptionsPopupView) {
//        [self hideAllOptionsOfButtonContainer];
//        // Create Video options popup view
//        UIButton *frontCameraButton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 150, 50)];
//        UIButton *rearCameraButton = [[UIButton alloc]initWithFrame:CGRectMake(0, 50, 150, 50)];
//        [frontCameraButton setTitle:@"Front Camera" forState:UIControlStateNormal];
//        [rearCameraButton setTitle:@"Rear Camera" forState:UIControlStateNormal];
//        UIView * videoOptionsView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 150, 100)];
//        [videoOptionsView addSubview:frontCameraButton];
//        [videoOptionsView addSubview:rearCameraButton];
//        _videoOptionsPopupView = [[PopUpView alloc]init];
//        _videoOptionsPopupView = [_videoOptionsPopupView popupViewInView:self.view withContentSize:videoOptionsView.frame.size
//                                                              pointingTo:CGPointMake(self.videoOptionsButton.frame.origin.x + (self.videoOptionsButton.frame.size.width/2), self.buttonContainer.frame.origin.y) forceUp:YES];
//        _videoOptionsPopupView.contentView = videoOptionsView;
//        _videoOptionsPopupView.bubbleColor = [UIColor colorWithRed:132.0f/255.0f green:184.0f/255.0f blue:25.0f/255.0f alpha:0.8];
//        [self.view addSubview: _videoOptionsPopupView];
    } else {
        [_videoOptionsPopupView removeFromSuperview];
        _videoOptionsPopupView = nil;
    }
}


- (IBAction)moreOptionsButtonPressed:(id)sender
{
	[self invalidateButtonContainerHideTimer];
    [self removeBadgeNumberAtMoreOptionsButton];
    
    if (!_moreOptionsPopupView) {
        [self hideAllOptionsOfButtonContainer];
        // Create More Options popup view
		
		NSInteger optionsCount = 3;
		if (self.hasScreenSharingUsers) {
			optionsCount = 4;
		}
		
        _moreOptionsPopupView = [PopUpListView popupViewInView:self.view
											   withContentSize:CGSizeMake(150.0f, 44.0f * optionsCount)
													   toPoint:CGPointMake(self.moreOptionsButton.frame.origin.x + (self.moreOptionsButton.frame.size.width/2), self.buttonContainer.frame.origin.y)
													   forceUp:YES
												  withDelegate:self];
        _moreOptionsPopupView.bubbleColor = kSMBlueButtonColorAlpha08;
        
		[_moreOptionsPopupView reload];
        [self.view addSubview:_moreOptionsPopupView];
    } else {
        [_moreOptionsPopupView removeFromSuperview];
        _moreOptionsPopupView = nil;
    }
}


- (void)addBuddyButtonPressed:(id)sender
{
	if (!_currentBuddyListViewController) {
		_currentBuddyListViewController = [[BuddyListViewController alloc] initWithNibName:@"BuddyListViewController" bundle:nil];
		_currentBuddyListViewController.delegate = self;
        _currentBuddyListViewController.navigationLeftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                                                            target:_currentBuddyListViewController
                                                                                                                            action:@selector(cancel)];
	}
	
	_currentBuddyListViewController.buddies = [[UsersManager defaultManager] roomUsersSortedByDisplayName];
	
	NSMutableSet *set = [NSMutableSet set];
	for (BuddyVisual *buddyVisual in self.buddiesOnCall) {
		[set addObject:buddyVisual.buddy.sessionId];
	}
	
	_currentBuddyListViewController.selectedUserSessionIds = [NSSet setWithSet:set];
	
	[self presentBuddyListViewController];
    
    [_moreOptionsPopupView removeFromSuperview];
    _moreOptionsPopupView = nil;
}


- (void)hideCallingViewAndShowUIPlace:(UserInterfacePlace)place
{
	[self hideAllOptionsOfButtonContainer];
    
    _unreadMessagesDict = [[NSMutableDictionary alloc] init];
	
	UIView *activeCallView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, [CallWidget size].width, [CallWidget size].height)];
	UIImageView *imageView = [[UIImageView alloc] initWithFrame:activeCallView.bounds];
	imageView.image = [UIImage imageNamed:@"logo_icon"];
	imageView.contentMode = UIViewContentModeScaleAspectFit;
	[activeCallView addSubview:imageView];
	
	[[UserInterfaceManager sharedInstance] hideExistingCallToShow:place
													 backIconView:activeCallView
															 text:NSLocalizedStringWithDefaultValue(@"label_active-call",
																									nil, [NSBundle mainBundle],
																									@"Active call",
																									@"Active call(noun)")];
}


#pragma mark - PopUpListView delegate

- (NSInteger)listItemsCountInPopUpListView:(PopUpListView *)listView
{
	if (listView == _moreOptionsPopupView) {
		NSInteger optionsCount = 3;
		if (self.hasScreenSharingUsers) {
			optionsCount = 4;
		}
		
		return optionsCount;
	}
	
	return 0;
}


- (NSAttributedString *)optionNameInPopUpListView:(PopUpListView *)listView forIndex:(NSInteger)index
{
	if (listView == _moreOptionsPopupView) {
		NSAttributedString *optionName = nil;
		switch (index) {
			case 0:
				optionName = [[NSAttributedString alloc] initWithString:kSMLocalStringUsersLabel];
				break;
			case 1:
				optionName = [[NSAttributedString alloc] initWithString:kSMLocalStringFilesLabel];
				break;
			case 2:
				optionName = [[NSAttributedString alloc] initWithString:kSMLocalStringChatsLabel];
				break;
			case 3:
				optionName = [[NSAttributedString alloc] initWithString:kSMLocalStringScreenSharingLabel];
				break;
				
			default:
				break;
		}
		return optionName;
	}
	
	return nil;
}


- (NSInteger)badgeNumberInPopUpListView:(PopUpListView *)listView forIndex:(NSInteger)index
{
    if (listView == _moreOptionsPopupView) {
        NSInteger badgeNumber = 0;
        switch (index) {
            case 2:
                badgeNumber = [_unreadMessagesDict count];
                break;
                
            case 3:
                badgeNumber = _uncheckedScreenSharers;
                break;
                
            default:
                break;
        }
        return badgeNumber;
    }
    
    return 0;
}


- (void)didSelectOptionInPopUpListView:(PopUpListView *)listView atIndex:(NSInteger)index
{
	if (listView == _moreOptionsPopupView) {
		switch (index) {
			case 0:
				[self hideCallingViewAndShowUIPlace:kUserInterfacePlaceUsers];
				break;
			case 1:
				[self hideCallingViewAndShowUIPlace:kUserInterfacePlaceFiles];
				break;
			case 2:
				[self hideCallingViewAndShowUIPlace:kUserInterfacePlaceChats];
				break;
			case 3:
				[self screenSharingOptionChosen];
				break;
			default:
				break;
		}
	}
}


#pragma mark - Users update protocol

- (void)userHasBeenUpdated:(User *)user
{
	if (user && (self.buddiesOnCall.count > 0 || self.pendingIncomingCallUserSessionId)) {
		BuddyVisual *buddyVisual = [self buddyVisualForBuddySessionId:user.sessionId];
		[self updateUIForBuddyVisual:buddyVisual];
	}
}


#pragma mark - Add new buddies to call

- (void)presentBuddyListViewController
{
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		_addBuddyPopover = [[UIPopoverController alloc] initWithContentViewController:_currentBuddyListViewController];
//		[_addBuddyPopover presentPopoverFromRect:self.addBuddyButton.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	} else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:_currentBuddyListViewController];
		[self presentViewController:nav animated:YES completion:NULL];
	}
}


- (void)dismissBuddyListViewController
{
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		[_addBuddyPopover dismissPopoverAnimated:YES];
	} else {
		[self dismissViewControllerAnimated:YES completion:NULL];
	}
}


#pragma mark - Select screensharing from list

- (void)presentScreensharingListViewController
{
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		_selectScreensharingPopover = [[UIPopoverController alloc] initWithContentViewController:_currentScreensharingListViewController];
		_currentScreensharingListViewController.contentSizeForViewInPopover = CGSizeMake(320.0f, 480.0f); // iPhone 4 size
		[_selectScreensharingPopover presentPopoverFromRect:[self.view convertRect:self.moreOptionsButton.frame fromView:self.moreOptionsButton.superview]
													 inView:self.view
								   permittedArrowDirections:UIPopoverArrowDirectionAny
												   animated:YES];
	} else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:_currentScreensharingListViewController];
		[self presentViewController:nav animated:YES completion:NULL];
	}
}


- (void)dismissScreensharingListViewControllerIfPresented
{
    if (_currentScreensharingListViewController.isViewLoaded && _currentScreensharingListViewController.view.window) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [_selectScreensharingPopover dismissPopoverAnimated:YES];
        } else {
            [self dismissViewControllerAnimated:YES completion:NULL];
        }
    }
}


#pragma mark - BuddyListViewControllerDelegate

- (void)buddyListViewController:(BuddyListViewController *)buddyListViewController didSelectBuddy:(User *)buddy
{
    if (buddyListViewController == _currentBuddyListViewController) {
        // If buddy is nil it means he/she is already added to call
        if (buddy) {
            if ([self.userActionsDelegate respondsToSelector:@selector(callingViewController:userAddedBuddyToCall:withVideo:)]) {
                [self.userActionsDelegate callingViewController:self userAddedBuddyToCall:buddy withVideo:YES];
            }
        }
        [self dismissBuddyListViewController];
    } else if (buddyListViewController == _currentScreensharingListViewController) {
        if (buddy) {
            [self screenSharingUserSessionIdSelected:buddy.sessionId];
        }
        [self dismissScreensharingListViewControllerIfPresented];
    } else {
        spreed_me_log("Unrecognized BuddyListViewController");
    }
}


#pragma mark - UserRecentActivityControllerUpdatesListener delegate

- (void)userActivityController:(UsersActivityController *)controller
                 userSessionId:(NSString *)userSessionId
               hasBeenActiveAt:(NSString *)dayLimitedDateString
           movedOnTopFromIndex:(NSUInteger)fromIndex

{
    if (self.isViewLoaded && self.view.window) {
        [self showButtonContainerAnimated:YES];
        [self addUnreadChatWithUserSessionId:userSessionId];
    }
}


#pragma mark - Utils

- (void)addUnreadChatWithUserSessionId:(NSString *)userSessionId
{
    NSNumber *unreadMessages = [_unreadMessagesDict objectForKey:userSessionId];
    [_unreadMessagesDict setObject:@([unreadMessages integerValue] + 1) forKey:userSessionId];
    [self updateMoreOptionsButtonBadgeNumbers];
}


- (void)updateMoreOptionsButtonBadgeNumbers
{
    NSInteger badgeNumber = 0;
    NSUInteger unreadChats = [_unreadMessagesDict count];
    
    if (unreadChats > 0) {
        badgeNumber += 1;
    }
    
    if (_uncheckedScreenSharers > 0) {
        badgeNumber += 1;
    }
    
    if (_moreOptionsPopupView) {
        [_moreOptionsPopupView removeFromSuperview];
        _moreOptionsPopupView = nil;
        [self moreOptionsButtonPressed:self];
    }
    
    [self setBadgeNumberAtMoreOptionsButton:badgeNumber];
}


#pragma mark - UICollectionView Datasource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return [_buddiesOnCall count];
}


- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	BuddyCollectionViewCell *cell = (BuddyCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"BuddyCollectionViewCell" forIndexPath:indexPath];
	
	BuddyVisual *buddyVisual = [_buddiesOnCall objectAtIndex:indexPath.row];
	
	
	cell.buddyVisual = buddyVisual;
	[cell updateUI];
	
	return cell;
}


#pragma mark - Screen Sharing

- (void)userHasStartedScreensharing:(NSString *)userSessionId
{
    User *screenSharer = [[UsersManager defaultManager] userForSessionId:userSessionId];
    UIImage *alertImage = (screenSharer.iconImage) ? screenSharer.iconImage : [UIImage imageNamed:@"logo_icon"];
    SoftAlert *alert = [[SoftAlert alloc] initWithTitle:screenSharer.displayName
                                                message:NSLocalizedStringWithDefaultValue(@"button_tap-to-view-shared-screen",
																						  nil, [NSBundle mainBundle],
																						  @"Tap to view screen",
																						  @"Tap(verb) to view screen(screensharing enabled by remote user)")
                                                  image:alertImage
                                            actionBlock:^{
                                                [self screenSharingUserSessionIdSelected:userSessionId];
                                            }];
    [alert show];
    [self showButtonContainerAnimated:YES];
    _uncheckedScreenSharers += 1;
    [self updateMoreOptionsButtonBadgeNumbers];
}


- (void)screenSharingOptionChosen
{
    if (!_currentScreensharingListViewController) {
        _currentScreensharingListViewController = [[BuddyListViewController alloc] initWithNibName:@"BuddyListViewController" bundle:nil];
        _currentScreensharingListViewController.delegate = self;
        _currentScreensharingListViewController.navigationLeftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                                                            target:_currentScreensharingListViewController
                                                                                                                            action:@selector(cancel)];
    }
    
    _uncheckedScreenSharers = 0;
    
    _currentScreensharingListViewController.selectedUserSessionIds = [NSSet setWithObjects:_currentScreenSharerSessionId, nil];
    NSMutableArray *screensharingBuddies = [NSMutableArray array];
    for (NSString *userSessionId in [[PeerConnectionController sharedInstance] screenSharingUsers]) {
        User *buddy = [[UsersManager defaultManager] userForSessionId:userSessionId];
        [screensharingBuddies addObject:buddy];
    }
    _currentScreensharingListViewController.buddies = [NSArray arrayWithArray:screensharingBuddies];
		
	[self presentScreensharingListViewController];
    
    [_moreOptionsPopupView removeFromSuperview];
    _moreOptionsPopupView = nil;

}


- (void)screenSharingUserSessionIdSelected:(NSString *)userSessionId
{
    if (_remoteScreenSharingStarted) {
        [self hideScreenSharingButtonPressed:nil];
		//[self hideAllOptionsOfButtonContainer];
	}
    _remoteScreenSharingStarted = YES;
    
    [self initializeScreenSharingContainerView];
    
    PeerConnectionController *pcController = [PeerConnectionController sharedInstance];
    //We expect that userSessionId is in the list of currentScreenSharers
    [pcController connectToScreenSharingForUserSessionId:userSessionId];
    _currentScreenSharerSessionId = userSessionId;
    [self hideAllOptionsOfButtonContainer];
}


- (void)initializeScreenSharingContainerView
{
    self.screenSharingContainerView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.screenSharingContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.screenSharingContainerView.backgroundColor = [[UIColor alloc] initWithPatternImage:[UIImage imageNamed:@"bg-tiles.png"]];
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(checkHideShowButtonContainer:)];
    [self.screenSharingContainerView addGestureRecognizer:tapGesture];
    
    self.screenSharingScrollView = [[UIScrollView alloc] initWithFrame:self.screenSharingContainerView.bounds];
    self.screenSharingScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.screenSharingContainerView addSubview:self.screenSharingScrollView];
    
    RoundedRectButton *closeButton = [RoundedRectButton buttonWithType:UIButtonTypeRoundedRect];
    CGFloat closeButtonYpos = 20.0f;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7.0) {
        closeButtonYpos = 0.0f;
    }
    
    closeButton.frame = CGRectMake(5.0f, closeButtonYpos, 32.0f, 32.0f);
    closeButton.titleLabel.font = [UIFont fontWithName:kFontAwesomeFamilyName size:22];
    [closeButton setTitle:[NSString fontAwesomeIconStringForEnum:FATimes] forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeButton setCornerRadius:16.0f];
    [closeButton setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(hideScreenSharingButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.screenSharingContainerView addSubview:closeButton];
    
    [self.view addSubview:self.screenSharingContainerView];
    
    [self.view bringSubviewToFront:self.buttonContainer];
    
    [self showStartScreenSharingNotification];
}


- (void)endRemoteScreenSharing
{
    [self hideStartScreenSharingNotification];
    
	self.screenSharingContainerView.hidden = YES;
	
	for (UIView *view in self.screenSharingScrollView.subviews) {
		[view removeFromSuperview];
	}
	
	if (self.secondaryWindow) {
		for (UIView *view in self.secondaryWindow.subviews) {
			[view removeFromSuperview];
		}
		self.secondaryWindow = nil;
	}
	
	[[PeerConnectionController sharedInstance] stopRemoteScreenSharingForUserSessionId:_currentScreenSharerSessionId];
	_currentScreenSharerSessionId = nil;
	_remoteScreenSharingStarted = NO;
}


- (void)hideScreenSharingButtonPressed:(id)sender
{
	[self endRemoteScreenSharing];
}


#pragma mark - Video Rendering

- (void)panLocalVideoRenderView:(UIPanGestureRecognizer *)sender
{
	CGPoint location = [sender locationInView:self.view];
	
	self.localVideoRenderView.center = location;
}


#pragma mark - UserInterfaceCallbacks

- (void)firstOutgoingCallStartedWithUserSessionId:(NSString *)userSessionId withVideo:(BOOL)video
{
    if (video) {
        [self setupUIWithCallingState:kCallingViewStatePendingOutgoingVideoCall];
    } else {
        [self setupUIWithCallingState:kCallingViewStatePendingOutgoingCall];
    }
    
	[self addToCallUserSessionId:userSessionId withVisualState:kUCVSOutgoingCall];
}


- (void)firstIncomingCallReceivedWithUserSessionId:(NSString *)userSessionId
{
	[self setUIForIncomingCall];
    [self setupUIWithCallingState:kCallingViewStatePendingIncomingCall];
	[self addToCallUserSessionId:userSessionId withVisualState:kUCVSIncomingCall];
	if (self.pendingIncomingCallUserSessionId) {
		NSAssert(false, @"Error pending incoming call user ID is not nil!");
	}
	self.pendingIncomingCallUserSessionId = userSessionId;
}


- (void)outgoingCallStartedWithUserSessionId:(NSString *)userSessionId
{
	[self addToCallUserSessionId:userSessionId withVisualState:kUCVSConnecting];
}


- (void)incomingCallReceivedWithUserSessionId:(NSString *)userSessionId
{
	[self addToCallUserSessionId:userSessionId withVisualState:kUCVSConnecting];
}


- (void)callConnectionEstablishedWithUserSessionId:(NSString *)userSessionId
{
    [self setupUIWithCallingState:kCallingViewStateInCall];
	BuddyVisual *buddyVisual = [self buddyVisualForBuddySessionId:userSessionId];
	buddyVisual.visualState = kUCVSConnected;
	[self updateUIForBuddyVisual:buddyVisual];
	
	if ([_buddiesOnCall count] == 1 && !_callHasStarted) {
		_callHasStarted = YES;
		[self startCountingCallTime];
	}
}


- (void)callConnectionLostWithUserSessionId:(NSString *)userSessionId
{
	BuddyVisual *buddyVisual = [self buddyVisualForBuddySessionId:userSessionId];
	buddyVisual.visualState = kUCVSDisconnected;
	[self updateUIForBuddyVisual:buddyVisual];
}


- (void)callConnectionFailedWithUserSessionId:(NSString *)userSessionId
{
	BuddyVisual *buddyVisual = [self buddyVisualForBuddySessionId:userSessionId];
	buddyVisual.visualState = kUCVSFailed;
	[self updateUIForBuddyVisual:buddyVisual];
}


- (void)callIsFinishedWithReason:(SMCallFinishReason)callFinishReason
{
    [self setDisconnectedVisualStateForAllVisibleCells];
    
    [self dismissScreensharingListViewControllerIfPresented];
	
	self.pendingIncomingCallUserSessionId = nil;
	[self.buddiesOnCall removeAllObjects];
	[self.collectionView reloadData]; // force cells to redraw or to be deleted
	
	/*
	 We must remove local video render view as soon as we don't need it.
	 We had a problem when newly created localVideoRenderView wasn't showing content due to existence of previous one.
	 */
	[self.localVideoRenderView removeFromSuperview];
	self.localVideoRenderView = nil;
	
	[self stopCountingCallTime];
	_callHasStarted = NO;
    
    switch (callFinishReason) {
        case kSMCallFinishReasonInternalError:
            // maybe do not dismiss calling view controller as it has to signal problem to user
            [self dismissCallingView];
            break;
            
        case kSMCallFinishReasonUnspecified:
        case kSMCallFinishReasonLocalHangUp:
        case kSMCallFinishReasonRemoteHungUp:
        default:
            [self dismissCallingView];
            break;
    }
}


- (void)dismissCallingView
{
    [[UserInterfaceManager sharedInstance] dismissCallingViewControllerWithCompletionBlock:^{
        [self setupUIWithCallingState:kCallingViewStateCallIsFinished];
    }];
}


- (void)remoteUserHungUp:(NSString *)userSessionId
{
	BuddyVisual *buddyVisual = [self buddyVisualForBuddySessionId:userSessionId];
	buddyVisual.visualState = kUCVSDisconnected;
	[self updateUIForBuddyVisual:buddyVisual];
	double delayInSeconds = 1.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		[self removeFromCallUserSessionId:userSessionId];
	});
}


- (void)noAnswerFromUserSessionId:(NSString *)userSessionId
{
	
}


- (void)newMissedCallFromUserSessionId:(NSString *)userSessionId
{
	
}


- (void)incomingCallWasAutoRejectedWithUserSessionId:(NSString *)userSessionId
{
}


- (void)localVideoRenderViewWasCreated:(UIView *)view forTrackId:(NSString *)trackId inStreamWithLabel:(NSString *)streamLabel
{
	[self.localVideoRenderView removeFromSuperview];
	self.localVideoRenderView = view;
	self.localVideoRenderView.backgroundColor = [UIColor blackColor];
	
	// We AffineTransform in order to fix 'openGL rotation'
	// For local video stream we also have to flip video in order to show local user what exactly sees remote user.
	CGAffineTransform transform = CGAffineTransformIdentity;
	transform = CGAffineTransformScale(transform, -1.0f, 1.0f);
	transform = CGAffineTransformRotate(transform, M_PI);
	self.localVideoRenderView.transform = transform;
	
	[self.view addSubview:self.localVideoRenderView];
	[self setupLocalVideoRenderViewWithAspectRatio:1.0f];
	self.localVideoRenderView.frame = CGRectMake(self.collectionView.frame.size.width - self.localVideoRenderView.frame.size.width,
												 self.collectionView.frame.size.height - self.localVideoRenderView.frame.size.height - self.buttonContainer.frame.size.height,
												 self.localVideoRenderView.frame.size.width, self.localVideoRenderView.frame.size.height);
	
	[self.view bringSubviewToFront:self.localVideoRenderView];
	
	self.mutedVideoInfoView.hidden = YES;
	[self.mutedVideoInfoView removeFromSuperview];
	self.mutedVideoInfoView.transform = self.localVideoRenderView.transform;
    
    CGSize localVideoSize = self.localVideoRenderView.frame.size;
    CGRect mutedVideoFrame = self.mutedVideoInfoView.frame;
    
    mutedVideoFrame.size = localVideoSize;
    self.mutedVideoInfoView.frame = mutedVideoFrame;
    
	[self.localVideoRenderView addSubview:self.mutedVideoInfoView];
	
	
	UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panLocalVideoRenderView:)];
	panGesture.maximumNumberOfTouches = 1;
	panGesture.minimumNumberOfTouches = 1;
	
	NSArray *gestures = self.localVideoRenderView.gestureRecognizers;
	for (UIGestureRecognizer *gestureRecognizer in gestures) {
		[self.localVideoRenderView removeGestureRecognizer:gestureRecognizer];
	}
	
	[self.localVideoRenderView addGestureRecognizer:panGesture];
    
    [self.view bringSubviewToFront:self.buttonContainer];
}


- (void)remoteVideoRenderView:(UIView *)view wasCreatedForUserSessionId:(NSString *)userSessionId forTrackId:(NSString *)trackId inStreamWithLabel:(NSString *)streamLabel
{
	BuddyVisual *buddyVisualToUpdate = nil;
	NSInteger buddyVisualToUpdateIndex = -1;
	for (BuddyVisual *buddyVisual in _buddiesOnCall) {
		if ([buddyVisual.buddy.sessionId isEqualToString:userSessionId]) {
			buddyVisualToUpdate = buddyVisual;
			buddyVisualToUpdateIndex = [_buddiesOnCall indexOfObject:buddyVisual];
			break;
		}
	}
	
	if (buddyVisualToUpdate) {
		buddyVisualToUpdate.videoRenderView = view;
		
		// We need AffineTransform in order to fix 'openGL rotation'
		CGAffineTransform transform = CGAffineTransformIdentity;
		transform = CGAffineTransformRotate(transform, M_PI);
		buddyVisualToUpdate.videoRenderView.transform = transform;
		
		BuddyCollectionViewCell *cell = (BuddyCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:buddyVisualToUpdateIndex inSection:0]];
		cell.buddyVisual = buddyVisualToUpdate;
		[cell updateUI];
	}
}


- (void)remoteVideoRenderView:(UIView *)view
			 forUserSessionId:(NSString *)userSessionId
				   forTrackId:(NSString *)trackId
			inStreamWithLabel:(NSString *)streamLabel
			  hasSetFrameSize:(CGSize)frameSize
{
	CGFloat aspectRatio = frameSize.height / frameSize.width;
	
	BuddyVisual *buddyVisualToUpdate = nil;
	NSInteger buddyVisualToUpdateIndex = -1;
	for (BuddyVisual *buddyVisual in _buddiesOnCall) {
		if ([buddyVisual.buddy.sessionId isEqualToString:userSessionId]) {
			buddyVisualToUpdate = buddyVisual;
			buddyVisualToUpdateIndex = [_buddiesOnCall indexOfObject:buddyVisual];
			break;
		}
	}
	
	if (buddyVisualToUpdate) {
		buddyVisualToUpdate.videoRenderView = view;
		buddyVisualToUpdate.videoRenderViewAspectRatio = aspectRatio;
		BuddyCollectionViewCell *cell = (BuddyCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:buddyVisualToUpdateIndex inSection:0]];
		cell.buddyVisual = buddyVisualToUpdate;
		[cell updateUI];
	}
}


- (void)localVideoRenderView:(UIView *)view
				  forTrackId:(NSString *)trackId
		   inStreamWithLabel:(NSString *)streamLabel
			 hasSetFrameSize:(CGSize)frameSize
{
	CGFloat aspectRatio = frameSize.height / frameSize.width;
	
	if (self.localVideoRenderView == view) {
		[self setupLocalVideoRenderViewWithAspectRatio:aspectRatio];
	} else {
		spreed_me_log("Current localVideoRenderView is not equal to the one which aspect ratio has changed!");
	}
}


- (void)setupLocalVideoRenderViewWithAspectRatio:(CGFloat)aspectRatio
{
	CGFloat localVideoRenderViewWidth;
    CGFloat localVideoRenderViewHeight;
    
    if (aspectRatio > 1.0f) {
        localVideoRenderViewWidth = 80.0f;
        localVideoRenderViewHeight = localVideoRenderViewWidth * aspectRatio;
    } else {
        localVideoRenderViewHeight = 80.0f;
        localVideoRenderViewWidth = localVideoRenderViewHeight / aspectRatio;
    }
	
	CGPoint previousCenter = self.localVideoRenderView.center;
	
	CGSize previousSize = self.localVideoRenderView.frame.size;
	
	self.localVideoRenderView.frame = CGRectMake(0.0f, 0.0f, floorf(localVideoRenderViewWidth), floorf(localVideoRenderViewHeight));
	
	CGPoint translation = CGPointZero;
	translation.x = (previousSize.width - self.localVideoRenderView.frame.size.width) / 2.0f;
	translation.y = (previousSize.height - self.localVideoRenderView.frame.size.height) / 2.0f;
	
	self.localVideoRenderView.center = CGPointMake(previousCenter.x + translation.x, previousCenter.y + translation.y);
}


- (void)screenSharingVideoRenderView:(UIView *)view
		  wasCreatedForUserSessionId:(NSString *)userSessionId
						  forTrackId:(NSString *)trackId
				   inStreamWithLabel:(NSString *)streamLabel
{
	for (UIView *view in self.screenSharingScrollView.subviews) {
		[view removeFromSuperview];
	}
	
	
	if ([[UIScreen screens] count] > 1) {
		UIScreen *additionalScreen = [[UIScreen screens] objectAtIndex:1];
		
		spreed_me_log("Found additional screen %s", [additionalScreen cDescription]);
		
		UIWindow *scrWindow = [[UIWindow alloc] initWithFrame:additionalScreen.bounds];
		scrWindow.backgroundColor = [UIColor redColor];
		scrWindow.screen = additionalScreen;
		scrWindow.hidden = NO;
		self.secondaryWindow = scrWindow;
		
		[self.screenSharingContainerView removeFromSuperview];
		self.screenSharingContainerView.frame = self.secondaryWindow.bounds;
		self.screenSharingScrollView.frame = self.screenSharingContainerView.bounds;
		[self.secondaryWindow addSubview:self.screenSharingContainerView];
	}
	
	if (self.screenSharingRenderView != view) {
		CGRect newFrame = CGRectMake(0.0f, 0.0f, 1280.0f, 720.0f); // These are magic numbers. We expect real values in another method
		
		view.frame = newFrame;
		CGAffineTransform transform = CGAffineTransformIdentity;
		transform = CGAffineTransformScale(transform, -1.0f, 1.0f);
		transform = CGAffineTransformRotate(transform, M_PI);
		view.transform = transform;
		[self.screenSharingScrollView addSubview:view];
		self.screenSharingScrollView.contentSize = view.bounds.size;
		self.screenSharingRenderView = view;
	}
}


- (void)screenSharingVideoRenderView:(UIView *)view
					forUserSessionId:(NSString *)userSessionId
						  forTrackId:(NSString *)trackId
				   inStreamWithLabel:(NSString *)streamLabel
					 hasSetFrameSize:(CGSize)frameSize
{
    [self hideStartScreenSharingNotification];
    
	if (self.screenSharingRenderView == view) {
	
		// Since GLKView doesn't allow (or at least we have problems with) frames that are larger than 2048 units
		// we have to downscale our video frame in order for it to work.
		
		CGFloat largerSide = frameSize.width > frameSize.height ? frameSize.width : frameSize.height;
		CGFloat downscaleRatio = 1.0f;
		
		if (largerSide > 2048.0f) {
			downscaleRatio = 2048.0f / largerSide;
		}
		
		if (downscaleRatio != 1.0f) {
			frameSize.width = floorf(frameSize.width * downscaleRatio);
			frameSize.height = floorf(frameSize.height * downscaleRatio);
		}
		
		if (self.secondaryWindow) {
			
			CGRect frameRect = CGRectMake(0.0f, 0.0f, frameSize.width, frameSize.height);
			
			if (CGRectContainsRect(self.secondaryWindow.bounds, frameRect)) {
				view.frame = frameRect;
			} else {
				// Fit screensharing frame into secondary display window
				while (!CGRectContainsRect(self.secondaryWindow.bounds, frameRect)) {
					frameRect = CGRectApplyAffineTransform(frameRect, CGAffineTransformMakeScale(0.97f, 0.97f));
					frameRect.origin = CGPointZero;
					frameRect.size.width = floorf(frameRect.size.width);
					frameRect.size.height = floorf(frameRect.size.height);
				}
				
				view.frame = frameRect;
			}
			
		} else {
			view.frame = CGRectMake(0.0f, 0.0f, frameSize.width, frameSize.height);
		}
		
		CGAffineTransform transform = CGAffineTransformIdentity;
		transform = CGAffineTransformScale(transform, -1.0f, 1.0f);
		transform = CGAffineTransformRotate(transform, M_PI);
		view.transform = transform;
		self.screenSharingScrollView.contentSize = view.frame.size;
		spreed_me_log("screen sharing framesize %.1f:%.1f; downscale %.3f", frameSize.width, frameSize.height, downscaleRatio);
	}
}


- (void)screenSharingHasBeenStoppedByRemoteUser:(NSString *)userSessionId
{
	if ([userSessionId isEqualToString:_currentScreenSharerSessionId]) {
		[self endRemoteScreenSharing];
	}
}


@end
