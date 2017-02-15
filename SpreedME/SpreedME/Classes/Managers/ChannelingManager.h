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


#import "BuddyParser.h"
#import "SMChannelingAPIInterface.h"
#import "ChannelingConstants.h"
#import "SMWebSocketController.h"
#import "STByteCount.h"
#import "STNetworkDataStatisticsController.h"
#import "User.h"


@class ChannelingManager;

@protocol ChannelingManagerObserver <NSObject>
@required

- (void)channelingManagerDidConnectToServer:(ChannelingManager *)channelingManager;
- (void)channelingManagerDidDisconnectFromServer:(ChannelingManager *)manager;
- (void)channelingManager:(ChannelingManager *)manager didReceiveSelf:(NSDictionary *)selfDict;
- (void)channelingManager:(ChannelingManager *)manager didReceiveAliveMessage:(NSDictionary *)aliveDict;
- (void)channelingManager:(ChannelingManager *)manager
	didReceiveChatMessage:(NSDictionary *)chatDict
			transportType:(ChannelingMessageTransportType)transportType;

@end


@interface ChannelingManager : NSObject <SMChannelingAPIInterface, STNetworkDataStatisticsControllerDataProvider>

@property (nonatomic, weak) id<ChannelingManagerObserver> observer;
@property (nonatomic, weak) id<SMUsersManagementNotificationsProtocol> usersManagementHandler;

@property (nonatomic, readwrite) BOOL isConnected;
@property (nonatomic, readwrite) BOOL spreedMeMode;
@property (nonatomic, readonly, copy) NSString *currentServer;

@property (nonatomic, readonly) STByteCount bytesSent;
@property (nonatomic, readonly) STByteCount bytesReceived;


+ (instancetype)sharedInstance; // Shared instance. You should not create your own instance although it is permitted now.

- (void)connectToServer:(NSString *)server withToken:(NSString *)token;
- (void)closeConnection;


// Channeling API
- (void)sendAuthenticationRequestWithUserId:(NSString *)userId nonce:(NSString *)nonce;
- (void)sendStatusWithDisplayName:(NSString *)displayName statusMessage:(NSString *)statusMessage picture:(NSString *)picture;
- (void)requestUsersListInCurrentRoom;
- (void)sayBye; // this should be sent on app termination or going offline
- (void)sayByeToRecepient:(NSString *)recepientId withReason:(ByeReason)reason; // basically "hang up"
- (void)sendConferenceRequestMessageTo:(NSString *)conferenceId inRoom:(NSString *)room; // Special chat message for makeing conference call
- (void)sendHeartBeat:(NSTimer *)theTimer;
- (void)changeRoomTo:(NSString *)room;
- (void)sendSessionsRequestWithTokenType:(NSString *)tokenType token:(NSString *)token;

- (void)sendMessage:(NSString *)message; // Sends message thru channeling server. Just sends without any additional wrapping or pollishing.



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

/*
 We now can receive messages through datachannels so we need some message dispatcher.
 At the moment we are going to use ChannelingManager so we need some method to get messages to it.
 TODO: create real message dispatcher!
 */
- (void)messageReceived:(id)message transportType:(ChannelingMessageTransportType)transportType wrapperId:(NSString *)wrapperId;


@end
