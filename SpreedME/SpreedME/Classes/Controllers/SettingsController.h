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

#import "CommonNetDefinitions.h"

typedef void (^GetServerConfigCompletionBlock)(NSError *error);
typedef void (^GetSpreedMEConfigCompletionBlock)(NSString *spreedMEURL, NSError *error);
typedef void (^GetRandomRoomCompletionBlock)(NSString *randomRoomName, NSError *error);
typedef void (^GetTemporaryPasswordCompletionBlock)(NSString *temporaryPassword, NSError *error);
typedef void (^GetLEDConfigCompletionBlock)(NSDictionary *ledConfigDict, NSError *error);

extern NSString * const kSpreedMeModeSettingsKey;
extern NSString * const kOwnCloudModeSettingsKey;

// Keys for server config dictionary
extern NSString * const kServerConfigTitleKey;
extern NSString * const kServerConfigTokenKey;
extern NSString * const kServerConfigVersionKey;
extern NSString * const kServerConfigUsersEnabledKey;
extern NSString * const kServerConfigUsersAllowedRegistrationKey;
extern NSString * const kServerConfigUsersModeKey;
extern NSString * const kServerConfigDefaultRoomEnabledKey;

// Keys for owncloud server config dictionary
extern NSString * const kServerConfigSpreedWebRTCKey;
extern NSString * const kServerConfigSpreedWebRTCURLKey;
extern NSString * const kServerConfigOwnCloudKey;
extern NSString * const kServerConfigOwnCloudMessageKey;

// Keys used in random room name generation
extern NSString * const kServerRandomRoomNameKey;
extern NSString * const kServerRandomRoomURLKey;

// Keys used in services config dictionary
extern NSString * const kServiceConfigAuthorizationEndpointKey;
extern NSString * const kServiceConfigOwncloudSpreedmeEndpointKey;
extern NSString * const kServiceConfigOwncloudEndpointKey;
extern NSString * const kServiceConfigSpreedWebrtcEndpointKey;
extern NSString * const kServiceConfigSpreedboxSetupEndpointKey;


@interface SettingsController : NSObject

+ (SettingsController *)sharedInstance;

@property (nonatomic, readwrite) BOOL spreedMeMode;
@property (nonatomic, readwrite) BOOL ownCloudMode;

@property (nonatomic, strong) NSString *lastConnectedUserId;
@property (nonatomic, strong) NSString *lastConnectedOCUserPass;
@property (nonatomic, strong) NSString *lastConnectedOCServer;
@property (nonatomic, strong) NSString *lastConnectedOCSMServer;

// For update purposes only! Use objectForInfoDictionaryKey:@"CFBundleShortVersionString" for real checks!
@property (nonatomic, copy) NSString *appVersion;

// The general per app/device setting which is used only in spreedMeMode. 
@property (nonatomic, assign) BOOL shouldNotNotifyAboutNewApplicationVersion;

@property (nonatomic, copy, readonly) NSDictionary *serverConfig;
@property (nonatomic, copy, readonly) NSDictionary *servicesConfig;

- (void)resetSettings;

- (NSString *)deriveLoginServerFromWebSocketServer:(NSString *)websocketServer;
- (id<STNetworkOperation>)getServerConfigWithServer:(NSString *)server;
- (id<STNetworkOperation>)getServerConfigWithServer:(NSString *)server
								withCompletionBlock:(GetServerConfigCompletionBlock)block; //if error is nil operation was successful and you can get config through 'serverConfig' property
- (id<STNetworkOperation>)discoverServicesFromServer:(NSString *)server withCompletionBlock:(GetServerConfigCompletionBlock)block;
- (id<STNetworkOperation>)getRandomRoomNameGeneratedByServer:(NSString *)server
										 withCompletionBlock:(GetRandomRoomCompletionBlock)block;
- (id<STNetworkOperation>)getTemporaryPaswordGeneratedByServer:(NSString *)server
                                                       forName:(NSString *)name
                                             andExpirationDate:(NSString *)expiration
                                           withCompletionBlock:(GetTemporaryPasswordCompletionBlock)block;
- (id<STNetworkOperation>)getLEDConfigurationWithCompletionBlock:(GetLEDConfigCompletionBlock)block;
- (id<STNetworkOperation>)setLEDConf:(NSDictionary *)config withCompletionBlock:(GetLEDConfigCompletionBlock)block;
- (id<STNetworkOperation>)previewLEDStateConfiguration:(NSDictionary *)config withCompletionBlock:(GetLEDConfigCompletionBlock)block;
- (id<STNetworkOperation>)getLEDDefaultConfigurationWithCompletionBlock:(GetLEDConfigCompletionBlock)block;
- (id<STNetworkOperation>)getServerConfigWithServer:(NSString *)server userName:(NSString *)userName password:(NSString *)password withCompletionBlock:(GetSpreedMEConfigCompletionBlock)block;
- (NSString *)removeServerConfigEndpointFromServer:(NSString *)server;

@end
