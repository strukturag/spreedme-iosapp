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

#import "PeerConnectionController.h"
#import "PeerConnectionController_ObjectiveCPP.h"

#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

// webrtc
#include <webrtc/modules/video_render/ios/video_render_ios_view.h>

// webrtc extensions
#include "PeerConnectionWrapperFactory.h"
#include "PeerConnectionWrapper.h"
#include "Call.h"
#include "ScreenSharingHandler.h"
#include "TalkBaseThreadWrapper.h"

// Cpp bridges
#import "CallDelegate.h"
#import "ObjCMessageQueue.h"
#import "ScreenSharingHandlerDelegate.h"

// Objc
#import "UsersManager.h"
#import "CallingViewController.h"
#import "ChatManager.h"
#import "FileSharingManagerObjC.h"
#import "MissedCall.h"
#import "MissedCallManager.h"
#import "UsersActivityController.h"
#import "SMConnectionController_ObjectiveCPP.h"
#import "SMLocalizedStrings.h"
#import "STLocalNotificationManager.h"
#import "SoftAlert.h"
#import "VideoRendereriOSInfo.h"
#import "UIDevice+Hardware.h"
#import "UserInterfaceManager.h"

using namespace spreedme;


NSString * const CallIsFinishedNotification		= @"CallIsFinishedNotification";
NSString * const UserHasLeftCallNotification	= @"UserHasLeftCallNotification";
NSString * const kUserSessionIdKey = @"UserSessionIdKey";


NSString *const kCallTimerIncomingKey		= @"Incoming";
NSString *const kCallTimerUserSessionIdKey	= @"UserSessionId";

typedef std::pair<std::string, rtc::scoped_refptr<PeerConnectionWrapper> > PeerConnectionWrapperForID;
typedef std::pair<std::string, std::string> PeerConnectionWrapperIDForUserSessionId;

std::string stdStringFromNSString(NSString *nsString);

std::string stdStringFromNSString(NSString *nsString)
{
	std::string value;
	if (nsString) {
		value = std::string([nsString cStringUsingEncoding:NSUTF8StringEncoding]);
	} else {
		spreed_me_log("NSString from which we create std::string is nil! Crashing.");
		assert(false);
	}
	
	return value;
}

namespace spreedme {
struct CallAndDelegatesPackage
{
	explicit CallAndDelegatesPackage(spreedme::Call *call,
									 spreedme::CallDelegateInterface *delegate) :
	call(call), delegate(delegate) {};
	
	void DeleteAll()
	{
		if (call) { call->Dispose(); call = NULL;}

		if (delegate) { delete delegate; delegate = NULL; }
	};
	
	spreedme::Call *call;
	spreedme::CallDelegateInterface *delegate;
	bool hasRequestedStatistics;
};
struct ScreenSharingHandlerAndDelegatesPackage
{
	explicit ScreenSharingHandlerAndDelegatesPackage(spreedme::ScreenSharingHandler *handler,
													 spreedme::ScreenSharingHandlerDelegate *delegate) :
	handler(handler), delegate(delegate) {};
	
	void DeleteAll()
	{
		if (handler) { handler->Dispose(); handler = NULL;}
		
		if (delegate) { delete delegate; delegate = NULL; }
	};
	
	spreedme::ScreenSharingHandler *handler;
	spreedme::ScreenSharingHandlerDelegate *delegate;
	bool hasRequestedStatistics;
};
}


@interface PeerConnectionController () <UIAlertViewDelegate, CallingViewControllerUserActionsDelegate>
{
	spreedme::PeerConnectionWrapperFactory *_peerConnectionWrapperFactory;
	
	BOOL _isChannelingReady;
	
	NSString *_pendingOffer;
	
	NSString *_pendingConferenceCallerId;
	
	NSTimer *_outgoingCallTimer;
	NSTimer *_incomingCallTimer;
	
	Call *_call;
	
	CallDelegate *_callDelegate;

	float _lastVolume;
	
	UILocalNotification *_currentCallLocalNotification;
	
	NSMutableDictionary *_callRenderers;
	uint64_t _rendererNameNumber;
	
	NSString *_devicePlatform;
	
	BOOL _haveLocalRenderer;
    
    NSString *_userVideoDevice;
    int _userVideoFrameWidth;
    int _userVideoFrameHeight;
    int _userFPS;
	
	BOOL _isVideoMutedByUser;
	BOOL _isVideoMuted;
	
	BOOL _appStateNotificationSubscribed;
	
	rtc::scoped_refptr<ScreenSharingHandler> _screenSharingHandler;
	VideoRendereriOSInfo *_screenSharingRendererInfo;
	ScreenSharingHandlerDelegate *_screenSharingDelegate;
	
	ObjCMessageQueue *_callbackMainQueue;
	TalkBaseThreadWrapper *_callWorkerThread;
	TalkBaseThreadWrapper *_screenSharingQueue;
	
	NSMutableDictionary *_screenSharingUsers;
	
	std::vector<spreedme::CallAndDelegatesPackage> _pendingHungUpCalls;
	std::vector<spreedme::ScreenSharingHandlerAndDelegatesPackage> _pendingScreenSharingHandlers;
}


@property (nonatomic, readonly) User *me;

/* This property is used to track missed calls when local user does not pick up phone.*/
@property (nonatomic, strong) NSString *firstIncomingCallUserSessionId;


@end


@implementation PeerConnectionController

#pragma mark - Object Lifecycle

+ (PeerConnectionController *)sharedInstance
{
	static dispatch_once_t once;
    static PeerConnectionController *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (id)init
{
	self = [super init];
	if (self) {
		[self initializeCommunication];
        [self initializeSettings];
	}
	return self;
}


- (void)initializeSettings
{
    _userVideoDevice = @"com.apple.avfoundation.avcapturedevice.built-in_video:0";
}


- (void)initializeCommunication
{
	_peerConnectionWrapperFactory = new spreedme::PeerConnectionWrapperFactory();
	_callbackMainQueue = ObjCMessageQueue::CreateObjCMessageQueueMainQueue();
	
	rtc::Thread *callWorkerThread = new rtc::Thread();
	callWorkerThread->SetName("Call_worker_thread", callWorkerThread);
	callWorkerThread->Start();
	_callWorkerThread = new TalkBaseThreadWrapper(callWorkerThread);
	
	
	rtc::Thread *screensharingThread = new rtc::Thread();
	screensharingThread->SetName("Screensharing_thread", screensharingThread);
	screensharingThread->Start();
	_screenSharingQueue = new TalkBaseThreadWrapper(screensharingThread);
	
	_callRenderers = [[NSMutableDictionary alloc] init];
	_screenSharingUsers = [[NSMutableDictionary alloc] init];
	
	[SMConnectionController sharedInstance]; // init Connection controller
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionBecomeActive:) name:ChannelingConnectionBecomeActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedSelfMessage:) name:SelfMessageReceivedNotification object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyHungUpNotification:) name:ByeMessageReceivedNotification object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screensharingHasStarted:) name:RemoteUserHasStartedScreenSharingNotification object:nil];
}


- (spreedme::PeerConnectionWrapperFactory *)peerConnectionWrapperFactory
{
	return _peerConnectionWrapperFactory;
}


#pragma mark - Audio/Video Constraints and preferences

- (void)setConstrainsFromVideoPreferences
{
    if (_call) {
        spreedme::MediaConstraints *videoConstraints = new spreedme::MediaConstraints;
        int userVideoFrameWidth = _userVideoFrameWidth;
        int userVideoFrameHeight = _userVideoFrameHeight;
        int userFPS = _userFPS;
        
        if (_userVideoDevice) {
            std::string camera = stdStringFromNSString(_userVideoDevice);
            videoConstraints->AddMandatory(webrtc::MediaConstraintsInterface::kMaxWidth, userVideoFrameWidth);
            videoConstraints->AddMandatory(webrtc::MediaConstraintsInterface::kMaxHeight, userVideoFrameHeight);
            if (userFPS > 0) {
                videoConstraints->AddMandatory(webrtc::MediaConstraintsInterface::kMaxFrameRate, userFPS);
            }
            
            _call->SetVideoDeviceId(camera);
            _call->SetCallVideoConstraints(videoConstraints);

        } else {
            videoConstraints->AddMandatory(webrtc::MediaConstraintsInterface::kOfferToReceiveVideo, webrtc::MediaConstraintsInterface::kValueFalse);
        }
    }
}


- (void)setVideoPreferencesWithCamera:(NSString *)camera
                      videoFrameWidth:(NSInteger)videoFrameWidth
                     videoFrameHeight:(NSInteger)videoFrameHeight
                                  FPS:(NSInteger)fps
{
    _userVideoDevice = camera;
    _userVideoFrameWidth = videoFrameWidth;
    _userVideoFrameHeight = videoFrameHeight;
    _userFPS = fps;
    
    [self setConstrainsFromVideoPreferences];
}

#pragma mark - Me

- (User *)me
{
	return [UsersManager defaultManager].currentUser;
}


#pragma mark - Notifications

- (void)connectionBecomeActive:(NSNotification *)notification
{
	_isChannelingReady = YES;
	
	if (!_call) {
		[self createCall];
	}
}


- (void)receivedSelfMessage:(NSNotification *)notification
{
	NSArray *servers = [notification.userInfo objectForKey:kSelfMessageIceServersKey];
	[self updateIceServers:servers];
}


- (void)proximitySensorStateChanged:(NSNotification *)notification
{
	if (self.inCall &&
		[_userVideoDevice isEqualToString:@"com.apple.avfoundation.avcapturedevice.built-in_video:1"]) // this should correspond to frontCamera
	{
		
		if ([UIDevice currentDevice].proximityState) {
			[self muteVideo:YES userAction:NO];
		} else {
			if (!_isVideoMutedByUser) {
				[self muteVideo:NO userAction:NO];
			}
		}
	}
}


- (void)appWillResignActive:(NSNotification *)notification
{
	[self stopVideo];
}


- (void)appDidBecomeActive:(NSNotification *)notification
{
	[self startVideo];
}


#pragma mark - Update ice servers

- (void)updateIceServers:(NSArray *)servers
{
	std::vector<webrtc::PeerConnectionInterface::IceServer> iceServers;
	for (NSDictionary *dict in servers) {
		webrtc::PeerConnectionInterface::IceServer server;
		
		NSString *uri = [dict objectForKey:NSStr(kLCUrlKey)];
		if (uri && [uri isKindOfClass:[NSString class]]) {
			server.uri = [uri cStringUsingEncoding:NSUTF8StringEncoding];
		}
		
		NSString *username = [dict objectForKey:NSStr(kLCUserNameKey)];
		if (username && [username isKindOfClass:[NSString class]]) {
			server.username = [username cStringUsingEncoding:NSUTF8StringEncoding];
		}
		
		NSString *password = [dict objectForKey:NSStr(kLCPasswordKey)];
		if (password && [password isKindOfClass:[NSString class]]) {
			server.password = [password cStringUsingEncoding:NSUTF8StringEncoding];
		}
		
		if (!server.uri.empty()) {
			iceServers.push_back(server);
		}
	}
	
	if (iceServers.size()) {
		_peerConnectionWrapperFactory->SetIceServers(iceServers);
	}
}


#pragma mark - UIDevice and Application stuff handling

- (void)preventDeviceSleep:(BOOL)yesNo
{
	[UIApplication sharedApplication].idleTimerDisabled = yesNo;
}


- (void)setProximitySensorEnabled:(BOOL)enabled
{
	[UIDevice currentDevice].proximityMonitoringEnabled = enabled;
}


- (void)appIsInCall:(BOOL)yesNo
{
	self.inCall = yesNo;
	[self preventDeviceSleep:yesNo];
	[self setProximitySensorEnabled:yesNo];
	
	if (yesNo) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appAudioInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
	} else {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:nil];
	}
}


#pragma mark - Call handling

- (void)createCall
{
	if (!_call) {
		std::string selfId = stdStringFromNSString(self.me.sessionId);
		
		if (_callDelegate) {
			delete _callDelegate;
		}

		
		_callDelegate = new CallDelegate(self);
		_call = new Call(selfId, _peerConnectionWrapperFactory, [SMConnectionController sharedInstance].signallingHandler, _callWorkerThread, _callbackMainQueue);
		_call->SetDelegate(_callDelegate);
		[SMConnectionController sharedInstance].signallingHandler->RegisterMessageReceiver(_call);
		[SMConnectionController sharedInstance].signallingHandler->SetWrapperProvider(_call);
        
        [self setConstrainsFromVideoPreferences];
	}
}


- (void)muteAudio:(BOOL)mute
{
	bool cpp_mute = mute ? true : false;
	_call->MuteAudio(cpp_mute);
}


- (void)muteVideo:(BOOL)mute
{
	[self muteVideo:mute userAction:YES];
}


- (void)muteVideo:(BOOL)mute userAction:(BOOL)isUserAction
{
	if (_isVideoMuted != mute) {
		_isVideoMuted = mute;
		bool cpp_mute = mute ? true : false;
		_call->MuteVideo(cpp_mute);
	}
	
	if (isUserAction) {
		_isVideoMutedByUser = mute;
	}
}


- (void)callToBuddy:(User *)buddy withVideo:(BOOL)withVideo
{
	[[UsersManager defaultManager] holdUser:buddy forSessionId:buddy.sessionId];
	
	if (buddy.isMixer) { //conference mixer call
		
		[self callToConferenceBuddy:buddy withVideo:withVideo];
		
	} else { // one to one call
	
		[self callToSingleBuddy:buddy withVideo:withVideo];
	}
}


- (void)addUserToCall:(User *)user withVideo:(BOOL)withVideo
{
	BOOL hasVideo = (BOOL)_call->HasVideo();
	
	if (hasVideo && !withVideo) {
		hasVideo = NO;
	}
	
	[[PeerConnectionController sharedInstance] callToBuddy:user withVideo:hasVideo];
	
	[self.callingViewController addToCallUserSessionId:user.sessionId withVisualState:kUCVSConnecting];
}


- (void)callToSingleBuddy:(User *)buddy withVideo:(BOOL)withVideo
{
	spreedme::MediaConstraints *constraints = NULL;
	if (!withVideo) {
		constraints = new MediaConstraints;
		constraints->AddMandatory(webrtc::MediaConstraintsInterface::kOfferToReceiveVideo, webrtc::MediaConstraintsInterface::kValueFalse);
	}
    	
	_call->EstablishOutgoingCall(stdStringFromNSString(buddy.sessionId), constraints, false);
}


- (void)callToConferenceBuddy:(User *)buddy withVideo:(BOOL)withVideo
{
	_pendingConferenceCallerId = buddy.sessionId;
	[[SMConnectionController sharedInstance].channelingManager sendConferenceRequestMessageTo:buddy.sessionId inRoom:[UsersManager defaultManager].currentUser.room.name];
}


- (void)hangUpBuddy:(User *)buddy
{
	/* 
	 At the moment we don't have possibility to reject separate users in conference so this method is unused.
	 When we decide to add such functionality we should rewrite this method.
	 */
//	std::string userSessionId = stdStringFromNSString(buddy.sessionId);
//	_call->SendBye(userSessionId, kByeReasonNotSpecified);
//	
//	if (_call->usersOnCallCount() <= 0) {
//		[self appIsInCall:NO];
//		[self stopIOCallTimer];
//	}
}


- (void)hangUpWithReason:(ByeReason)reason
		callFinishReason:(SMCallFinishReason)callFinishReason
{
	[self cleanUpScreenSharingHandlers];
	[self removeAllVideoRenderers];
	
	
	// Unregister call in signallingHandler (P2P wrappers and message reception)
	[SMConnectionController sharedInstance].signallingHandler->SetWrapperProvider(NULL);
	[SMConnectionController sharedInstance].signallingHandler->UnRegisterMessageReceiver(_call);
	
	
	// Now we can send HangUp message
	_call->HangUp(reason);
	
	CallAndDelegatesPackage package(_call, _callDelegate);
	package.hasRequestedStatistics = false;
	_pendingHungUpCalls.push_back(package);
	[SMConnectionController sharedInstance].signallingHandler->UnRegisterMessageReceiver(_call);
	[SMConnectionController sharedInstance].signallingHandler->SetWrapperProvider(NULL);
	
	_call = NULL;
	_callDelegate = NULL;
	
	[self cleanUpAfterCallWithCallFinishReason:callFinishReason];
}


- (void)hangUp
{
	[self hangUpWithReason:kByeReasonNotSpecified callFinishReason:kSMCallFinishReasonUnspecified];
}


- (void)hangUpWithReason:(ByeReason)reason
{
	[self hangUpWithReason:reason callFinishReason:kSMCallFinishReasonUnspecified];
}


- (void)buddyHungUp:(User *)user withReason:(ByeReason)reason
{
	NSString *alertTitle = nil;
	NSString *alertMessage = nil;
	UIImage *alertImage = user.iconImage ? user.iconImage : [UIImage imageNamed:@"logo_icon"];
	
	switch (reason) {
		case kByeReasonBusy:
		{
			alertTitle = user.displayName;
			alertMessage = NSLocalizedStringWithDefaultValue(@"message_body_call-alert-view_is-busy",
															 nil, [NSBundle mainBundle],
															 @"is busy.",
															 @"This string is used in conjunction with user name: username is busy.");
		}
		break;
			
		case kByeReasonNoAnswer:
		{
			alertTitle = user.displayName;
			alertMessage = NSLocalizedStringWithDefaultValue(@"message_body_call-alert-view_is-not-answering",
															 nil, [NSBundle mainBundle],
															 @"is not answering.",
															 @"This string is used in conjunction with user name: username is not answering.");
		}
		break;
		
		case kByeReasonReject:
		{
			alertTitle = user.displayName;
			alertMessage = NSLocalizedStringWithDefaultValue(@"message_body_call-alert-view_rejected-your-call",
															 nil, [NSBundle mainBundle],
															 @"rejected your call.",
															 @"This string is used in conjunction with user name: username rejected your call.");
		}
		break;
			
		case kByeReasonAbort:
			// No need show alert
		break;
			
		case kByeReasonNotSpecified:
		{
			// we assume this is regular hangup so don't show alert
		}
		break;
			
		default:
		{
			alertTitle = user.displayName;
			alertMessage = NSLocalizedStringWithDefaultValue(@"message_body_call-alert-view_call-has-ended",
															 nil, [NSBundle mainBundle],
															 @"Call has ended.",
															 @"This string is used in conjunction with user name: username. Call has ended.");
		}
			
		break;
	}
	
	if (alertTitle && alertMessage) {
		SoftAlert *softAlert = [[SoftAlert alloc] initWithTitle:alertTitle
														message:alertMessage
														  image:alertImage
													actionBlock:NULL];
		[softAlert show];
	}
	
	
	std::string userSessionId = stdStringFromNSString(user.sessionId);
	_call->ReceivedByeMessage(userSessionId, reason);
}


- (void)processNoAnswerFromUserSessionId:(NSString *)userSessionId
{
	[self hangUpWithReason:kByeReasonAbort];
	
	if (self.userInterfaceCallbacksDelegate && [self.userInterfaceCallbacksDelegate respondsToSelector:@selector(noAnswerFromUserSessionId:)]) {
		[self.userInterfaceCallbacksDelegate noAnswerFromUserSessionId:userSessionId];
	}
}


- (BOOL)hasVideo
{
	BOOL answer = NO;
	if (self.inCall) {
		answer = _haveLocalRenderer;
	}
	
	return answer;
}


- (void)cleanUpAfterCallWithCallFinishReason:(SMCallFinishReason)callFinishReason
{
	_appStateNotificationSubscribed = NO;
	_isVideoMuted = NO;
	_isVideoMutedByUser = NO;
    [self appIsInCall:NO];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
	
	if (self.userInterfaceCallbacksDelegate && [self.userInterfaceCallbacksDelegate respondsToSelector:@selector(callIsFinishedWithReason:)]) {
		[self.userInterfaceCallbacksDelegate callIsFinishedWithReason:callFinishReason];
	}
	
	// This is missed call if we have first incoming call and call finish reason is not local hang up
	if (self.firstIncomingCallUserSessionId && callFinishReason != kCallFinishReasonLocalHangUp) {
		[self newMissedCallFromUserSessionId:self.firstIncomingCallUserSessionId];
		self.firstIncomingCallUserSessionId = nil;
	}
	
	// we actually expect here that call is already NULL if it is not true then something is wrong
	if (_call) {
		spreed_me_log("Cleaning up after call and _call(%p) is not NULL!", _call);
		_call = NULL; // we still nullify it in order 'createCall' to work but log this
	}
	
	[self createCall];
	
	[self stopIncomingCallTimer];
	[self stopOutgoingCallTimer];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:CallIsFinishedNotification object:self];
}


#pragma mark -

- (void)acceptPendingIncomingCallFrom:(NSString *)userSessionId withVideo:(BOOL)withVideo
{
	// Hold user since he/she might disconnect or leave room and we still need to have infor on him/her
	UsersManager *usersManager = [UsersManager defaultManager];
	User *user = [usersManager userForSessionId:userSessionId];
	if (user) {
		[usersManager holdUser:user forSessionId:user.sessionId];
	} else {
		spreed_me_log("This is strange. We don't have user for session id %s", [userSessionId cDescription]);
	}
	
	std::string userSessionId_cpp = stdStringFromNSString(userSessionId);
	
	spreedme::MediaConstraints *constraints = NULL;
	if (!withVideo) {
		constraints = new MediaConstraints;
		constraints->AddMandatory(webrtc::MediaConstraintsInterface::kOfferToReceiveVideo, webrtc::MediaConstraintsInterface::kValueFalse);
	}
	
	_call->AcceptIncomingCall(userSessionId_cpp, std::string(), constraints);
}


- (void)acceptIncomingCall:(User *)from withVideo:(BOOL)withVideo
{
	[self acceptPendingIncomingCallFrom:from.sessionId withVideo:withVideo];
}


- (BOOL)isUserSessionIdInCall:(NSString *)sessionId
{
	BOOL answer = NO;
	if (self.inCall) {
		std::set<std::string> sessionIds = _call->GetUsersIdsAsSet();
		std::string cpp_userSessionId = stdStringFromNSString(sessionId);
		if (sessionIds.find(cpp_userSessionId) != sessionIds.end()) {
			answer = YES;
		}
	}
	return answer;
}


#pragma mark -

- (void)createAndSetupCallingViewController
{
	self.callingViewController = [[CallingViewController alloc] initWithNibName:@"CallingViewController" bundle:nil];
	self.callingViewController.modalPresentationStyle = UIModalPresentationFullScreen;
	self.callingViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	self.userInterfaceCallbacksDelegate = self.callingViewController;
	self.callingViewController.userActionsDelegate = self;
}


- (int)calculateMaxNumberOfVideoConnections
{
	if (!_devicePlatform) {
		_devicePlatform = [[UIDevice currentDevice] platform];
	}
	
	int maxNumberOfVideoConnections = 0;
	
	if ([_devicePlatform rangeOfString:@"iPhone3"].location != NSNotFound) {
		maxNumberOfVideoConnections = 0;
	} else if ([_devicePlatform rangeOfString:@"iPhone4"].location != NSNotFound) {
		maxNumberOfVideoConnections = 3;
	} else if ([_devicePlatform rangeOfString:@"iPhone5"].location != NSNotFound) {
		maxNumberOfVideoConnections = 4;
	} else if ([_devicePlatform rangeOfString:@"iPhone6"].location != NSNotFound) {
		maxNumberOfVideoConnections = 6;
	} else if ([_devicePlatform rangeOfString:@"iPad2"].location != NSNotFound) {
		maxNumberOfVideoConnections = 1;
	} else if ([_devicePlatform rangeOfString:@"iPad3"].location != NSNotFound) {
		maxNumberOfVideoConnections = 3;
	} else if ([_devicePlatform rangeOfString:@"iPad4"].location != NSNotFound) {
		maxNumberOfVideoConnections = 6;
	} else if ([_devicePlatform rangeOfString:@"iPod4"].location != NSNotFound) {
		maxNumberOfVideoConnections = 0;
	} else if ([_devicePlatform rangeOfString:@"iPod5"].location != NSNotFound) {
		maxNumberOfVideoConnections = 2;
	}
	
	return maxNumberOfVideoConnections;
}


#pragma mark -

- (void)buddyHungUpNotification:(NSNotification *)notification
{
	NSString *from = [notification.userInfo objectForKey:ByeFromNotificationUserInfoKey];
	NSString *to = [notification.userInfo objectForKey:ByeToNotificationUserInfoKey];
	NSString *reason = [notification.userInfo objectForKey:ByeReasonNotificationUserInfoKey];
	
	if ([to isEqualToString:[UsersManager defaultManager].currentUser.sessionId]) {
		User *buddy = [[UsersManager defaultManager] userForSessionId:from];
		if (buddy) {
			
			ByeReason byeReason = kByeReasonNotSpecified;
			
			if (reason) {
				if ([reason isEqualToString:NSStr(kByeReasonNoAnswerString)]) {
					byeReason = kByeReasonNoAnswer;
				} else if ([reason isEqualToString:NSStr(kByeReasonBusyString)]) {
					byeReason = kByeReasonBusy;
				} else if ([reason isEqualToString:NSStr(kByeReasonRejectString)]) {
					byeReason = kByeReasonReject;
				} else if ([reason isEqualToString:NSStr(kByeReasonAbortString)]) {
					byeReason = kByeReasonAbort;
				} else {
					byeReason = kByeReasonNotSpecified;
				}
			}
			
			[self buddyHungUp:buddy withReason:byeReason];
		}
	}
}


#pragma mark -

- (void)stopVideo
{
	if (_screenSharingHandler) {
		_screenSharingHandler->DisableAllVideo();
	}
	
	_call->DisableAllVideo();
}


- (void)startVideo
{
	if (_screenSharingHandler) {
		_screenSharingHandler->EnableAllVideo();
	}
	
	_call->EnableAllVideo();
}


#pragma mark - Events handling (non call related)

- (void)sessionIdHasChanged:(NSString *)newSessionId
{
	if (self.inCall) {
		
		[self hangUpWithReason:kByeReasonNotSpecified
			  callFinishReason:kSMCallFinishReasonInternalError];
		
	} else {
		
		if (_call) {
			_call->Dispose();
		}
		_call = NULL;
		[self createCall];
	}
}


#pragma mark - Missed Call

- (void)newMissedCallFromUserSessionId:(NSString *)userSessionId
{
	MissedCall *missedCall = [[MissedCall alloc] init];
	missedCall.selfId = self.me.sessionId;
	User *buddyForMissedCall = [[UsersManager defaultManager] userForSessionId:userSessionId];
	
	// Buddy could have already dissapeared
	if (!buddyForMissedCall) {
		return;
	}
	
	missedCall.userSessionId = buddyForMissedCall.sessionId;
	missedCall.date = [NSDate date];
	missedCall.userName = buddyForMissedCall.displayName;
	[[UsersManager defaultManager] holdUser:buddyForMissedCall forSessionId:buddyForMissedCall.sessionId];
	[[MissedCallManager sharedInstance] addMissedCall:missedCall forUserSessionId:buddyForMissedCall.sessionId];
	[[UsersActivityController sharedInstance] addUserActivityToHistory:missedCall forUserSessionId:buddyForMissedCall.sessionId];
	
	
	if (self.userInterfaceCallbacksDelegate && [self.userInterfaceCallbacksDelegate respondsToSelector:@selector(newMissedCallFromUserSessionId:)]) {
		[self.userInterfaceCallbacksDelegate newMissedCallFromUserSessionId:buddyForMissedCall.sessionId];
	}
		
	UIApplication *app = [UIApplication sharedApplication];
	
	if (app.applicationState != UIApplicationStateActive) {
		
		if ([[_currentCallLocalNotification.userInfo objectForKey:NSStr(kIdKey)] isEqualToString:buddyForMissedCall.sessionId]) {
			[app cancelLocalNotification:_currentCallLocalNotification];
			_currentCallLocalNotification = nil;
		}
		
		[[STLocalNotificationManager sharedInstance] postLocalNotificationWithSoundName:UILocalNotificationDefaultSoundName
                                                                              alertBody:[NSString stringWithFormat:kSMLocalStringMissedCallFromLabelArg1, buddyForMissedCall.displayName]
																			alertAction:kSMLocalStringViewInTheAppButton];
	}
}


#pragma mark - Calling timer

- (void)startIOCallTimerAndCallDirectionIsIncoming:(BOOL)isIncoming withUserSessionId:(NSString *)userSessionId
{
	NSTimeInterval timeoutForOutgoingCall = 5.0 * 60.0; // 5 minutes
	NSTimeInterval timeoutForIncomingCall = 1.0 * 60.0; // 1 minute
	
	
	if (isIncoming) {
		[_incomingCallTimer invalidate];
		NSDictionary *userInfo = @{kCallTimerIncomingKey : @(isIncoming), kCallTimerUserSessionIdKey : userSessionId};
		_incomingCallTimer = [NSTimer scheduledTimerWithTimeInterval:timeoutForIncomingCall
															  target:self
															selector:@selector(waitingCallTimeElapsed:)
															userInfo:userInfo
															 repeats:NO];

	} else {
		[_outgoingCallTimer invalidate];
		NSDictionary *userInfo = @{kCallTimerIncomingKey : @(isIncoming), kCallTimerUserSessionIdKey : userSessionId};
		_outgoingCallTimer = [NSTimer scheduledTimerWithTimeInterval:timeoutForOutgoingCall
															  target:self
															selector:@selector(waitingCallTimeElapsed:)
															userInfo:userInfo
															 repeats:NO];
	}
}


- (void)stopOutgoingCallTimer
{
	[_outgoingCallTimer invalidate];
	_outgoingCallTimer = nil;
}


- (void)stopIncomingCallTimer
{
	[_incomingCallTimer invalidate];
	_incomingCallTimer = nil;
}


- (void)waitingCallTimeElapsed:(NSTimer *)theTimer
{
	BOOL isCallIncoming = [[theTimer.userInfo objectForKey:kCallTimerIncomingKey] boolValue];
	NSString *userSessionId = [theTimer.userInfo objectForKey:kCallTimerUserSessionIdKey];
	
	
	if (isCallIncoming) {
		/*
			Local user didn't pickup for given interval.
			Send noAnswer bye to remote user.
			Do NOT count missed call here since it will be counted in 'callIsFinished:'.
		 */
		[self hangUpWithReason:kByeReasonNoAnswer];
	} else {
		[self processNoAnswerFromUserSessionId:userSessionId]; // remote user does not respond, send abort and stop timer
	}
}


#pragma mark - Audio Interruption

- (void)appAudioInterruption:(NSNotification *)notification
{
	if ([notification.userInfo objectForKey:AVAudioSessionInterruptionTypeKey]) {
		NSNumber *type = [notification.userInfo objectForKey:AVAudioSessionInterruptionTypeKey];
		if ([type unsignedIntegerValue] == AVAudioSessionInterruptionTypeBegan) {
			_call->MuteAudio(true);
//			_peerConnectionWrapperFactory->AudioInterruptionStarted();
//			[[AVAudioSession sharedInstance] setActive:NO error:nil];
		} else if ([type unsignedIntegerValue] == AVAudioSessionInterruptionTypeEnded) {
//			[[AVAudioSession sharedInstance] setActive:YES error:nil];
			_call->MuteAudio(false);
//			_peerConnectionWrapperFactory->AudioInterruptionStopped();
		}
	}
}


#pragma mark - ScreenSharing

- (void)screensharingHasStarted:(NSNotification *)notification
{
	NSString *userSessionId = [notification.userInfo objectForKey:kScreenSharingUserSessionIdInfoKey];
	NSString *screensharingToken = [notification.userInfo objectForKey:kScreenSharingTokenInfoKey];
	
	// TODO: Maybe add some checks on RAM. We can probably safely rely on the next condition since device capabilities is reflected in 'calculateMaxNumberOfVideoConnections'.
	// Although on iPhone 5s with one video call and one screensharing video (2550x1440) app uses up to 200MB of RAM
//	int usersOnCall = _call->usersOnCallCount();
//	int maxVideoConnections = [self calculateMaxNumberOfVideoConnections];
//	if (usersOnCall >= maxVideoConnections) {
//		spreed_me_log("This device is not capable to add screensharing video due to performance limitations in current conditions. Users on call %d; max video connections = %d; device %s", usersOnCall, maxVideoConnections, [_devicePlatform cDescription]);
//		return;
//	}
	
	if ([userSessionId length] > 0 && [screensharingToken length] > 0) {
		[_screenSharingUsers setObject:screensharingToken forKey:userSessionId];
		_callingViewController.hasScreenSharingUsers = YES;
		[self updateUIWithScreenSharingFromUserSessionId:userSessionId];
	}
}


- (void)askForScreenFromUserSessionId:(NSString *)userSessionId screenSharingToken:(NSString *)screensharingToken
{
	if (!_screenSharingHandler) {
		ScreenSharingHandler *ref =  new rtc::RefCountedObject<ScreenSharingHandler>(_peerConnectionWrapperFactory,
			   [SMConnectionController sharedInstance].signallingHandler,
			   _screenSharingQueue,
			   _callbackMainQueue);
		_screenSharingHandler = rtc::scoped_refptr<ScreenSharingHandler>(ref);
		_screenSharingDelegate = new ScreenSharingHandlerDelegate(self);
		_screenSharingHandler->SetDelegate(_screenSharingDelegate);
		
		std::string userSessionId_cpp = stdStringFromNSString(userSessionId);
		std::string token_cpp = stdStringFromNSString(screensharingToken);
		_screenSharingHandler->EstablishConnection(token_cpp, userSessionId_cpp);
	} else {
		spreed_me_log("Screen sharing handler already exists!");
	}
}


- (void)updateUIWithScreenSharingFromUserSessionId:(NSString *)userSessionId
{
    [self.callingViewController userHasStartedScreensharing:userSessionId];
}


- (NSArray *)screenSharingUsers
{
	return [_screenSharingUsers allKeys];
}


- (void)connectToScreenSharingForUserSessionId:(NSString *)userSessionId
{
	NSString *token = [_screenSharingUsers objectForKey:userSessionId];
	if (token && userSessionId) {
		[self askForScreenFromUserSessionId:userSessionId screenSharingToken:token];
	}
}


- (void)stopRemoteScreenSharingForUserSessionId:(NSString *)userSessionId
{
	if (_screenSharingHandler) {

		BOOL shouldStopHandler = NO;
		
		if (_screenSharingRendererInfo) {
			if ([_screenSharingRendererInfo.userSessionId isEqualToString:userSessionId]) {
				// This is a correct handler for stoping
				shouldStopHandler = YES;
			} else {
				spreed_me_log("Screen sharing closing problem, trying to close incorrect handler");
			}
		} else {
			// There is no _screenSharingRendererInfo yet, so we assume we have started it but there is no connection yet
			shouldStopHandler = YES;
		}
		
		if (shouldStopHandler) {
			_screenSharingHandler->Stop();
			
			ScreenSharingHandlerAndDelegatesPackage package = ScreenSharingHandlerAndDelegatesPackage(_screenSharingHandler.release(), _screenSharingDelegate);
			_pendingScreenSharingHandlers.push_back(package);
			
			_screenSharingHandler = NULL;
			_screenSharingRendererInfo = nil;
		}
	} else {
		spreed_me_log("There is nothing to close for screen sharing");
	}
}


- (void)cleanUpScreenSharingHandlers
{
	[_screenSharingUsers removeAllObjects];
	_callingViewController.hasScreenSharingUsers = NO;
	
	if (_screenSharingHandler.get() != NULL) {
		
		_screenSharingHandler->Stop();
		
		ScreenSharingHandlerAndDelegatesPackage package = ScreenSharingHandlerAndDelegatesPackage(_screenSharingHandler.release(), _screenSharingDelegate);
		_pendingScreenSharingHandlers.push_back(package);
		
		_screenSharingRendererInfo = nil;
		_screenSharingHandler = NULL;
		_screenSharingDelegate = NULL;
	}
}


#pragma mark - VideoRenderers

- (NSString *)rendererNamePart
{
	NSString *namePart = [NSString stringWithFormat:@"%llu", _rendererNameNumber];
	if (_rendererNameNumber == 456456) {
		_rendererNameNumber = 0;
	} else {
		++_rendererNameNumber;
	}
	
	return namePart;
}


- (NSString *)rendererKeyForUserSessionId:(NSString *)userSessionId
							  streamLabel:(NSString *)streamLabel
							 videoTrackId:(NSString *)trackId
{
	NSString *key = nil;
	if (userSessionId.length > 0 &&
		streamLabel.length > 0 &&
		trackId.length > 0) {
	
		NSMutableString *temp = [NSMutableString new];
		[temp appendString:userSessionId];
		[temp appendString:streamLabel];
		[temp appendString:trackId];
		
		key = [temp copy];
	}
	
	return key;
}


// Saves videoRendererInfo into dictionary with key userSessionId+streamLabel+videoTrackId+rendererName
- (void)saveVideoRenderer:(VideoRendereriOSInfo *)rendererInfo
{
	NSString *key = [self rendererKeyForUserSessionId:rendererInfo.userSessionId
										  streamLabel:rendererInfo.streamLabel
										 videoTrackId:rendererInfo.videoTrackId];
	
	if (key.length > 0) {
		
		NSMutableDictionary *renderers = [_callRenderers objectForKey:key];
		if (!renderers) {
			renderers = [NSMutableDictionary new];
		}
		[renderers setObject:rendererInfo forKey:rendererInfo.rendererName];
		[_callRenderers setObject:renderers forKey:key];
	} else {
		NSAssert(NO, @"renderer or trackId or streamLabel is nil");
	}
}


// VideoRendereriOSInfo *rendererInfo is used only as a package of arguments here
- (VideoRendereriOSInfo *)videoRendererForVideoRenderer:(VideoRendereriOSInfo *)rendererInfo
{
	return [self videoRendererForUserSessionId:rendererInfo.userSessionId
								   streamLabel:rendererInfo.streamLabel
								  videoTrackId:rendererInfo.videoTrackId
								  rendererName:rendererInfo.rendererName];
}


- (VideoRendereriOSInfo *)videoRendererForUserSessionId:(NSString *)userSessionId
											streamLabel:(NSString *)streamLabel
										   videoTrackId:(NSString *)videoTrackId
										   rendererName:(NSString *)rendererName
{
	VideoRendereriOSInfo *rendererInfo = nil;
	
	
	NSString *key = [self rendererKeyForUserSessionId:userSessionId
										  streamLabel:streamLabel
										 videoTrackId:videoTrackId];
	
	if (key.length > 0) {
		NSMutableDictionary *renderers = [_callRenderers objectForKey:key];
		if (renderers) {
			rendererInfo = [renderers objectForKey:rendererName];
		}
	}
	
	return rendererInfo;
}


- (NSArray *)videoRenderersForUserSessionId:(NSString *)userSessionId
								streamLabel:(NSString *)streamLabel
							   videoTrackId:(NSString *)videoTrackId

{
	NSArray *renderers = nil;
	
	
	NSString *key = [self rendererKeyForUserSessionId:userSessionId
										  streamLabel:streamLabel
										 videoTrackId:videoTrackId];
	
	if (key.length > 0) {
		NSMutableDictionary *renderersDict = [_callRenderers objectForKey:key];
		if (renderersDict) {
			renderers = [renderersDict allValues];
		}
	}
	
	return renderers;
}


- (void)deleteVideoRenderer:(VideoRendereriOSInfo *)rendererInfo
{
	NSString *key = [self rendererKeyForUserSessionId:rendererInfo.userSessionId
										  streamLabel:rendererInfo.streamLabel
										 videoTrackId:rendererInfo.videoTrackId];
	
	if (key.length > 0) {
		NSMutableDictionary *renderers = [_callRenderers objectForKey:key];
		if (renderers) {
			[renderers removeObjectForKey:rendererInfo.rendererName];
			if (renderers.count == 0) {
				[_callRenderers removeObjectForKey:key];
			}
		}
	} else {
		NSAssert(NO, @"renderer or trackId or streamLabel is nil");
	}
}


- (NSArray *)allVideoRenderers
{
	NSMutableArray *array = [NSMutableArray new];
	
	NSArray *tempArray = [_callRenderers allValues];
	
	for (NSMutableDictionary *renderers in tempArray) {
		[array addObjectsFromArray:[renderers allValues]];
	}
	
	NSArray *returnArray = nil;
	if ([array count]) {
		returnArray = [NSArray arrayWithArray:array];
	}
	
	return returnArray;
}


- (void)removeAllVideoRenderers
{
	_haveLocalRenderer = NO;
	[_callRenderers removeAllObjects];
}


#pragma mark - CallDelegate

// CallDelegate methods
- (void)firstOutgoingCallStarted:(Call *)call withUserSessionId:(NSString *)userSessionId withVideo:(BOOL)withVideo
{
	if (_call == call) {
	
		if (!_appStateNotificationSubscribed) {
			_appStateNotificationSubscribed = YES;
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(proximitySensorStateChanged:) name:UIDeviceProximityStateDidChangeNotification object:nil];
		}
		
		[self createAndSetupCallingViewController];
		[[UserInterfaceManager sharedInstance] presentModalCallingViewController:self.callingViewController];
		
		if ([self.userInterfaceCallbacksDelegate respondsToSelector:@selector(firstOutgoingCallStartedWithUserSessionId:withVideo:)]) {
            [self.userInterfaceCallbacksDelegate firstOutgoingCallStartedWithUserSessionId:userSessionId withVideo:withVideo];
        }
        
		[self startIOCallTimerAndCallDirectionIsIncoming:NO withUserSessionId:userSessionId];
		[self appIsInCall:YES];
	} else {
		spreed_me_log("Warning. First outgoing call from not current _call.");
	}
}


- (void)outgoingCallStarted:(Call *)call withUserSessionId:(NSString *)userSessionId
{
	if (_call == call) {
		if ([self.userInterfaceCallbacksDelegate respondsToSelector:@selector(outgoingCallStartedWithUserSessionId:)]) {
			[self.userInterfaceCallbacksDelegate outgoingCallStartedWithUserSessionId:userSessionId];
		}
	} else {
		spreed_me_log("Warning. Outgoing call from not current _call.");
	}
}


- (void)firstIncomingCallReceived:(Call *)call withUserSessionId:(NSString *)userSessionId
{
	if (_call == call) {
		if (!_appStateNotificationSubscribed) {
			_appStateNotificationSubscribed = YES;
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(proximitySensorStateChanged:) name:UIDeviceProximityStateDidChangeNotification object:nil];
		}
		
		[self createAndSetupCallingViewController];
		[[UserInterfaceManager sharedInstance] presentModalCallingViewController:self.callingViewController];
		
		if ([self.userInterfaceCallbacksDelegate respondsToSelector:@selector(firstIncomingCallReceivedWithUserSessionId:)]) {
			[self.userInterfaceCallbacksDelegate firstIncomingCallReceivedWithUserSessionId:userSessionId];
		}
		
		User *buddy = [[UsersManager defaultManager] userForSessionId:userSessionId];
		UIApplication *app = [UIApplication sharedApplication];
		
		if (app.applicationState != UIApplicationStateActive) {
			UILocalNotification *callNotification = [[STLocalNotificationManager sharedInstance] createLocalNotificationWithSoundName:@"29_sec_whistle.caf"
                                                                                                                            alertBody:[NSString stringWithFormat:kSMLocalStringIsCallingYouArg1, buddy.displayName]
                                                                                                                          alertAction:kSMLocalStringViewInTheAppButton];
            // User can disable local notification in settings so user might not see this notification.
            if (callNotification) {
                callNotification.userInfo = @{ NSStr(kIdKey) : userSessionId};
                _currentCallLocalNotification = callNotification;
                [app presentLocalNotificationNow:callNotification];
            }
			
		}
		
		[self startIOCallTimerAndCallDirectionIsIncoming:YES withUserSessionId:userSessionId];
		[self appIsInCall:YES];
		
		self.firstIncomingCallUserSessionId = userSessionId;
	} else {
		spreed_me_log("Warning. First incoming call from not current _call.");
	}
}


- (void)incomingCallReceived:(Call *)call withUserSessionId:(NSString *)userSessionId
{
	if (_call == call) {
		if ([self.userInterfaceCallbacksDelegate respondsToSelector:@selector(incomingCallReceivedWithUserSessionId:)]) {
			[self.userInterfaceCallbacksDelegate incomingCallReceivedWithUserSessionId:userSessionId];
		}
	} else {
		spreed_me_log("Warning. Incoming call from not current _call.");
	}
}


- (void)callConnectionEstablished:(Call *)call withUserSessionId:(NSString *)userSessionId
{
	if (_call == call) {
		if (self.userInterfaceCallbacksDelegate && [self.userInterfaceCallbacksDelegate respondsToSelector:@selector(callConnectionEstablishedWithUserSessionId:)]) {
			[self.userInterfaceCallbacksDelegate callConnectionEstablishedWithUserSessionId:userSessionId];
		}
		
		[self stopOutgoingCallTimer];
		[self stopIncomingCallTimer];
		
		if ([userSessionId isEqualToString:self.firstIncomingCallUserSessionId]) {
			self.firstIncomingCallUserSessionId = nil;
		}
	} else {
		spreed_me_log("Warning. Call connection established from not current _call.");
	}
}


- (void)callConnectionLost:(Call *)call withUserSessionId:(NSString *)userSessionId
{
	if (_call == call) {
		if (self.userInterfaceCallbacksDelegate && [self.userInterfaceCallbacksDelegate respondsToSelector:@selector(callConnectionLostWithUserSessionId:)]) {
			[self.userInterfaceCallbacksDelegate callConnectionLostWithUserSessionId:userSessionId];
		}
	} else {
		spreed_me_log("Warning. Call connection lost from not current _call.");
	}
}


- (void)callConnectionFailed:(Call *)call withUserSessionId:(NSString *)userSessionId
{
	if (_call == call) {
		if (self.userInterfaceCallbacksDelegate && [self.userInterfaceCallbacksDelegate respondsToSelector:@selector(callConnectionFailedWithUserSessionId:)]) {
			[self.userInterfaceCallbacksDelegate callConnectionFailedWithUserSessionId:userSessionId];
		}
	} else {
		spreed_me_log("Warning. Call connection failed from not current _call.");
	}
}


- (void)callHasStarted:(spreedme::Call *)call
{
	if (_call == call) {
		if (_call->HasVideo()) {
			_call->SetLoudspeakerStatus(true);
		}
	} else {
		spreed_me_log("Warning. Call has started from not current _call.");
	}
}


- (void)remoteUserHangUp:(NSString *)userSessionId inCall:(Call *)call
{
	if (_call == call) {
		NSArray *renderers = [self allVideoRenderers];
		NSMutableArray *renderersForUser = [NSMutableArray array];
		for (VideoRendereriOSInfo *renderer in renderers) {
			if ([renderer.userSessionId isEqualToString:userSessionId]) {
				[renderersForUser addObject:renderer];
			}
		}
		
		for (VideoRendereriOSInfo *renderer in renderersForUser) {
			[self deleteVideoRenderer:renderer];
		}
		
		if (self.userInterfaceCallbacksDelegate && [self.userInterfaceCallbacksDelegate respondsToSelector:@selector(remoteUserHungUp:)]) {
			[self.userInterfaceCallbacksDelegate remoteUserHungUp:userSessionId];
		}
		
		if ([self.firstIncomingCallUserSessionId isEqualToString:userSessionId]) {
			[self newMissedCallFromUserSessionId:userSessionId];
			self.firstIncomingCallUserSessionId = nil;
		}
		
		[_screenSharingUsers removeObjectForKey:userSessionId];
		if ([_screenSharingUsers count] == 0) {
			_callingViewController.hasScreenSharingUsers = NO;
		}
		
		NSDictionary *userInfo = @{kUserSessionIdKey : userSessionId};
		[[NSNotificationCenter defaultCenter] postNotificationName:UserHasLeftCallNotification object:self userInfo:userInfo];
	} else {
		spreed_me_log("Warning. Remote user hang up from not current _call.");
	}
}


- (void)callIsFinished:(Call *)call callFinishReason:(SMCallFinishReason)finishReason
{
	if (_call == call) {
		// Remote user hung up
		
		_call->RequestStatistics();
		
		// TODO: WARNING: refactor this since call to delete call will probably
		// erase messages to remove renderers from signalling_thread message queue.
		// We didn't spot problems with that so far but this should be refactored.
		[self cleanUpScreenSharingHandlers];
		[self removeAllVideoRenderers];
		
		CallAndDelegatesPackage package(_call, _callDelegate);
		package.hasRequestedStatistics = true;
		[SMConnectionController sharedInstance].signallingHandler->UnRegisterMessageReceiver(_call);
		[SMConnectionController sharedInstance].signallingHandler->SetWrapperProvider(NULL);
		_pendingHungUpCalls.push_back(package);
		
		_call = NULL;
		_callDelegate =  NULL;
		
		[self cleanUpAfterCallWithCallFinishReason:finishReason];
	} else {
		for (std::vector<spreedme::CallAndDelegatesPackage>::iterator it = _pendingHungUpCalls.begin();
			 it != _pendingHungUpCalls.end();) {
			
			// Warning: we do not check here for duplicate insertions of the CallAndDelegatesPackage with the same call
			if (it->call == call && !it->hasRequestedStatistics) {
				call->RequestStatistics();
				break;
			}
			++it;
		}
	}
}


- (void)incomingCallWasAutoRejected:(Call *)call withUserSessionId:(NSString *)userSessionId
{
	if (_call == call) {
		[self newMissedCallFromUserSessionId:userSessionId];
	} else {
		spreed_me_log("Warning. Incoming call was autorejected from not current _call.");
	}
}


- (void)callLocalStreamHasBeenAdded:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId streamLabel:(NSString *)streamLabel videoTracksIds:(NSArray *)videoTracksIds
{
	if (_call == call) {
		if ([userSessionId length] > 0 && [streamLabel length] > 0 && [videoTracksIds count] > 0 && !_haveLocalRenderer) {
			if (self.userInterfaceCallbacksDelegate && [self.userInterfaceCallbacksDelegate respondsToSelector:@selector(localVideoRenderViewWasCreated:forTrackId:inStreamWithLabel:)]) {
				
				// This implementation depends on quantity of video tracks in stream and/or on their sequence
				// We assume that we always have only one video track. If this changes this code should be refactored.
				
				NSString *trackId = [videoTracksIds objectAtIndex:0]; //we can do this since we have checked that trackId array is not empty
				NSArray *renderers = [self videoRenderersForUserSessionId:userSessionId
															  streamLabel:streamLabel
															 videoTrackId:trackId];
				if (renderers.count == 0) {
					
					// Request new renderer only if we didn't do that already
					std::string userSessionId_cpp = stdStringFromNSString(userSessionId);
					std::string streamLabel_cpp = stdStringFromNSString(streamLabel);
					std::string trackId_cpp = stdStringFromNSString(trackId);
					std::string rendererName = "Local";
					_haveLocalRenderer = YES;
					
					call->RequestToSetupVideoRenderer(userSessionId_cpp, streamLabel_cpp, trackId_cpp, rendererName);
					
					VideoRendereriOSInfo *rendererInfo = [[VideoRendereriOSInfo alloc] init];
					
					rendererInfo.userSessionId = userSessionId;
					rendererInfo.streamLabel = streamLabel;
					rendererInfo.videoTrackId = trackId;
					rendererInfo.rendererName = NSStr(rendererName.c_str());
					rendererInfo.isLocal = YES;
					
					[self saveVideoRenderer:rendererInfo];
				}
			}
		} else {
			spreed_me_log("We may already have local render, or no userSessionId or no streamLabel or no videotracks");
		}
	} else {
		spreed_me_log("Warning. CallLocalStreamHasBeenAdded from not current _call.");
	}
}


- (void)callLocalStreamHasBeenRemoved:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId streamLabel:(NSString *)streamLabel videoTracksIds:(NSArray *)videoTracksIds
{
	if (_call == call) {
		spreed_me_log("Call local stream (%s) has been removed with tracks: %s", [streamLabel cDescription], [videoTracksIds cDescription]);
	} else {
		spreed_me_log("Warning. callLocalStreamHasBeenRemoved from not current _call.");
	}
}


- (void)callRemoteStreamHasBeenAdded:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId streamLabel:(NSString *)streamLabel videoTracksIds:(NSArray *)videoTracksIds
{
	if (_call == call) {
		if ([userSessionId length] > 0 && [streamLabel length] > 0 && [videoTracksIds count] > 0) {
			
			if (self.userInterfaceCallbacksDelegate &&
				[self.userInterfaceCallbacksDelegate respondsToSelector:@selector(remoteVideoRenderView:wasCreatedForUserSessionId:forTrackId:inStreamWithLabel:)]) {
			
				// This implementation depends on quantity of video tracks in stream and/or on their sequence
				// We assume that we always have only one video track. If this changes this code should be refactored.
				
				NSString *trackId = [videoTracksIds objectAtIndex:0]; //we can do this since we have checked that trackId array is not empty
				NSArray *renderers = [self videoRenderersForUserSessionId:userSessionId
															  streamLabel:streamLabel
															 videoTrackId:trackId];
				if (renderers.count == 0) {
					
					// Request new renderer only if we didn't do that already
					std::string userSessionId_cpp = stdStringFromNSString(userSessionId);
					std::string streamLabel_cpp = stdStringFromNSString(streamLabel);
					std::string trackId_cpp = stdStringFromNSString(trackId);
					std::string rendererName = "Remote_" + stdStringFromNSString([self rendererNamePart]) + "_" + trackId_cpp;
					
					call->RequestToSetupVideoRenderer(userSessionId_cpp, streamLabel_cpp, trackId_cpp, rendererName);
					
					VideoRendereriOSInfo *rendererInfo = [[VideoRendereriOSInfo alloc] init];
					
					rendererInfo.userSessionId = userSessionId;
					rendererInfo.streamLabel = streamLabel;
					rendererInfo.videoTrackId = trackId;
					rendererInfo.rendererName = NSStr(rendererName.c_str());
					rendererInfo.isLocal = NO;
					
					[self saveVideoRenderer:rendererInfo];
				}
			}
		}
	} else {
		spreed_me_log("Warning. callRemoteStreamHasBeenAdded from not current _call.");
	}
}


- (void)callRemoteStreamHasBeenRemoved:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId streamLabel:(NSString *)streamLabel videoTracksIds:(NSArray *)videoTracksIds
{
	if (_call == call) {
		spreed_me_log("Call with userSessionID (%s) remote stream (%s) has been removed with tracks: %s", [userSessionId cDescription], [streamLabel cDescription], [videoTracksIds cDescription]);
	} else {
		spreed_me_log("Warning. callRemoteStreamHasBeenRemoved from not current _call.");
	}
}


- (void)callHasEncounteredAnError:(spreedme::Call *)call error:(NSError *)error
{
	if (_call == call) {
		spreed_me_log("Call has encountered an error %@", error);
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"message_title_call-failed",
																								  nil, [NSBundle mainBundle],
																								  @"Call has failed",
																								  @"Call has failed. This only can happen in rare ocasions and usually doesn't have any additional info.")
														message:NSLocalizedStringWithDefaultValue(@"message_body_call-failed",
																								  nil, [NSBundle mainBundle],
																								  @"Call connection has encountered unknown problems. Please try again.",
																								  @"Call connection has encountered unknown problems. Please try again. This only can happen in rare ocasions and usually doesn't have any additional info.")
													   delegate:nil
											  cancelButtonTitle:kSMLocalStringSadOKButton
											  otherButtonTitles:nil];
		
		[alert show];
		
		[self hangUpWithReason:kByeReasonNotSpecified
			  callFinishReason:kSMCallFinishReasonInternalError];
	} else {
		spreed_me_log("Warning. callHasEncounteredAnError from not current _call.");
	}
}


- (void)videoRendererWasCreatedIn:(spreedme::Call *)call info:(VideoRendereriOSInfo *)info
{
	
	// Although info is of type VideoRendereriOSInfo* it doesn't mean it should be the same instance as
	// our previously saved rendererInfo.
	
	VideoRendereriOSInfo *rendererInfo = [self videoRendererForVideoRenderer:info];

	if (rendererInfo) {
		rendererInfo.userSessionId = info.userSessionId;
		rendererInfo.streamLabel = info.streamLabel;
		rendererInfo.videoTrackId = info.videoTrackId;
		rendererInfo.outputView = info.outputView;
		
		[self saveVideoRenderer:rendererInfo];
		
		
		if (rendererInfo.isLocal) {
			[self.userInterfaceCallbacksDelegate localVideoRenderViewWasCreated:rendererInfo.outputView
																	 forTrackId:rendererInfo.videoTrackId
															  inStreamWithLabel:rendererInfo.streamLabel];
		} else {
			[self.userInterfaceCallbacksDelegate remoteVideoRenderView:rendererInfo.outputView
											wasCreatedForUserSessionId:rendererInfo.userSessionId
															forTrackId:rendererInfo.videoTrackId
													 inStreamWithLabel:rendererInfo.streamLabel];
		}
		
	} else {
		spreed_me_log("Unknown renderer was setup!");
	}
}


- (void)videoRendererHasSetFrameIn:(spreedme::Call *)call
							  info:(VideoRendereriOSInfo *)info
{
	VideoRendereriOSInfo *rendererInfo = [self videoRendererForVideoRenderer:info];
	
	if (rendererInfo) {
		rendererInfo.frameSize = info.frameSize;
		if (rendererInfo != _screenSharingRendererInfo) {
		
			if (rendererInfo.isLocal) {
				[self.userInterfaceCallbacksDelegate localVideoRenderView:rendererInfo.outputView
															   forTrackId:rendererInfo.videoTrackId
														inStreamWithLabel:rendererInfo.streamLabel
														  hasSetFrameSize:rendererInfo.frameSize];
			} else {
				[self.userInterfaceCallbacksDelegate remoteVideoRenderView:rendererInfo.outputView
														  forUserSessionId:rendererInfo.userSessionId
																forTrackId:rendererInfo.videoTrackId
														 inStreamWithLabel:rendererInfo.streamLabel
														   hasSetFrameSize:rendererInfo.frameSize];
			}
			
		} else {
			[self.userInterfaceCallbacksDelegate screenSharingVideoRenderView:rendererInfo.outputView
															 forUserSessionId:rendererInfo.userSessionId
																   forTrackId:rendererInfo.videoTrackId
															inStreamWithLabel:rendererInfo.streamLabel
															  hasSetFrameSize:rendererInfo.frameSize];
		}
		
	} else {
		spreed_me_log("Unknown has received new frame size!");
	}
}


- (void)videoRendererWasDeletedIn:(spreedme::Call *)call
							 info:(VideoRendereriOSInfo *)info
{
	spreed_me_log("Deleted video renderer");
}


- (void)failedToSetupVideoRendererIn:(spreedme::Call *)call
								info:(VideoRendereriOSInfo *)info
							   error:(spreedme::VideoRendererManagementError)error
{
	VideoRendereriOSInfo *rendererInfo = [self videoRendererForVideoRenderer:info];
	
	if (rendererInfo) {
		if (rendererInfo.isLocal) {
			_haveLocalRenderer = NO;
		}
		
		[self deleteVideoRenderer:rendererInfo];
	}
	
	spreed_me_log("Failed to setup video renderer: %d", error);
}


- (void)failedToDeleteVideoRendererIn:(spreedme::Call *)call
								 info:(VideoRendereriOSInfo *)info
								error:(spreedme::VideoRendererManagementError)error
{
	VideoRendereriOSInfo *rendererInfo = [self videoRendererForVideoRenderer:info];
	
	if (rendererInfo) {
		[self deleteVideoRenderer:rendererInfo];
	}
	
	spreed_me_log("Failed to delete video renderer: %d", error);
}


- (void)callHasReceivedStatistics:(spreedme::Call *)call
							stats:(webrtc::StatsReports)reports;
{
	for (std::vector<spreedme::CallAndDelegatesPackage>::iterator it = _pendingHungUpCalls.begin();
		 it != _pendingHungUpCalls.end();) {
		
		// Warning: we do not check here for duplicate insertions of the CallAndDelegatesPackage with the same call
		if (it->call == call) {
			
			it->DeleteAll();
			_pendingHungUpCalls.erase(it);
			
			for (webrtc::StatsReports::iterator it_rep = reports.begin(); it_rep != reports.end(); ++it_rep) {
				if ((*it_rep)->type() == webrtc::StatsReport::kStatsReportTypeSsrc) {
                    
                    const webrtc::StatsReport::Value *valueRec = (*it_rep)->FindValue(webrtc::StatsReport::kStatsValueNameBytesReceived);
                    if (valueRec) {
                        uint64_t result = 0;
                        std::stringstream convert(valueRec->value);
                        if ( !(convert >> result) ) { result = 0; }
                        
                        [[SMConnectionController sharedInstance].ndController addReceivedBytes:result forServiceName:SMWebRTCServiceNameForStatistics];
                    }
                    const webrtc::StatsReport::Value *valueSent = (*it_rep)->FindValue(webrtc::StatsReport::kStatsValueNameBytesSent);
                    if (valueSent) {
                        uint64_t result = 0;
                        std::stringstream convert(valueSent->value);
                        if ( !(convert >> result) ) { result = 0; }
                        
                        [[SMConnectionController sharedInstance].ndController addSentBytes:result forServiceName:SMWebRTCServiceNameForStatistics];
                    }
				}
			}
			
			break;
		} else {
			++it;
		}
	}
}


#pragma mark - ScreenSharingUIDelegate methods

- (void)screenSharingHasStarted:(spreedme::ScreenSharingHandler *)handler
					  withToken:(NSString *)token
			  withUserSessionId:(NSString *)userSessionId
					   withView:(void *)renderView
				   rendererName:(NSString *)rendererName
{
	if (self.userInterfaceCallbacksDelegate && [self.userInterfaceCallbacksDelegate respondsToSelector:@selector(screenSharingVideoRenderView:wasCreatedForUserSessionId:forTrackId:inStreamWithLabel:)]) {
		
		if (_screenSharingHandler == handler) {
		
			if (!_screenSharingRendererInfo) {
				_screenSharingRendererInfo = [[VideoRendereriOSInfo alloc] init];
				_screenSharingRendererInfo.userSessionId = userSessionId;
				_screenSharingRendererInfo.streamLabel = @"ScreenSharingStream";
				_screenSharingRendererInfo.videoTrackId = @"ScreenSharingVideoTrack";
				_screenSharingRendererInfo.rendererName = rendererName;
				_screenSharingRendererInfo.isLocal = NO;
				_screenSharingRendererInfo.outputView = (__bridge UIView *)renderView;
				
				[self.userInterfaceCallbacksDelegate screenSharingVideoRenderView:_screenSharingRendererInfo.outputView
													   wasCreatedForUserSessionId:_screenSharingRendererInfo.userSessionId
																	   forTrackId:_screenSharingRendererInfo.videoTrackId
																inStreamWithLabel:_screenSharingRendererInfo.streamLabel];
			} else {
				spreed_me_log("Warning: There is already _screenSharingRendererInfo!");
			}
		} else {
			spreed_me_log("ScreenSharing has started for unexpected screenShatingHandler");
		}
	}
}


- (void)screenSharingHasStopped:(spreedme::ScreenSharingHandler *)handler
					  withToken:(NSString *)token
			  withUserSessionId:(NSString *)userSessionId
{
	if (_screenSharingHandler == handler) {
	
		spreed_me_log("screenSharing connection closed with user %s", [userSessionId cDescription]);
		[_screenSharingUsers removeObjectForKey:userSessionId];
		if ([_screenSharingUsers count] == 0) {
			_callingViewController.hasScreenSharingUsers = NO;
		}
		
		ScreenSharingHandlerAndDelegatesPackage package = ScreenSharingHandlerAndDelegatesPackage(_screenSharingHandler.release(), _screenSharingDelegate);
		_pendingScreenSharingHandlers.push_back(package);
		
		_screenSharingRendererInfo = nil;
		_screenSharingHandler = NULL;
		
		if ([self.userInterfaceCallbacksDelegate respondsToSelector:@selector(screenSharingHasBeenStoppedByRemoteUser:)]) {
			[self.userInterfaceCallbacksDelegate screenSharingHasBeenStoppedByRemoteUser:userSessionId];
		}
	} else {
		
		// One of the possibilities to receive this delegate call from not the current handler is when remote user
		// whose screen we watch has hung up. Then we will receive it twice from the same handler.
		// First time from "bye" message in screensharing and the second time when the screensharing connection is closed. 
		spreed_me_log("We received screenSharingHasStopped from not current handler");
	}
}


- (void)screenSharingHasChangedFrameSize:(spreedme::ScreenSharingHandler *)handler
							   withToken:(NSString *)token
					   withUserSessionId:(NSString *)userSessionId
							rendererName:(NSString *)rendererName
							   frameSize:(CGSize)frameSize
{
	if (_screenSharingHandler == handler) {
		if (self.userInterfaceCallbacksDelegate &&
			[self.userInterfaceCallbacksDelegate respondsToSelector:@selector(screenSharingVideoRenderView:forUserSessionId:forTrackId:inStreamWithLabel:hasSetFrameSize:)])
		{
			[self.userInterfaceCallbacksDelegate screenSharingVideoRenderView:_screenSharingRendererInfo.outputView
															 forUserSessionId:_screenSharingRendererInfo.userSessionId
																   forTrackId:_screenSharingRendererInfo.videoTrackId
															inStreamWithLabel:_screenSharingRendererInfo.streamLabel
															  hasSetFrameSize:frameSize];
		}
	} else {
		spreed_me_log("We received screenSharingHasChangedFrameSize from not current handler");
	}
}


- (void)screenSharingConnectionEstablished:(spreedme::ScreenSharingHandler *)handler
								 withToken:(NSString *)token
						 withUserSessionId:(NSString *)userSessionId
{
	spreed_me_log("screenSharing connection established with user %s", [userSessionId cDescription]);
}


- (void)screenSharingConnectionLost:(spreedme::ScreenSharingHandler *)handler
						  withToken:(NSString *)token
				  withUserSessionId:(NSString *)userSessionId
{
	spreed_me_log("screenSharing connection lost with user %s", [userSessionId cDescription]);
}


- (void)screenSharingHandlerHasBeenClosed:(spreedme::ScreenSharingHandler *)handler
								withToken:(NSString *)token
						withUserSessionId:(NSString *)userSessionId
									stats:(webrtc::StatsReports)reports
{
	for (std::vector<spreedme::ScreenSharingHandlerAndDelegatesPackage>::iterator it = _pendingScreenSharingHandlers.begin();
		 it != _pendingScreenSharingHandlers.end();) {
		
		// Warning: we do not check here for duplicate insertions of the CallAndDelegatesPackage with the same call
		if (it->handler == handler) {
			
			it->DeleteAll();
			_pendingScreenSharingHandlers.erase(it);
			
			for (webrtc::StatsReports::iterator it_rep = reports.begin(); it_rep != reports.end(); ++it_rep) {
				if ((*it_rep)->type() == webrtc::StatsReport::kStatsReportTypeSsrc) {
                    
                    const webrtc::StatsReport::Value *valueRec = (*it_rep)->FindValue(webrtc::StatsReport::kStatsValueNameBytesReceived);
                    if (valueRec) {
                        uint64_t result = 0;
                        std::stringstream convert(valueRec->value);
                        if ( !(convert >> result) ) { result = 0; }
                        
                        [[SMConnectionController sharedInstance].ndController addReceivedBytes:result forServiceName:SMWebRTCServiceNameForStatistics];
                    }
                    const webrtc::StatsReport::Value *valueSent = (*it_rep)->FindValue(webrtc::StatsReport::kStatsValueNameBytesSent);
                    if (valueSent) {
                        uint64_t result = 0;
                        std::stringstream convert(valueSent->value);
                        if ( !(convert >> result) ) { result = 0; }
                        
                        [[SMConnectionController sharedInstance].ndController addSentBytes:result forServiceName:SMWebRTCServiceNameForStatistics];
                    }
				}
			}
			
			break;
		} else {
			++it;
		}
	}
	
	if (_screenSharingHandler == handler) {
		spreed_me_log("Current _screenSharingHandler has been closed. This is probably because of racing conditions!");
	}
}


#pragma mark - CallObserverInterface methods

- (void)tokenDataChannelOpened:(Call *)call userSessionId:(NSString *)userSessionId wrapperId:(NSString *)wrapperId
{
	spreed_me_log("tokenDataChannelOpened");
}


- (void)tokenDataChannelClosed:(Call *)call userSessionId:(NSString *)userSessionId wrapperId:(NSString *)wrapperId
{
	spreed_me_log("tokenDataChannelClosed");
}


#pragma mark - CallingViewControllerUserActions delegate methods

- (void)userHangUpInCallingViewController:(CallingViewController *)callingVC
{
	[[PeerConnectionController sharedInstance] hangUpWithReason:kByeReasonNotSpecified
											   callFinishReason:kSMCallFinishReasonLocalHangUp];
}


- (void)userCanceledOutgoingCall:(CallingViewController *)callingVC
{
	[[PeerConnectionController sharedInstance] hangUpWithReason:kByeReasonAbort
											   callFinishReason:kSMCallFinishReasonLocalHangUp];
}


- (void)callingViewController:(CallingViewController *)callingVC userAcceptedIncomingCall:(User *)from withVideo:(BOOL)withVideo
{
    [[PeerConnectionController sharedInstance] acceptIncomingCall:from withVideo:withVideo];
}


- (void)callingViewController:(CallingViewController *)callingVC userRejectedIncomingCall:(User *)from
{
	[[PeerConnectionController sharedInstance] hangUpWithReason:kByeReasonReject
											   callFinishReason:kSMCallFinishReasonLocalHangUp];
}


- (void)callingViewController:(CallingViewController *)callingVC userAddedBuddyToCall:(User *)user withVideo:(BOOL)withVideo
{
	[self addUserToCall:user withVideo:withVideo];
}


- (void)callingViewController:(CallingViewController *)callingVC userSetSoundMuted:(BOOL)muted
{
	[[PeerConnectionController sharedInstance] muteAudio:muted];
}


- (void)callingViewController:(CallingViewController *)callingVC userSetVideoMuted:(BOOL)muted
{
	[[PeerConnectionController sharedInstance] muteVideo:muted];
}


#pragma mark - CallingViewControllerInternals Delegate methods

- (void)callingViewController:(CallingViewController *)callingVC setAllVideoMuted:(BOOL)muted
{
}


#pragma mark - Video device capabilities

- (NSArray *)videoDeviceCapabilitiesForDevice:(SMVideoDevice *)device
{
	NSArray *capabilities_objc = nil;
	
	if (device) {
		std::vector<webrtc::VideoCaptureCapability> capabilities = _peerConnectionWrapperFactory->GetVideoDeviceCaptureCapabilities(stdStringFromNSString(device.deviceId));
		if (capabilities.size()) {
			NSMutableArray *mutableCapabilities_objc = [NSMutableArray array];
			for (std::vector<webrtc::VideoCaptureCapability>::iterator it = capabilities.begin(); it != capabilities.end(); ++it) {
				SMVideoDeviceCapability *capability = [[SMVideoDeviceCapability alloc] init];
				capability.videoFrameWidth = it->width;
				capability.videoFrameHeight = it->height;
				capability.maxFPS = it->maxFPS;
				[mutableCapabilities_objc addObject:capability];
			}
			capabilities_objc = [NSArray arrayWithArray:mutableCapabilities_objc];
		}
	}
	
	return capabilities_objc;
}


- (NSArray *)videoDevices
{
	NSMutableArray *array = [NSMutableArray array];
	
	STDStringVector ids = _peerConnectionWrapperFactory->videoDeviceUniqueIDs();
	
	for (STDStringVector::iterator it = ids.begin(); it != ids.end(); ++it) {
		SMVideoDevice *videoDevice = [[SMVideoDevice alloc] init];
		videoDevice.deviceId = NSStr(it->c_str());
		videoDevice.deviceLocalizedName = NSStr((_peerConnectionWrapperFactory->GetLocalizedNameOfVideoDevice(*it)).c_str());
		[array addObject:videoDevice];
	}
	
	return [NSArray arrayWithArray:array];
}


@end
