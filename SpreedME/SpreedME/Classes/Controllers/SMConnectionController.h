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

#import "SMChannelingAPIInterface.h"
#import "STNetworkDataStatisticsController.h"

extern NSString * const kDefaultServer;

extern NSString * const kWebSocketEndpoint;
extern NSString * const kRESTAPIEndpoint;
extern NSString * const kImagesEndpoint;
extern NSString * const kServerConfigEndpoint;

extern NSString * const SMWebRTCServiceNameForStatistics;


typedef enum : NSInteger {
	kSMLoginFailReasonNotFailed = 0,
	kSMLoginFailReasonUnknown,
    kSMLoginFailReasonIncorrectUserNameOrPassword,
	kSMLoginFailReasonAppTokenExpired,
	kSMLoginFailReasonCouldNotGetNonce,
	kSMLoginFailReasonIncorrectUserIdWithAuthorizedSelf,
	kSMLoginFailReasonCouldNotRefreshToken,
    kSMLoginFailReasonNetworkFailure,
} SMLoginFailReason;


typedef enum SMDisconnectionReason {
	kSMDisconnectionReasonUnspecified = 0, // We don't know what happened. We should start connection process from beginning
	kSMDisconnectionReasonClosedByUser, // User has closed connection on purpose. We should not try to reconnect
	kSMDisconnectionReasonClosedByUserButShouldReconnectNextTime, // User has closed connection on purpose but wants to try to reconnect if needed
	kSMDisconnectionReasonFailed, // Generally it means network failure. We should start connection process from beginning
	kSMDisconnectionReasonUserFailedToLogin, // User has failed to login. We should start connection process from beginning
} SMDisconnectionReason;


@interface SMConnectionController : NSObject

@property (nonatomic, readonly) SMConnectionState connectionState;
@property (nonatomic, readonly) SMAppLoginState appLoginState;
@property (nonatomic, readwrite) BOOL spreedMeMode;
@property (nonatomic, readwrite) BOOL ownCloudMode;
@property (nonatomic, readwrite) BOOL ownCloudAppNotEnabled;
@property (nonatomic, readonly) BOOL appHasFailedVersionCheck;
@property (nonatomic, copy, readonly) NSString *versionCheckFailedString;

@property (nonatomic, strong, readonly) id<SMChannelingAPIInterface> channelingManager;

@property (nonatomic, strong, readonly) STNetworkDataStatisticsController *ndController;

// This is the server string exactly as user gave to us.
// Should be used for UI display purposes only.
// For connections use endpoints below.
@property (nonatomic, copy, readonly) NSString *currentServer;

// This is the server of the ownCloud service.
// We will use it just for login and authentication.
// After that we will do all calls to the Spreed.ME service inside ownCloud.
@property (nonatomic, copy) NSString *currentOwnCloudServer;

// Endpoints for different APIs
@property (nonatomic, copy, readonly) NSString *currentImagesEndpoint; // no trailing slash
@property (nonatomic, copy, readonly) NSString *currentWebSocketEndpoint; // no trailing slash
@property (nonatomic, copy, readonly) NSString *currentRESTAPIEndpoint; // no trailing slash
@property (nonatomic, copy, readonly) NSString *currentWellKnownEndpoint; // no trailing slash

// Endpoint for ownCloud REST API
@property (nonatomic, copy, readonly) NSString *currentOwnCloudRESTAPIEndpoint; // no trailing slash


+ (instancetype)sharedInstance;

- (void)connectToNewServer:(NSString *)newServer;
- (void)connectToOwnCloudService:(NSString *)ownCloudServer withSpreedMEService:(NSString *)spreedMEServer;
- (void)reconnectToCurrentServer;
- (void)reconnectIfNeeded;
- (void)disconnect;
- (void)logout;
- (void)resetConnectionController;

- (void)loginWithUsername:(NSString *)username password:(NSString *)password;
- (void)loginOCWithUsername:(NSString *)username password:(NSString *)password serverEndpoint:(NSString *)serverRESTAPIEndpoint;

- (void)presentLoginScreenToGetSpreedMEConfigurationInOwnCloudServer:(NSString *)ownCloudServer;
- (void)checkPermissionToUseSpreedMEAppWithUsername:(NSString *)username password:(NSString *)password serverEndpoint:(NSString *)serverRESTAPIEndpoint;
- (void)connectToOwnCloudService:(NSString *)ownCloudServer withSpreedMEService:(NSString *)spreedMEServer username:(NSString *)username password:(NSString *)password;

@end
