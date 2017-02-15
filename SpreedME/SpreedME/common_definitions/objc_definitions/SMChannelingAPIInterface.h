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

#import "ChannelingConstants.h"

typedef enum : NSUInteger {
    kSMConnectionStateDisconnected  = 0,
    kSMConnectionStateConnecting    = 1,
    kSMConnectionStateConnected     = 2,
} SMConnectionState;


// Notifications
extern NSString * const ChannelingConnectionBecomeActiveNotification;
extern NSString * const ChannelingConnectionBecomeInactiveNotification;

extern NSString * const ConnectionHasChangedStateNotification;
extern NSString * const kConnectionHasChangedStateNotificationNewStateKey;

extern NSString * const ConnectionControllerHasProcessedChangeOfApplicationModeNotification;
extern NSString * const ConnectionControllerHasProcessedResetOfApplicationNotification;

extern NSString * const SelfMessageReceivedNotification;
extern NSString * const ByeMessageReceivedNotification;

extern NSString * const LocalUserDidLeaveRoomNotification;
extern NSString * const LocalUserDidJoinRoomNotification;
extern NSString * const LocalUserDidReceiveDisabledDefaultRoomErrorNotification;
extern NSString * const kRoomUserInfoKey;
extern NSString * const kRoomLeaveReasonUserInfoKey;
extern NSString * const kRoomLeaveReasonRoomChange;
extern NSString * const kRoomLeaveReasonRoomRoomExit;

extern NSString * const RemoteUserHasStartedScreenSharingNotification;

// Keys in userinfo dictionaries of corresponding notifications
extern NSString * const ByeFromNotificationUserInfoKey;
extern NSString * const ByeToNotificationUserInfoKey;
extern NSString * const ByeReasonNotificationUserInfoKey;
extern NSString * const SelfNotificationInfoKey;
extern NSString * const kSelfMessageIceServersKey;
extern NSString * const kScreenSharingUserSessionIdInfoKey;
extern NSString * const kScreenSharingTokenInfoKey;
extern NSString * const kChannelingConnectionBecomeInactiveReasonKey; // in ChannelingConnectionBecomeInactiveNotification
extern NSString * const kChannelingConnectionBecomeInactiveLoginFailedReasonKey; // in ChannelingConnectionBecomeInactiveNotification


#pragma mark - SMChannelingRequest

@interface SMChannelingRequest : NSObject
@property (nonatomic, copy) NSString *iid;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, strong) NSDictionary *userInfo;

+ (instancetype)requestWithIid:(NSString *)iid type:(NSString *)type;
- (BOOL)isSame:(SMChannelingRequest *)otherRequest;

@end


@protocol SMChannelingAPIInterface <NSObject>
@required

- (void)sendAuthenticationRequestWithUserId:(NSString *)userId nonce:(NSString *)nonce;
- (void)sendStatusWithDisplayName:(NSString *)displayName statusMessage:(NSString *)statusMessage picture:(NSString *)picture;

- (void)requestUsersListInCurrentRoom;

- (void)sayHelloToRoom:(NSString *)roomName;

- (void)sayBye; // this should be sent on app termination or going offline
- (void)sayByeToRecepient:(NSString *)recepientId withReason:(ByeReason)reason; // basically "hang up"
- (void)sendConferenceRequestMessageTo:(NSString *)conferenceId inRoom:(NSString *)room; // Special chat message for makeing conference call

- (void)sendHeartBeat:(NSTimer *)theTimer;

- (void)sendEmptySelf;

- (void)changeRoomTo:(NSString *)room;

- (void)exitFromCurrentRoom;

- (void)sendSessionsRequestWithTokenType:(NSString *)tokenType token:(NSString *)token;

/*
 If transportType==kTransportTypeAuto or kPeerToPeer: this call will try to send message thru data channel if it exists.
 If not it will send thru server.
 If transportType==kWebsocketChannelingServer: send thru channelling server
 If message is sent thru channeling server it will be wrapped in {"Type": "Whatever", "Whatever": { your document }} as descirbed in API.
 */
- (void)sendMessage:(NSString *)message
			   type:(NSString *)type
				 to:(NSString *)recepientId
	  transportType:(ChannelingMessageTransportType)transportType;

/*
 The same as sendMessage:type:to:transportType: with transport type kTransportTypeAuto
 */
- (void)sendMessage:(NSString *)message type:(NSString *)type to:(NSString *)recepientId;

@end


@protocol SMUsersManagementNotificationsProtocol <NSObject>
@required
- (void)channelingManager:(id<SMChannelingAPIInterface>)channelingManager hasReceivedSessionsList:(NSDictionary *)info;
- (void)channelingManager:(id<SMChannelingAPIInterface>)channelingManager hasReceivedUserSessionLeftEvent:(NSDictionary *)info;
- (void)channelingManager:(id<SMChannelingAPIInterface>)channelingManager hasReceivedUserSessionJoinedEvent:(NSDictionary *)info;
- (void)channelingManager:(id<SMChannelingAPIInterface>)channelingManager hasReceivedUserSessionStatusEvent:(NSDictionary *)info;
- (void)channelingManager:(id<SMChannelingAPIInterface>)channelingManager hasReceivedMessageWithAttestationToken:(NSDictionary *)info;


@end
