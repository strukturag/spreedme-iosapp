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

#import "SettingsController.h"

#import <AVFoundation/AVFoundation.h>

#import "AFNetworking.h"
#import "OCLoginManager.h"
#import "ResourceDownloadManager.h"
#import "SMConnectionController.h"
#import "SpreedSSLSecurityPolicy.h"
#import "SpreedMeStrictSSLSecurityPolicy.h"
#import "UICKeyChainStore.h"
#import "UsersManager.h"

NSString * const kSpreedMeModeSettingsKey					= @"spreedMeMode";
NSString * const kOwnCloudModeSettingsKey					= @"ownCloudMode";

NSString * const kAppVersionKey								= @"applicationVersion";

NSString * const kServerConfigTitleKey							= @"Title";
NSString * const kServerConfigTokenKey							= @"Token";
NSString * const kServerConfigVersionKey						= @"Version";
NSString * const kServerConfigUsersEnabledKey					= @"UsersEnabled";
NSString * const kServerConfigUsersAllowedRegistrationKey		= @"UsersAllowRegistration";
NSString * const kServerConfigUsersModeKey						= @"UsersMode";
NSString * const kServerConfigDefaultRoomEnabledKey             = @"DefaultRoomEnabled";

NSString * const kServerConfigSpreedWebRTCKey                   = @"spreed_webrtc";
NSString * const kServerConfigSpreedWebRTCURLKey                = @"url";
NSString * const kServerConfigOwnCloudKey                       = @"owncloud";
NSString * const kServerConfigOwnCloudMessageKey                = @"message";

NSString * const kServiceConfigAuthorizationEndpointKey         = @"authorization_endpoint";
NSString * const kServiceConfigOwncloudSpreedmeEndpointKey      = @"owncloud-spreedme_endpoint";
NSString * const kServiceConfigOwncloudEndpointKey              = @"owncloud_endpoint";
NSString * const kServiceConfigSpreedWebrtcEndpointKey          = @"spreed-webrtc_endpoint";
NSString * const kServiceConfigSpreedboxSetupEndpointKey        = @"spreedbox-setup_endpoint";

NSString * const kServerRandomRoomNameKey                       = @"name";
NSString * const kServerRandomRoomURLKey                        = @"url";

NSString * const kServerTemporaryPasswordKey                    = @"tp";

NSString * const kLEDNConfigEnabledKey                          = @"enabled";
NSString * const kLEDNConfigParametersKey                       = @"parameters";


NSString * const kSMLastConnectedUserId         = @"SMLastConnectedUserId";
NSString * const kOCLastConnectedUserPass		= @"OCLastConnectedUserPass";
NSString * const kOCLastConnectedServer         = @"kOCLastConnectedServer";
NSString * const kOCLastConnectedSMServer       = @"kOCLastConnectedSMServer";

NSString * const kSMShouldNotNotifyAboutAvailableUpdateKey         = @"ShouldNotNotifyAboutAvailableUpdate";


@interface SMSettingsNetOperation : NSObject <STNetworkOperation>
@property (nonatomic, strong) AFURLConnectionOperation *afOperation;
- (void)cancel;
@end

@implementation SMSettingsNetOperation
- (void)cancel { [self.afOperation cancel]; }
@end


@implementation SettingsController
{

}


+ (SettingsController *)sharedInstance
{
	static dispatch_once_t once;
    static SettingsController *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (id)init
{
	self = [super init];
	if (self) {
		[self readValuesFromDefaults];
		
		//TODO: Maybe move this from here
		[[ResourceDownloadManager sharedInstance] registerSecurityPolicyClass:_spreedMeMode ? [SpreedMeStrictSSLSecurityPolicy class] : [SpreedSSLSecurityPolicy class]];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
	}
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Other public methods

- (void)resetSettings
{
	// We have to remember some persistant values even in reset conditions!
	BOOL spreedMeMode = _spreedMeMode;
	NSString *appVersion = [_appVersion copy];
	
	NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
	
	[self readValuesFromDefaults];
	
	self.appVersion = appVersion; // we are using propery which sets value back to userdefaults
	
	_spreedMeMode = spreedMeMode;
	
	[[NSUserDefaults standardUserDefaults] synchronize];
}


- (void)readValuesFromDefaults
{	
	NSString *spreedMeMode = [UICKeyChainStore stringForKey:kSpreedMeModeSettingsKey];
	_spreedMeMode = [spreedMeMode isEqualToString:kSMSpreedMeModeOnString];
    
    NSString *ownCloudMode = [UICKeyChainStore stringForKey:kOwnCloudModeSettingsKey];
    _ownCloudMode = [ownCloudMode isEqualToString:kOCOwnCloudModeOnString];
	
	_appVersion = [[NSUserDefaults standardUserDefaults] objectForKey:kAppVersionKey];
    _shouldNotNotifyAboutNewApplicationVersion = [[NSUserDefaults standardUserDefaults] boolForKey:kSMShouldNotNotifyAboutAvailableUpdateKey];
    
    _lastConnectedUserId = [UICKeyChainStore stringForKey:kSMLastConnectedUserId];
    _lastConnectedOCUserPass = [UICKeyChainStore stringForKey:kOCLastConnectedUserPass];
    _lastConnectedOCServer = [UICKeyChainStore stringForKey:kOCLastConnectedServer];
    _lastConnectedOCSMServer = [UICKeyChainStore stringForKey:kOCLastConnectedSMServer];
}


#pragma mark - Properties implementation

- (void)setSpreedMeMode:(BOOL)spreedMeMode
{
	if (spreedMeMode != _spreedMeMode) {
		_spreedMeMode = spreedMeMode;
		[UICKeyChainStore setString:_spreedMeMode ? kSMSpreedMeModeOnString : kSMSpreedMeModeOffString forKey:kSpreedMeModeSettingsKey];
	}
}


- (void)setOwnCloudMode:(BOOL)ownCloudMode
{
    if (ownCloudMode != _ownCloudMode) {
        _ownCloudMode = ownCloudMode;
        [UICKeyChainStore setString:_ownCloudMode ? kOCOwnCloudModeOnString : kSMSpreedMeModeOffString forKey:kOwnCloudModeSettingsKey];
    }
}


- (void)setLastConnectedUserId:(NSString *)lastConnectedUserId
{
	if (![_lastConnectedUserId isEqualToString:lastConnectedUserId]) {
		_lastConnectedUserId = lastConnectedUserId;
		
		if (_lastConnectedUserId.length > 0) {
			[UICKeyChainStore setString:_lastConnectedUserId forKey:kSMLastConnectedUserId];
		} else {
			[UICKeyChainStore removeItemForKey:kSMLastConnectedUserId];
		}
	}
}


- (void)setLastConnectedOCUserPass:(NSString *)lastConnectedOCUserPass
{
    if (![_lastConnectedOCUserPass isEqualToString:lastConnectedOCUserPass]) {
        _lastConnectedOCUserPass = lastConnectedOCUserPass;
        
        if (_lastConnectedOCUserPass.length > 0) {
            [UICKeyChainStore setString:_lastConnectedOCUserPass forKey:kOCLastConnectedUserPass];
        } else {
            [UICKeyChainStore removeItemForKey:kOCLastConnectedUserPass];
        }
    }
}


- (void)setLastConnectedOCServer:(NSString *)lastConnectedOCServer
{
    if (![_lastConnectedOCServer isEqualToString:lastConnectedOCServer]) {
        _lastConnectedOCServer = lastConnectedOCServer;
        
        if (_lastConnectedOCServer.length > 0) {
            [UICKeyChainStore setString:_lastConnectedOCServer forKey:kOCLastConnectedServer];
        } else {
            [UICKeyChainStore removeItemForKey:kOCLastConnectedServer];
        }
    }
}


- (void)setLastConnectedOCSMServer:(NSString *)lastConnectedOCSMServer
{
    if (![_lastConnectedOCSMServer isEqualToString:lastConnectedOCSMServer]) {
        _lastConnectedOCSMServer = lastConnectedOCSMServer;
        
        if (_lastConnectedOCSMServer.length > 0) {
            [UICKeyChainStore setString:_lastConnectedOCSMServer forKey:kOCLastConnectedSMServer];
        } else {
            [UICKeyChainStore removeItemForKey:kOCLastConnectedSMServer];
        }
    }
}


- (void)setAppVersion:(NSString *)appVersion
{
	if (_appVersion != appVersion) {
		_appVersion = [appVersion copy];
		
		[[NSUserDefaults standardUserDefaults] setObject:_appVersion forKey:kAppVersionKey];
	}
}


- (void)setShouldNotNotifyAboutNewApplicationVersion:(BOOL)shouldNotNotifyAboutNewApplicationVersion
{
    if (_shouldNotNotifyAboutNewApplicationVersion != shouldNotNotifyAboutNewApplicationVersion) {
        _shouldNotNotifyAboutNewApplicationVersion = shouldNotNotifyAboutNewApplicationVersion;
        
        [[NSUserDefaults standardUserDefaults] setBool:_shouldNotNotifyAboutNewApplicationVersion
                                                forKey:kSMShouldNotNotifyAboutAvailableUpdateKey];
    }
}


#pragma mark - Server related methods

- (id<STNetworkOperation>)getServerConfigWithServer:(NSString *)server
{
	return [self getServerConfigWithServer:server withCompletionBlock:NULL];
}


- (id<STNetworkOperation>)getServerConfigWithServer:(NSString *)server withCompletionBlock:(GetServerConfigCompletionBlock)block
{
	if (!([server length] > 0)) {
		return nil;
	}
	
	AFHTTPRequestOperationManager *httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
	httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
	httpRequestOpManager.requestSerializer = [[AFHTTPRequestSerializer alloc] init];
    httpRequestOpManager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
	AFSecurityPolicy *securityPolicy = self.spreedMeMode ? [SpreedMeStrictSSLSecurityPolicy defaultPolicy] : [SpreedSSLSecurityPolicy defaultPolicy];
	httpRequestOpManager.securityPolicy = securityPolicy;
	
	GetServerConfigCompletionBlock complBlock = NULL;
	
	if (block) {
		complBlock = [block copy];
	}
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
    
    AFHTTPRequestOperation *op = [httpRequestOpManager GET:server parameters:@{} success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([operation.responseObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *spreedWebRTCService = [operation.responseObject objectForKey:kServerConfigSpreedWebRTCKey];
            if (spreedWebRTCService) {
                NSString *spreedWebRTCServiceURL = [spreedWebRTCService objectForKey:kServerConfigSpreedWebRTCURLKey];
                if ([spreedWebRTCServiceURL length] > 0) {
                    spreed_me_log("ownCloud service found.");
                    NSString *owncloudServiceURL = [self removeServerConfigEndpointFromServer:server];
                    [[SMConnectionController sharedInstance] connectToOwnCloudService:owncloudServiceURL withSpreedMEService:spreedWebRTCServiceURL];
                    if (complBlock) {
                        complBlock([NSError errorWithDomain:@"Application domain" code:101 userInfo:@{@"error" : @"ownCloud service found"}]);
                    }
                }
            }
            
            if ([operation.responseObject objectForKey:kServerConfigVersionKey]) {
                _serverConfig = operation.responseObject;
                spreed_me_log("Saved server configuration");
                if (![[_serverConfig objectForKey:kServerConfigDefaultRoomEnabledKey] boolValue]) {
                    [self getRandomRoomNameGeneratedByServer:server withCompletionBlock:NULL];
                }
                if (complBlock) {
                    complBlock(nil);
                }
            }
        } else {
            spreed_me_log("Wrong config format");
            if (complBlock) {
                complBlock([NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Wrong config format"}]);
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if ([operation.responseObject isKindOfClass:[NSDictionary class]]) {
            NSString *ownCloudServiceMessage = [operation.responseObject objectForKey:kServerConfigOwnCloudMessageKey];
            if ([ownCloudServiceMessage isEqualToString:@"App is not enabled"]) {
                spreed_me_log("ownCloud service found. Needs auth.");
                NSString *owncloudServiceURL = [self removeServerConfigEndpointFromServer:server];
                [[SMConnectionController sharedInstance] presentLoginScreenToGetSpreedMEConfigurationInOwnCloudServer:owncloudServiceURL];
                if (complBlock) {
                    complBlock([NSError errorWithDomain:@"Application domain" code:101 userInfo:@{@"error" : @"ownCloud service found"}]);
                }
            }
        } else {
            if (_spreedMeMode || _ownCloudMode) {
                spreed_me_log("Couldn't load server config %s", [error cDescription]);
                if (complBlock) {
                    complBlock(error);
                }
            } else {
                if (error.code != -1012) {
                    spreed_me_log("Couldn't get server config. Error: %s", [error cDescription]);
                    if ([self tryAntoherServerURLForServer:server]) {
                        if (complBlock) {
                            complBlock([NSError errorWithDomain:@"Application domain" code:101 userInfo:@{@"error" : @"No Spreed.ME service found"}]);
                        }
                    } else {
                        spreed_me_log("Tried all different server URLs. NO server config found.");
                        if (complBlock) {
                            complBlock([NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Wrong config format"}]);
                        }
                    }
                } else {
                    spreed_me_log("Certificate Authentication needed. Error: %s", [error cDescription]);
                    if (complBlock) {
                        complBlock([NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Wrong config format"}]);
                    }
                }
            }
        }
    }];
    
	SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
	wrapperOperation.afOperation = op;
	
	return wrapperOperation;
}


- (BOOL)tryAntoherServerURLForServer:(NSString *)server
{
    NSString *firstPathMod = @"/index.php/apps/spreedme";
    NSString *secondPathMod = @"/owncloud";
    
    NSString *tryingServer = [self removeServerConfigEndpointFromServer:server];
    spreed_me_log("Trying another server URL for server: %s", [tryingServer cDescription]);
    
    if ([tryingServer rangeOfString:firstPathMod].location == NSNotFound) {
        tryingServer = [NSString stringWithFormat:@"%@%@", tryingServer, firstPathMod];
        spreed_me_log("Trying with URL: %s", [tryingServer cDescription]);
        [[SMConnectionController sharedInstance] connectToNewServer:tryingServer];
        return YES;
    } else {
        tryingServer = [tryingServer substringToIndex:[tryingServer length] - [firstPathMod length]];
        if ([tryingServer rangeOfString:secondPathMod].location == NSNotFound) {
            [tryingServer stringByReplacingOccurrencesOfString:firstPathMod withString:@""];
            tryingServer = [NSString stringWithFormat:@"%@%@%@", tryingServer, secondPathMod, firstPathMod];
            spreed_me_log("Trying with URL: %s", [tryingServer cDescription]);
            [[SMConnectionController sharedInstance] connectToNewServer:tryingServer];
            return YES;
        }
    }
    
    return NO;
}


- (NSString *)removeServerConfigEndpointFromServer:(NSString *)server
{
    NSString *serverWithNoEndpoints = [server copy];
    NSString *configSuffix = [NSString stringWithFormat:@"%@%@", kRESTAPIEndpoint, kServerConfigEndpoint];
    
    if ([serverWithNoEndpoints hasSuffix:configSuffix]) {
        serverWithNoEndpoints = [serverWithNoEndpoints substringToIndex:[serverWithNoEndpoints length] - [configSuffix length]];
    }
    
    return serverWithNoEndpoints;
}


- (id<STNetworkOperation>)getServerConfigWithServer:(NSString *)server userName:(NSString *)userName password:(NSString *)password withCompletionBlock:(GetSpreedMEConfigCompletionBlock)block
{
    if (!([server length] > 0)) {
        return nil;
    }
    
    AFHTTPRequestOperationManager *httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
    httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
    httpRequestOpManager.requestSerializer = [[AFHTTPRequestSerializer alloc] init];
    httpRequestOpManager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    AFSecurityPolicy *securityPolicy = self.spreedMeMode ? [SpreedMeStrictSSLSecurityPolicy defaultPolicy] : [SpreedSSLSecurityPolicy defaultPolicy];
    httpRequestOpManager.securityPolicy = securityPolicy;
    
    GetSpreedMEConfigCompletionBlock complBlock = NULL;
    
    if (block) {
        complBlock = [block copy];
    }
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
    
    [httpRequestOpManager.requestSerializer setAuthorizationHeaderFieldWithUsername:userName password:password];
    
    AFHTTPRequestOperation *op = [httpRequestOpManager GET:server parameters:@{} success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([operation.responseObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *spreedWebRTCService = [operation.responseObject objectForKey:kServerConfigSpreedWebRTCKey];
            if (spreedWebRTCService) {
                NSString *spreedWebRTCServiceURL = [spreedWebRTCService objectForKey:kServerConfigSpreedWebRTCURLKey];
                if ([spreedWebRTCServiceURL length] > 0) {
                    spreed_me_log("ownCloud service found.");
                    if (complBlock) {
                        complBlock(spreedWebRTCServiceURL, nil);
                    }
                }
            }
        } else {
            spreed_me_log("Wrong config format");
            if (complBlock) {
                complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Wrong config format"}]);
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (complBlock) {
            complBlock(nil, [NSError errorWithDomain:@"Application domain" code:102 userInfo:@{@"error" : @"ownCloud service NOT found"}]);
        }
    }];
    
    SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
    wrapperOperation.afOperation = op;
    
    return wrapperOperation;
}


- (id<STNetworkOperation>)getRandomRoomNameGeneratedByServer:(NSString *)server withCompletionBlock:(GetRandomRoomCompletionBlock)block
{
    if (!([server length] > 0)) {
		if (block) {
			block(nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:@{NSLocalizedDescriptionKey : @"Server URL is empty."}]);
		};
		return nil;
	}
	
	AFHTTPRequestOperationManager *httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
	httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
	httpRequestOpManager.requestSerializer = [[AFHTTPRequestSerializer alloc] init];
	AFSecurityPolicy *securityPolicy = self.spreedMeMode ? [SpreedMeStrictSSLSecurityPolicy defaultPolicy] : [SpreedSSLSecurityPolicy defaultPolicy];
    httpRequestOpManager.securityPolicy = securityPolicy;
	
	GetRandomRoomCompletionBlock complBlock = NULL;
	
	if (block) {
		complBlock = [block copy];
	}
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
    
	// We add an empty dictionary as parameter in order to make AFHTTPRequestSerializer set application/x-www-form-urlencoded as content type.
	AFHTTPRequestOperation *op = [httpRequestOpManager POST:server parameters:@{} success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([operation.responseObject isKindOfClass:[NSDictionary class]]) {
			NSDictionary *serverResponse = operation.responseObject;
            NSString *randomRoomName = [serverResponse objectForKeyedSubscript:kServerRandomRoomNameKey];
			if (complBlock) {
				complBlock(randomRoomName, nil);
			}
		} else {
			spreed_me_log("Wrong random room response format");
			if (complBlock) {
				complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Wrong random room response format"}]);
			}
		}
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        spreed_me_log("Couldn't receive random generated room from server");
		if (complBlock) {
			complBlock(nil, error);
		}
    }];
	
	SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
	wrapperOperation.afOperation = op;
	
	return wrapperOperation;
}


- (id<STNetworkOperation>)discoverServicesFromServer:(NSString *)server withCompletionBlock:(GetServerConfigCompletionBlock)block
{
    if (!([server length] > 0)) {
        return nil;
    }
    
    AFHTTPRequestOperationManager *httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
    httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
    httpRequestOpManager.requestSerializer = [[AFHTTPRequestSerializer alloc] init];
    httpRequestOpManager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    AFSecurityPolicy *securityPolicy = self.spreedMeMode ? [SpreedMeStrictSSLSecurityPolicy defaultPolicy] : [SpreedSSLSecurityPolicy defaultPolicy];
    httpRequestOpManager.securityPolicy = securityPolicy;
    
    GetServerConfigCompletionBlock complBlock = NULL;
    
    if (block) {
        complBlock = [block copy];
    }
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
    
    AFHTTPRequestOperation *op = [httpRequestOpManager GET:server parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([operation.responseObject isKindOfClass:[NSDictionary class]]) {
            _servicesConfig = operation.responseObject;
            spreed_me_log("Saved services configuration");
            if (complBlock) {
                complBlock(nil);
            }
        } else {
            spreed_me_log("Wrong services config format");
            if (complBlock) {
                complBlock([NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Wrong services config format"}]);
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        spreed_me_log("Couldn't load services config %s", [error cDescription]);
        if (complBlock) {
            complBlock(error);
        }
    }];
    
    SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
    wrapperOperation.afOperation = op;
    
    return wrapperOperation;
}


- (id<STNetworkOperation>)getTemporaryPaswordGeneratedByServer:(NSString *)server forName:(NSString *)name andExpirationDate:(NSString *)expiration withCompletionBlock:(GetTemporaryPasswordCompletionBlock)block
{
    if (!([server length] > 0)) {
        if (block) {
            block(nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:@{NSLocalizedDescriptionKey : @"Server URL is empty."}]);
        };
        return nil;
    }
    
    AFHTTPRequestOperationManager *httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
    httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
    httpRequestOpManager.requestSerializer = [[AFHTTPRequestSerializer alloc] init];
    AFSecurityPolicy *securityPolicy = self.spreedMeMode ? [SpreedMeStrictSSLSecurityPolicy defaultPolicy] : [SpreedSSLSecurityPolicy defaultPolicy];
    httpRequestOpManager.securityPolicy = securityPolicy;
    
    GetRandomRoomCompletionBlock complBlock = NULL;
    
    NSDictionary *parameters = @{@"userid" : name,
                                 @"expiration" : expiration};
    
    if (block) {
        complBlock = [block copy];
    }
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
    
    [httpRequestOpManager.requestSerializer setAuthorizationHeaderFieldWithUsername:_lastConnectedUserId password:_lastConnectedOCUserPass];
    
    AFHTTPRequestOperation *op = [httpRequestOpManager POST:server parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([operation.responseObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *serverResponse = operation.responseObject;
            NSString *temporaryPass = [serverResponse objectForKeyedSubscript:kServerTemporaryPasswordKey];
            if (complBlock) {
                complBlock(temporaryPass, nil);
            }
        } else {
            spreed_me_log("Wrong temporary password response format");
            if (complBlock) {
                complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Wrong temporary password response format"}]);
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        spreed_me_log("Couldn't receive temporary password from server. Error: %@", error.description);
        if (complBlock) {
            complBlock(nil, error);
        }
    }];
    
    SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
    wrapperOperation.afOperation = op;
    
    return wrapperOperation;
}


- (id<STNetworkOperation>)getLEDConfigurationWithCompletionBlock:(GetLEDConfigCompletionBlock)block
{
    NSDictionary *services = [[SettingsController sharedInstance] servicesConfig];
    NSString *restAPIEndpoint = nil;
    
    
    GetLEDConfigCompletionBlock complBlock = NULL;
    
    if (block) {
        complBlock = [block copy];
    }
    
    if (services) {
        restAPIEndpoint = [[services objectForKey:kServiceConfigSpreedWebrtcEndpointKey] stringByAppendingString:@"/api/v1"];
    } else {
        if (complBlock) {
            complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Could not find services in well-know document."}]);
        }
        return nil;
    }
    
    SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
    wrapperOperation.afOperation = nil;
    
    NSString *accessToken = [UsersManager defaultManager].currentUser.accessToken;
    NSDate *expirationDate = [UsersManager defaultManager].currentUser.accessTokenExpirationDate;
    
    if ([accessToken length] > 0 && [expirationDate timeIntervalSinceDate:[NSDate date]] > 0) {
        [self getLEDConfigurationWithAccessToken:accessToken andCompletionBlock:complBlock];
    } else {
        [[OCLoginManager sharedInstance] getAccessToken:_lastConnectedUserId
                                               password:_lastConnectedOCUserPass
                                         serverEndpoint:restAPIEndpoint
                                        completionBlock:^(NSString *accessToken, NSInteger expiresIn, NSError *error) {
                                            if (!error && [accessToken length] > 0 && expiresIn > 0) {
                                                [UsersManager defaultManager].currentUser.accessToken = accessToken;
                                                [UsersManager defaultManager].currentUser.accessTokenExpirationDate = [[NSDate date] dateByAddingTimeInterval:(expiresIn - 300)]; //Grace of 5 mins (300sec)
                                                
                                                [self getLEDConfigurationWithAccessToken:accessToken andCompletionBlock:complBlock];
                                            } else {
                                                spreed_me_log("Error getting access token from server");
                                                if (complBlock) {
                                                    complBlock(nil, error);
                                                }
                                            }
                                        }];
    }
    
    return wrapperOperation;
}


- (id<STNetworkOperation>)getLEDConfigurationWithAccessToken:(NSString *)accessToken andCompletionBlock:(GetLEDConfigCompletionBlock)block
{
    NSDictionary *services = [[SettingsController sharedInstance] servicesConfig];
    NSString *ledControlEndpoint = nil;
    
    GetLEDConfigCompletionBlock complBlock = NULL;
    
    if (block) {
        complBlock = [block copy];
    }
    
    if (services) {
        ledControlEndpoint = [[services objectForKey:kServiceConfigSpreedboxSetupEndpointKey] stringByAppendingString:@"/api/v1/system/service/led"];
    } else {
        if (complBlock) {
            complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Could not find any led endpoint."}]);
        }
        return nil;
    }
    
    AFHTTPRequestOperationManager *httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
    httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
    httpRequestOpManager.requestSerializer = [[AFHTTPRequestSerializer alloc] init];
    AFSecurityPolicy *securityPolicy = self.spreedMeMode ? [SpreedMeStrictSSLSecurityPolicy defaultPolicy] : [SpreedSSLSecurityPolicy defaultPolicy];
    httpRequestOpManager.securityPolicy = securityPolicy;
    
    NSString *authValue = [NSString stringWithFormat:@"Bearer %@", accessToken];
    [httpRequestOpManager.requestSerializer setValue:authValue forHTTPHeaderField:@"Authorization"];
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
    
    // We add an empty dictionary as parameter in order to make AFHTTPRequestSerializer set application/x-www-form-urlencoded as content type.
    AFHTTPRequestOperation *op = [httpRequestOpManager GET: ledControlEndpoint parameters:@{} success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([operation.responseObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *serverResponse = operation.responseObject;
            NSDictionary *resultDict = [serverResponse objectForKeyedSubscript:@"result"];
            if (complBlock) {
                complBlock(resultDict, nil);
            }
        } else {
            spreed_me_log("Wrong LED config response format");
            if (complBlock) {
                complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Wrong LED config response format"}]);
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        spreed_me_log("Couldn't receive LED config from server. Error: %@", [error description]);
        if (complBlock) {
            complBlock(nil, error);
        }
    }];
    
    SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
    wrapperOperation.afOperation = op;
    
    return wrapperOperation;
}


- (id<STNetworkOperation>)setLEDConf:(NSDictionary *)config withCompletionBlock:(GetLEDConfigCompletionBlock)block
{
    NSDictionary *services = [[SettingsController sharedInstance] servicesConfig];
    NSString *restAPIEndpoint = nil;
    
    GetLEDConfigCompletionBlock complBlock = NULL;
    
    if (block) {
        complBlock = [block copy];
    }
    
    if (services) {
        restAPIEndpoint = [[services objectForKey:kServiceConfigSpreedWebrtcEndpointKey] stringByAppendingString:@"/api/v1"];
    } else {
        if (complBlock) {
            complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Could not find services in well-know document."}]);
        }
        return nil;
    }
    
    SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
    wrapperOperation.afOperation = nil;
    
    NSString *accessToken = [UsersManager defaultManager].currentUser.accessToken;
    NSDate *expirationDate = [UsersManager defaultManager].currentUser.accessTokenExpirationDate;
    
    if ([accessToken length] > 0 && [expirationDate timeIntervalSinceDate:[NSDate date]] > 0) {
        [self setLEDConf:config withAccessToken:accessToken andCompletionBlock:complBlock];
    } else {
        [[OCLoginManager sharedInstance] getAccessToken:_lastConnectedUserId
                                               password:_lastConnectedOCUserPass
                                         serverEndpoint:restAPIEndpoint
                                        completionBlock:^(NSString *accessToken, NSInteger expiresIn, NSError *error) {
                                            if (!error && [accessToken length] > 0 && expiresIn > 0) {
                                                [UsersManager defaultManager].currentUser.accessToken = accessToken;
                                                [UsersManager defaultManager].currentUser.accessTokenExpirationDate = [[NSDate date] dateByAddingTimeInterval:(expiresIn - 300)]; //Grace of 5 mins (300sec)
                                                
                                                [self setLEDConf:config withAccessToken:accessToken andCompletionBlock:complBlock];
                                            } else {
                                                spreed_me_log("Error getting access token from server");
                                                if (complBlock) {
                                                    complBlock(nil, error);
                                                }
                                            }
                                        }];
    }
    
    return wrapperOperation;
}


- (id<STNetworkOperation>)setLEDConf:(NSDictionary *)config withAccessToken:(NSString *)accessToken andCompletionBlock:(GetLEDConfigCompletionBlock)block
{
    NSDictionary *services = [[SettingsController sharedInstance] servicesConfig];
    NSString *ledControlEndpoint = nil;
    
    GetLEDConfigCompletionBlock complBlock = NULL;
    
    if (block) {
        complBlock = [block copy];
    }
    
    if (services) {
        ledControlEndpoint = [[services objectForKey:kServiceConfigSpreedboxSetupEndpointKey] stringByAppendingString:@"/api/v1/system/service/led"];
    } else {
        if (complBlock) {
            complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Could not find services in well-know document."}]);
        }
        return nil;
    }
    
    AFHTTPRequestOperationManager *httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
    httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
    httpRequestOpManager.requestSerializer = [[AFJSONRequestSerializer alloc] init];
    AFSecurityPolicy *securityPolicy = self.spreedMeMode ? [SpreedMeStrictSSLSecurityPolicy defaultPolicy] : [SpreedSSLSecurityPolicy defaultPolicy];
    httpRequestOpManager.securityPolicy = securityPolicy;
    
    NSString *authValue = [NSString stringWithFormat:@"Bearer %@", accessToken];
    [httpRequestOpManager.requestSerializer setValue:authValue forHTTPHeaderField:@"Authorization"];
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
    
    AFHTTPRequestOperation *op = [httpRequestOpManager POST:ledControlEndpoint parameters:config success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([operation.responseObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *serverResponse = operation.responseObject;
            NSDictionary *resultDict = [serverResponse objectForKeyedSubscript:@"result"];
            if (complBlock) {
                complBlock(resultDict, nil);
            }
        } else {
            spreed_me_log("Wrong LED config response format");
            if (complBlock) {
                complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Wrong LED config response format"}]);
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        spreed_me_log("Couldn't receive LED config from server. Error: %@", [error description]);
        if (complBlock) {
            complBlock(nil, error);
        }
    }];
    
    SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
    wrapperOperation.afOperation = op;
    
    return wrapperOperation;
}


- (id<STNetworkOperation>)getLEDDefaultConfigurationWithCompletionBlock:(GetLEDConfigCompletionBlock)block
{
    NSDictionary *services = [[SettingsController sharedInstance] servicesConfig];
    NSString *restAPIEndpoint = nil;
    
    
    GetLEDConfigCompletionBlock complBlock = NULL;
    
    if (block) {
        complBlock = [block copy];
    }
    
    if (services) {
        restAPIEndpoint = [[services objectForKey:kServiceConfigSpreedWebrtcEndpointKey] stringByAppendingString:@"/api/v1"];
    } else {
        if (complBlock) {
            complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Could not find services in well-know document."}]);
        }
        return nil;
    }
    
    SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
    wrapperOperation.afOperation = nil;
    
    NSString *accessToken = [UsersManager defaultManager].currentUser.accessToken;
    NSDate *expirationDate = [UsersManager defaultManager].currentUser.accessTokenExpirationDate;
    
    if ([accessToken length] > 0 && [expirationDate timeIntervalSinceDate:[NSDate date]] > 0) {
        [self getLEDDefaultConfigurationWithCompletionBlock:accessToken andCompletionBlock:complBlock];
    } else {
        [[OCLoginManager sharedInstance] getAccessToken:_lastConnectedUserId
                                               password:_lastConnectedOCUserPass
                                         serverEndpoint:restAPIEndpoint
                                        completionBlock:^(NSString *accessToken, NSInteger expiresIn, NSError *error) {
                                            if (!error && [accessToken length] > 0 && expiresIn > 0) {
                                                [UsersManager defaultManager].currentUser.accessToken = accessToken;
                                                [UsersManager defaultManager].currentUser.accessTokenExpirationDate = [[NSDate date] dateByAddingTimeInterval:(expiresIn - 300)]; //Grace of 5 mins (300sec)
                                                
                                                [self getLEDDefaultConfigurationWithCompletionBlock:accessToken andCompletionBlock:complBlock];
                                            } else {
                                                spreed_me_log("Error getting access token from server");
                                                if (complBlock) {
                                                    complBlock(nil, error);
                                                }
                                            }
                                        }];
    }
    
    return wrapperOperation;
}


- (id<STNetworkOperation>)getLEDDefaultConfigurationWithCompletionBlock:(NSString *)accessToken andCompletionBlock:(GetLEDConfigCompletionBlock)block
{
    NSDictionary *services = [[SettingsController sharedInstance] servicesConfig];
    NSString *ledControlEndpoint = nil;
    
    GetLEDConfigCompletionBlock complBlock = NULL;
    
    if (block) {
        complBlock = [block copy];
    }
    
    if (services) {
        ledControlEndpoint = [[services objectForKey:kServiceConfigSpreedboxSetupEndpointKey] stringByAppendingString:@"/api/v1/system/service/led/defaults"];
    } else {
        if (complBlock) {
            complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Could not find any led endpoint."}]);
        }
        return nil;
    }
    
    AFHTTPRequestOperationManager *httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
    httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
    httpRequestOpManager.requestSerializer = [[AFHTTPRequestSerializer alloc] init];
    AFSecurityPolicy *securityPolicy = self.spreedMeMode ? [SpreedMeStrictSSLSecurityPolicy defaultPolicy] : [SpreedSSLSecurityPolicy defaultPolicy];
    httpRequestOpManager.securityPolicy = securityPolicy;
    
    NSString *authValue = [NSString stringWithFormat:@"Bearer %@", accessToken];
    [httpRequestOpManager.requestSerializer setValue:authValue forHTTPHeaderField:@"Authorization"];
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
    
    // We add an empty dictionary as parameter in order to make AFHTTPRequestSerializer set application/x-www-form-urlencoded as content type.
    AFHTTPRequestOperation *op = [httpRequestOpManager GET: ledControlEndpoint parameters:@{} success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([operation.responseObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *serverResponse = operation.responseObject;
            NSDictionary *resultDict = [serverResponse objectForKeyedSubscript:@"result"];
            if (complBlock) {
                complBlock(resultDict, nil);
            }
        } else {
            spreed_me_log("Wrong LED config response format");
            if (complBlock) {
                complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Wrong LED config response format"}]);
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        spreed_me_log("Couldn't receive LED config from server. Error: %@", [error description]);
        if (complBlock) {
            complBlock(nil, error);
        }
    }];
    
    SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
    wrapperOperation.afOperation = op;
    
    return wrapperOperation;
}


- (id<STNetworkOperation>)previewLEDStateConfiguration:(NSDictionary *)config withCompletionBlock:(GetLEDConfigCompletionBlock)block
{
    NSDictionary *services = [[SettingsController sharedInstance] servicesConfig];
    NSString *restAPIEndpoint = nil;
    
    GetLEDConfigCompletionBlock complBlock = NULL;
    
    if (block) {
        complBlock = [block copy];
    }
    
    if (services) {
        restAPIEndpoint = [[services objectForKey:kServiceConfigSpreedWebrtcEndpointKey] stringByAppendingString:@"/api/v1"];
    } else {
        if (complBlock) {
            complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Could not find services in well-know document."}]);
        }
        return nil;
    }
    
    SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
    wrapperOperation.afOperation = nil;
    
    NSString *accessToken = [UsersManager defaultManager].currentUser.accessToken;
    NSDate *expirationDate = [UsersManager defaultManager].currentUser.accessTokenExpirationDate;
    
    if ([accessToken length] > 0 && [expirationDate timeIntervalSinceDate:[NSDate date]] > 0) {
        [self previewLEDStateConfiguration:config withAccessToken:accessToken andCompletionBlock:complBlock];
    } else {
        [[OCLoginManager sharedInstance] getAccessToken:_lastConnectedUserId
                                               password:_lastConnectedOCUserPass
                                         serverEndpoint:restAPIEndpoint
                                        completionBlock:^(NSString *accessToken, NSInteger expiresIn, NSError *error) {
                                            if (!error && [accessToken length] > 0 && expiresIn > 0) {
                                                [UsersManager defaultManager].currentUser.accessToken = accessToken;
                                                [UsersManager defaultManager].currentUser.accessTokenExpirationDate = [[NSDate date] dateByAddingTimeInterval:(expiresIn - 300)]; //Grace of 5 mins (300sec)
                                                
                                                [self previewLEDStateConfiguration:config withAccessToken:accessToken andCompletionBlock:complBlock];
                                            } else {
                                                spreed_me_log("Error getting access token from server");
                                                if (complBlock) {
                                                    complBlock(nil, error);
                                                }
                                            }
                                        }];
    }
    
    return wrapperOperation;
}


- (id<STNetworkOperation>)previewLEDStateConfiguration:(NSDictionary *)config withAccessToken:(NSString *)accessToken andCompletionBlock:(GetLEDConfigCompletionBlock)block
{
    NSDictionary *services = [[SettingsController sharedInstance] servicesConfig];
    NSString *ledControlEndpoint = nil;
    
    GetLEDConfigCompletionBlock complBlock = NULL;
    
    if (block) {
        complBlock = [block copy];
    }
    
    if (services) {
        ledControlEndpoint = [[services objectForKey:kServiceConfigSpreedboxSetupEndpointKey] stringByAppendingString:@"/api/v1/leds/preview"];
    } else {
        if (complBlock) {
            complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Could not find services in well-know document."}]);
        }
        return nil;
    }
    
    AFHTTPRequestOperationManager *httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
    httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
    httpRequestOpManager.requestSerializer = [[AFJSONRequestSerializer alloc] init];
    AFSecurityPolicy *securityPolicy = self.spreedMeMode ? [SpreedMeStrictSSLSecurityPolicy defaultPolicy] : [SpreedSSLSecurityPolicy defaultPolicy];
    httpRequestOpManager.securityPolicy = securityPolicy;
    
    NSString *authValue = [NSString stringWithFormat:@"Bearer %@", accessToken];
    [httpRequestOpManager.requestSerializer setValue:authValue forHTTPHeaderField:@"Authorization"];
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
    
    AFHTTPRequestOperation *op = [httpRequestOpManager PUT:ledControlEndpoint parameters:config success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([operation.responseObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *serverResponse = operation.responseObject;
            NSDictionary *resultDict = [serverResponse objectForKeyedSubscript:@"result"];
            if (complBlock) {
                complBlock(resultDict, nil);
            }
        } else {
            spreed_me_log("Wrong LED config response format");
            if (complBlock) {
                complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Wrong LED config response format"}]);
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        spreed_me_log("Couldn't preview LED config in the server. Error: %@", [error description]);
        if (complBlock) {
            complBlock(nil, error);
        }
    }];
    
    SMSettingsNetOperation *wrapperOperation = [SMSettingsNetOperation new];
    wrapperOperation.afOperation = op;
    
    return wrapperOperation;
}


- (NSString *)deriveLoginServerFromWebSocketServer:(NSString *)websocketServer
{
	if ([websocketServer length] <= 0) {
		return nil;
	}
	
	NSURL *serverURL = [NSURL URLWithString:websocketServer];
	
	NSString *server = [serverURL host];
	NSString *scheme = [serverURL scheme];
	int serverPort = 0;
	if ([scheme isEqualToString:@"wss"] || [scheme isEqualToString:@"https"]) {
		serverPort = [[serverURL port] intValue] != 0 ? [[serverURL port] intValue] : 443;
		scheme = @"https";
	} else if ([scheme isEqualToString:@"ws"] || [scheme isEqualToString:@"http"]) {
		serverPort = [[serverURL port] intValue] != 0 ? [[serverURL port] intValue] : 80;
		scheme = @"http";
	}
	server = [server stringByAppendingFormat:@":%d", serverPort];
	NSString *path = [[serverURL path] stringByDeletingLastPathComponent];
	server = [server stringByAppendingFormat:@"%@", [path isEqualToString:@"/"] ? @"" : path];
	server = [NSString stringWithFormat:@"%@://%@", scheme, server];
	
	return server;
}


#pragma mark - App notification

- (void)appWillResignActive:(NSNotification *)notification
{
	[[NSUserDefaults standardUserDefaults] synchronize];
}


@end
