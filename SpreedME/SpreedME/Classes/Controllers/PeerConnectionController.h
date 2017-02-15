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

#import <Foundation/Foundation.h>

#import "ChannelingManager.h"
#import "SMConnectionController.h"
#import "SMVideoDevice.h"


extern NSString * const CallIsFinishedNotification;

extern NSString * const UserHasLeftCallNotification;
extern NSString * const kUserSessionIdKey; 


typedef enum : NSInteger {
    kSMCallFinishReasonUnspecified = 0,
	kSMCallFinishReasonLocalHangUp,
	kSMCallFinishReasonRemoteHungUp,
    kSMCallFinishReasonInternalError,
} SMCallFinishReason;


@class User;

@protocol UserIntefaceCallbacks <NSObject>
@required
- (void)firstOutgoingCallStartedWithUserSessionId:(NSString *)userSessionId withVideo:(BOOL)video;
- (void)outgoingCallStartedWithUserSessionId:(NSString *)userSessionId;
- (void)firstIncomingCallReceivedWithUserSessionId:(NSString *)userSessionId;
- (void)incomingCallReceivedWithUserSessionId:(NSString *)userSessionId;
- (void)callConnectionEstablishedWithUserSessionId:(NSString *)userSessionId;
- (void)callConnectionLostWithUserSessionId:(NSString *)userSessionId;
- (void)callConnectionFailedWithUserSessionId:(NSString *)userSessionId;
- (void)noAnswerFromUserSessionId:(NSString *)userSessionId;
- (void)newMissedCallFromUserSessionId:(NSString *)userSessionId;
- (void)remoteUserHungUp:(NSString *)userSessionId;
- (void)callIsFinishedWithReason:(SMCallFinishReason)callFinishReason;
- (void)incomingCallWasAutoRejectedWithUserSessionId:(NSString *)userSessionId;

@optional
- (void)localVideoRenderViewWasCreated:(UIView *)view
							forTrackId:(NSString *)trackId
					 inStreamWithLabel:(NSString *)streamLabel;

- (void)localVideoRenderView:(UIView *)view
				  forTrackId:(NSString *)trackId
		   inStreamWithLabel:(NSString *)streamLabel
			 hasSetFrameSize:(CGSize)frameSize;


- (void)remoteVideoRenderView:(UIView *)view
   wasCreatedForUserSessionId:(NSString *)userSessionId
				   forTrackId:(NSString *)trackId
			inStreamWithLabel:(NSString *)streamLabel;

- (void)remoteVideoRenderView:(UIView *)view
			 forUserSessionId:(NSString *)userSessionId
				   forTrackId:(NSString *)trackId
			inStreamWithLabel:(NSString *)streamLabel
			  hasSetFrameSize:(CGSize)frameSize;

- (void)screenSharingVideoRenderView:(UIView *)view
		  wasCreatedForUserSessionId:(NSString *)userSessionId
						  forTrackId:(NSString *)trackId
				   inStreamWithLabel:(NSString *)streamLabel;

- (void)screenSharingVideoRenderView:(UIView *)view
					forUserSessionId:(NSString *)userSessionId
						  forTrackId:(NSString *)trackId
				   inStreamWithLabel:(NSString *)streamLabel
					 hasSetFrameSize:(CGSize)frameSize;

- (void)screenSharingHasBeenStoppedByRemoteUser:(NSString *)userSessionId;


- (void)localVideoHasBeenRemovedForTrackId:(NSString *)trackId inStreamWithLabel:(NSString *)streamLabel;
- (void)remoteVideoHasBeenRemovedForUserSessionId:(NSString *)userSessionId forTrackId:(NSString *)trackId inStreamWithLabel:(NSString *)streamLabel;

@end


@class CallingViewController;

@interface PeerConnectionController : NSObject

@property BOOL inCall;
@property (nonatomic, readonly) BOOL hasVideo; // check inCall first. If inCall is NO then hasVideo is NO.

@property (nonatomic, weak) id <UserIntefaceCallbacks> userInterfaceCallbacksDelegate;

@property (nonatomic, strong) CallingViewController *callingViewController; // PeerConnectionController relies on UserInterfaceManager to present calling view controller

+ (PeerConnectionController *)sharedInstance;

- (void)updateIceServers:(NSArray *)servers;

- (void)sessionIdHasChanged:(NSString *)newSessionId;

- (void)callToBuddy:(User *)buddy withVideo:(BOOL)withVideo;
- (void)addUserToCall:(User *)user withVideo:(BOOL)withVideo;
//- (void)hangUpBuddy:(Buddy *)buddy; // see comments in implementation
- (void)hangUpWithReason:(ByeReason)reason
		callFinishReason:(SMCallFinishReason)callFinishReason;
- (void)hangUp; // calls hangUpWithReason with kByeReasonNotSpecified and forgetAboutCall==YES
- (void)acceptIncomingCall:(User *)from withVideo:(BOOL)withVideo;

- (BOOL)isUserSessionIdInCall:(NSString *)sessionId;

- (void)muteAudio:(BOOL)mute;
- (void)muteVideo:(BOOL)mute;

- (int)calculateMaxNumberOfVideoConnections;

- (void)setVideoPreferencesWithCamera:(NSString *)camera
                      videoFrameWidth:(NSInteger)videoFrameWidth
                     videoFrameHeight:(NSInteger)videoFrameHeight
                                  FPS:(NSInteger)fps;

- (NSArray *)videoDeviceCapabilitiesForDevice:(SMVideoDevice *)device; // returns array of VideoDeviceCapability
- (NSArray *)videoDevices; // returns array of VideoDevices

- (NSArray *)screenSharingUsers;
- (void)connectToScreenSharingForUserSessionId:(NSString *)userSessionId;
- (void)stopRemoteScreenSharingForUserSessionId:(NSString *)userSessionId;

@end
