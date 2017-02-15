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

#import "SMConnectionController.h"
#import "SMConnectionController_ObjectiveCPP.h"

#import "ChannelingManager.h"
#import "ChannelingManager_ObjectiveCPP.h"
#import "ChatManager.h"
#import "CommonNetDefinitions.h"
#import "LoginManager.h"
#import "OCLoginManager.h"
#import "PeerConnectionController.h"
#import "ReachabilityManager.h"
#import "ResourceDownloadManager.h"
#import "SettingsController.h"
#import "SMAppIdentityController.h"
#import "SMAppVersionCheckController.h"
#import "SMHmacHelper.h"
#import "SMLocalizedStrings.h"
#import "SMLoginManager.h"
#import "SMNetworkDataStatisticsController.h"
#import "SpreedMeStrictSSLSecurityPolicy.h"
#import "SpreedSSLSecurityPolicy.h"
#import "STByteCount.h"
#import "UserInterfaceManager.h"
#import "UsersManager.h"


NSString * const kDefaultServer		= @"api.spreed.me:443";

NSString * const kWebSocketEndpoint = @"/ws";
NSString * const kRESTAPIEndpoint = @"/api/v1";
NSString * const kImagesEndpoint = @"/static/img";
NSString * const kWellKnownEndpoint = @"/.well-known/spreed-configuration";
NSString * const kServerConfigEndpoint = @"/config";

NSString * const kSMDefaultAppStoreApplicationLink = @"https://itunes.apple.com/us/app/webrtc/id828333357?ls=1&mt=8";

#ifdef SPREEDME
    NSString * const kSpreedMEVersionCheckEndpoint = @"/client/spreedme/ios/updatecheck";
#else
    NSString * const kWebRTCVersionCheckEndpoint = @"/client/webrtc/ios/updatecheck";
#endif

#warning USER check if it is a good name for statisics
NSString * const SMWebRTCServiceNameForStatistics = @"WebRTC_stat";


const NSTimeInterval kMaxReconnectTimeInterval = 30.0;
const NSTimeInterval kReconnectTimeOutIncreaseValue = 5.0;
const NSTimeInterval kDefaultTTL = 60.0;

const NSTimeInterval kSMDefaultAppVersionCheckInterval = 60.0 * 60.0 * 6; // 6 hours;

#pragma mark - Signalling Handler Bridge

namespace spreedme {
class SignallingHandlerBridge : public spreedme::SignallingMessageReceiverInterface,
public spreedme::ServerBasedMessageSenderInterface {
public:
	
	SignallingHandlerBridge(ChannelingManager *messageReceiver) : messageReceiver_(messageReceiver) {};
	
	virtual void SendMessage(const std::string &msg)
	{
		ChannelingManager *messageReceiver = messageReceiver_;
		NSString *message = NSStr(msg.c_str());
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[messageReceiver sendMessage:message];
		});
	}
	virtual void MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId)
	{
		ChannelingManager *messageReceiver = messageReceiver_;
		NSString *message = [NSString stringWithCString:msg.c_str() encoding:NSUTF8StringEncoding];
		NSString *wrapperId_objC = NSStr(msg.c_str());
		dispatch_async(dispatch_get_main_queue(), ^{
			[messageReceiver messageReceived:message transportType:transportType wrapperId:wrapperId_objC];
		});
	}
	virtual void MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token)
	{
		spreed_me_log("This should not happen as channeling manager shouldn't receive token messages.");
	}
	
private:
	SignallingHandlerBridge();
	
	__unsafe_unretained ChannelingManager *messageReceiver_;
};

}// namespace spreedme



typedef enum : NSInteger {
    kSMConnectionStateInternalDisconnected,
	kSMConnectionStateInternalWaitingForServerConfig,
	kSMConnectionStateInternalWaitingForAppToken,
	kSMConnectionStateInternalWaitingForRefreshedUserComboAndSecret,
	kSMConnectionStateInternalWaitingForSelf,
	kSMConnectionStateInternalWaitingForNonce,
	kSMConnectionStateInternalWaitingForAuthorizedSelf,
	kSMConnectionStateInternalConnected,
} SMConnectionStateInternal;


@interface SMConnectionController () <ChannelingManagerObserver>
{
	BOOL _wantsToConnect;
	BOOL _tryingToReconnect;
	NSTimer *_reconnectTimer;
	NSTimeInterval _reconnectTime;
	
	NSTimer *_iceServerUpdateTimer;
	
	spreedme::SignallingHandlerBridge *_signallingHandlerBridge;
	ChannelingManager *_channelingManager;
	
	SMConnectionStateInternal _state;
		
	id<STNetworkOperation> _currentLoginOperation;
	
	UIBackgroundTaskIdentifier __block _reconnectionBackgroundTaskId;
    
    SMAppVersionCheckController *_versionChecker;
}

@property (nonatomic, readwrite) SMAppLoginState appLoginState;

@property (nonatomic, readonly) BOOL isConnected;

@property (nonatomic, readwrite) SMLoginFailReason lastLoginFailReason;

@property (nonatomic, copy) NSString *lastServerVersion;
@property (nonatomic, assign) NSTimeInterval lastAppVersionCheck; // works based timeIntervalSince1970

// Override properties for read/write
@property (nonatomic, readwrite) BOOL appHasFailedVersionCheck;
@property (nonatomic, copy) NSString *versionCheckFailedString;

@end


@implementation SMConnectionController

@synthesize channelingManager = _channelingManager;
@dynamic connectionState;

// Forbid accidental arbitrary instance creation
- (instancetype)init
{
	self = nil;
	return self;
}


+ (instancetype)sharedInstance
{
	static dispatch_once_t once;
    static SMConnectionController *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] initOnce];
    });
    return sharedInstance;
}


- (instancetype)initOnce
{
	self = [super init];
	if (self) {
		_reconnectionBackgroundTaskId = UIBackgroundTaskInvalid;
		_lastLoginFailReason = kSMLoginFailReasonNotFailed;
		_appLoginState = kSMAppLoginStateNoLoginRequired;
		_state = kSMConnectionStateInternalDisconnected;
		
		_spreedMeMode = [SettingsController sharedInstance].spreedMeMode;
        _ownCloudMode = [SettingsController sharedInstance].ownCloudMode;
				
		ChannelingManager *chanManager = [[ChannelingManager alloc] init]; // init Channeling manager
		_channelingManager = chanManager;
		_channelingManager.spreedMeMode = _spreedMeMode;
		_signallingHandlerBridge = new spreedme::SignallingHandlerBridge(chanManager);
		_signallingHandler = new spreedme::SignallingHandler(std::string(), _signallingHandlerBridge);
		_signallingHandler->RegisterMessageReceiver(_signallingHandlerBridge);
		chanManager.signallingHandler = _signallingHandler;
		chanManager.observer = self;

        // Network data statistics controller setup
		_ndController = [[SMNetworkDataStatisticsController alloc]
						 initWithSavedEncryptedStatisticsInDir:[SMNetworkDataStatisticsController savedStatisticsDir]];
		[_ndController registerDataProvider:chanManager forServiceName:@"WebSocket"];
        
        // Version checker setup
        NSArray *endpoints = [self composeEndpointsURLsWithUserServerString:kDefaultServer];
        NSString *versionCheckEndpoint = endpoints[1];
        
#ifdef SPREEDME
        versionCheckEndpoint = [versionCheckEndpoint stringByAppendingString:kSpreedMEVersionCheckEndpoint];
#else
        versionCheckEndpoint = [versionCheckEndpoint stringByAppendingString:kWebRTCVersionCheckEndpoint];
#endif
        
        _versionChecker = [[SMAppVersionCheckController alloc] initWithEndpoint:versionCheckEndpoint
                                                                 securityPolicy:[SpreedMeStrictSSLSecurityPolicy defaultPolicy]];
        _versionChecker.appStoreLinkToApp = kSMDefaultAppStoreApplicationLink;
        if (_spreedMeMode) {
            [self setupAppVersionCheckerPeriodicChecks];
        }
        
		UsersManager *usersManager = [UsersManager defaultManager];
		chanManager.usersManagementHandler = usersManager;
        
        // User setup
        SMLocalUser *lastLoggedInUser = [self loadLastLoggedInUser];
       
        if (lastLoggedInUser) {
            usersManager.currentUser = lastLoggedInUser;
        } else {
            spreed_me_log("Couldn't load user!");
            usersManager.currentUser = [[SMLocalUser alloc] init];
            usersManager.currentUser.room = nil;
            if (_spreedMeMode) {
                usersManager.currentUser.wasConnected = YES; // Force new user to try to connect.
            } else if (_ownCloudMode) {
                usersManager.currentUser.wasConnected = YES; // Force new user to try to connect.
            } else { // If it is a new user in ownSpreed mode we don't know the server yet.
                usersManager.currentUser.wasConnected = NO;
            }
            [SettingsController sharedInstance].lastConnectedUserId = nil;
            [SettingsController sharedInstance].lastConnectedOCUserPass = nil;
        }
			
		
        if (_spreedMeMode) {
            [self refreshEndpointsURLsWithUserServerString:kDefaultServer];
            _appLoginState = kSMAppLoginStatePromptUserToLogin;
        } else if (_ownCloudMode){
            [self refreshEndpointsURLsWithOwnCloudServerString:[SettingsController sharedInstance].lastConnectedOCServer andSpreedMeServerString:[SettingsController sharedInstance].lastConnectedOCSMServer];
            _appLoginState = kSMAppLoginStatePromptUserToLogin;
        } else {
            _appLoginState = kSMAppLoginStateNoLoginRequired;
        }
        
		
		if (usersManager.currentUser.wasConnected) {
			
			_wantsToConnect = YES;
			
			if (_spreedMeMode) {
				if (usersManager.currentUser.applicationToken.length >0 &&
					usersManager.currentUser.username.length > 0 &&
					usersManager.currentUser.userId.length > 0)
				{
					_appLoginState = kSMAppLoginStateWaitForAutomaticLogin;
					[self reconnectIfNeeded];
				} else {
					_appLoginState = kSMAppLoginStatePromptUserToLogin;
				}
            } else if (_ownCloudMode) {
                if (usersManager.currentUser.username.length > 0 &&
                    usersManager.currentUser.userId.length > 0 &&
                    [SettingsController sharedInstance].lastConnectedOCUserPass &&
                    [SettingsController sharedInstance].lastConnectedOCServer &&
                    [SettingsController sharedInstance].lastConnectedOCSMServer)
                {
                    _appLoginState = kSMAppLoginStateWaitForAutomaticLogin;
                    [self reconnectIfNeeded];
                } else {
                    _appLoginState = kSMAppLoginStatePromptUserToLogin;
                }
            } else {
				[self reconnectIfNeeded];
			}
		}
		
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(userHasResetApplication:)
													 name:UserHasResetApplicationNotification
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationWillResignActive:)
													 name:UIApplicationWillResignActiveNotification
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationDidBecomeActive:)
													 name:UIApplicationDidBecomeActiveNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(networkDataBytesHaveBeenSent:)
													 name:STNetworkDataBytesHaveBeenSentNotification
												   object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(networkDataBytesHaveBeenReceived:)
													 name:STNetworkDataBytesHaveBeenReceivedNotification
												   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(userDidAcceptCertificate:)
                                                     name:UserDidAcceptCertificateNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(userDidRejectCertificate:)
                                                     name:UserDidRejectCertificateNotification
                                                   object:nil];
	}
	
	return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Utilities for User loading

- (SMLocalUser *)loadLastLoggedInUser
{
    NSString *lastConnectedUserId = [[SettingsController sharedInstance].lastConnectedUserId copy];
    return [self loadUserForSavedUserId:lastConnectedUserId];
}


- (SMLocalUser *)loadUserForSavedUserId:(NSString *)userId
{
    if (userId.length == 0) {
        return nil;
    }
    
    UsersManager *usersManager = [UsersManager defaultManager];
    
    NSString *hashedName = [SMHmacHelper sha256Hash:userId];
    NSString *dir = [[usersManager savedUsersDirectory] stringByAppendingPathComponent:hashedName];
    
    return [usersManager loadUserFromDir:dir];
}


#pragma mark - Application Version functionality

- (void)setupAppVersionCheckerPeriodicChecks
{
    [_versionChecker startPeriodicChecksWithInterval:kSMDefaultAppVersionCheckInterval andCompletionBlock:^(NSString *minimalVersion, NSString *newestAvailVersion) {
        
        SMApplicationVersionCheckState versionState = [self checkAppVersionsWithMinimal:minimalVersion newestAvailable:newestAvailVersion];
        switch (versionState) {
            case kSMAVCSOldSupported:
                [_versionChecker notifyUserAboutAvailableUpdateToVersion:newestAvailVersion];
                // FALLTHROUGH!!!
            case kSMAVCSNewestAvailble:
            case kSMAVCSNewDev:
                self.lastAppVersionCheck = [[NSDate date] timeIntervalSince1970];
            break;
                  
            case kSMAVCSTooOldUnsupported:
            {
                self.lastAppVersionCheck = 0.0; // Should check version again next time
                NSString *currentBundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
                [self failDueToTooOldVersion:currentBundleVersion withMinimal:minimalVersion];
            }
            break;
                                  
            case kSMAVCSError:
            default:
                self.lastAppVersionCheck = 0.0; // Should check version again next time
                [self connectionDisconnectedWithReason:kSMDisconnectionReasonFailed];
            break;
        }
    }];
}


- (SMApplicationVersionCheckState)checkAppVersionsWithMinimal:(NSString *)minimal newestAvailable:(NSString *)newestAvail
{
    SMApplicationVersionCheckState state = kSMAVCSError;
    if (!minimal || !newestAvail) {
        spreed_me_log("Error retrieveing app version information!");
        return state;
    }
    
    NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    NSArray *current = SMStringVersionNumberToIntArray(bundleVersion);
    NSArray *min = SMStringVersionNumberToIntArray(minimal);
    NSArray *newest = SMStringVersionNumberToIntArray(newestAvail);
    
    // Check versions only if we have what to check
    if (current.count > 0 && min.count > 0 && newest.count > 0) {
        if (SMCompareVersionArrays(min, current) == NSOrderedDescending) {
            
            state = kSMAVCSTooOldUnsupported;
            spreed_me_log("You can't use the app!!! Current version of the app (%s) is too low. Minimal secure version is (%s)",
                          [bundleVersion cDescription], [minimal cDescription]);
            
        } else if (SMCompareVersionArrays(newest, current) == NSOrderedDescending) {
            
            state = kSMAVCSOldSupported;
            spreed_me_log("You can still use the app but it is better to update current version of the app (%s) to available (%s)",
                          [bundleVersion cDescription], [newestAvail cDescription]);
            
        } else if (SMCompareVersionArrays(newest, current) == NSOrderedSame) {

            state = kSMAVCSNewestAvailble;
            spreed_me_log("You are using the newest app version (%s). Yeay!", [bundleVersion cDescription]);
            
        } else if (SMCompareVersionArrays(newest, current) == NSOrderedAscending){
            
            state = kSMAVCSNewDev;
            spreed_me_log("You are using the development app version (%s).", [bundleVersion cDescription]);
            
        } else {
            spreed_me_log("We have missed all check. Returning kSMAVCSError as something went wrong.");
        }
    }
    
    return state;
}


- (void)failDueToTooOldVersion:(NSString *)currentVersion withMinimal:(NSString *)minimalVersion
{
    NSString *descriptionString = NSLocalizedStringWithDefaultValue(@"description-arg1_unsupported-application-version",
                                                                    nil, [NSBundle mainBundle],
                                                                    @"The current application version %@ is no longer supported. Please update application to the latest version.",
                                                                    @"String to explain user problem with application version. You can move '%@' but do not remove it.");
    descriptionString = [NSString stringWithFormat:descriptionString, currentVersion];
    self.versionCheckFailedString = descriptionString;
    
    self.appHasFailedVersionCheck = YES;
    [self logout];
    [self notifyApplicationVersionCheckHasFailed];
}


- (void)failDueToIncorrectVersion:(NSString *)incorrectCurrentVersion
                      withMinimal:(NSString *)minimalVersion
                  newestAvailable:(NSString *)newestAvail
{
    self.appHasFailedVersionCheck = YES;
    [self logout];
    [self notifyApplicationVersionCheckHasFailed];
}


#pragma mark - Reconnection functionality

- (void)reconnect
{
	[self disconnect];
	[self connectUsingCurrentEndpoints];
}


- (void)reconnectToServerAfterFailure
{
	if (!_tryingToReconnect) {
		[self tryToReconnect:nil];
	} else {
		spreed_me_log("We are already trying to reconnect. No need for one more reconnect call.");
	}
}


- (void)reconnectIfNeeded
{
	BOOL shouldReconnect = NO;
	UIApplicationState appState = [UIApplication sharedApplication].applicationState;
	
	if (_appLoginState != kSMAppLoginStatePromptUserToLogin &&
		_state == kSMConnectionStateInternalDisconnected &&
		
		!self.isConnected &&
		_wantsToConnect &&
		
		[UsersManager defaultManager].currentUser.wasConnected)
	{
		if (appState == UIApplicationStateBackground) { // Just ignore that we are trying to reconnect if we are in background since all timers should be suspended
			_reconnectTime = 0.0; // reset reconnect time for background
		}
		
		shouldReconnect = YES;
		[self tryToReconnect:nil];
	}
	
	spreed_me_log("Reconnect=%s; app in background=%s; connReady=%s; isTryingToReconn=%s; wantsToConnect=%s; _state=%d;",
				  shouldReconnect ? "YES" : "NO",
				  appState == UIApplicationStateBackground ? "YES" : "NO",
				  self.isConnected ? "YES" : "NO",
				  _tryingToReconnect ? "YES" : "NO",
				  _wantsToConnect ? "YES" : "NO",
				  _state);
}


- (void)tryToReconnect:(NSTimer *)theTimer
{
	UIApplication *app = [UIApplication sharedApplication];
	
	UIApplicationState appState = app.applicationState;
	
	if (appState == UIApplicationStateBackground && [UsersManager defaultManager].currentUser.settings.shouldDisconnectOnBackground) {
		spreed_me_log("Trying to reconnect in background with 'Disconnect in background' option enabled. Do not reconnect.");
		return;
	}
	
	// We are waiting until user logs in. There is no reason to reconnect.
	if (_state == kSMConnectionStateInternalWaitingForAppToken) {
		spreed_me_log("We are waiting until user logs in. There is no reason to reconnect.");
		[self stopTryingToReconnect];
		return;
	}
	
	if (_reconnectionBackgroundTaskId == UIBackgroundTaskInvalid) {
		
		_reconnectionBackgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
			// We have run out of background time. Stop reconnecting.
			spreed_me_log("No more background time. Stop trying ot reconnect this time.");
			[self stopTryingToReconnect];
		}];
	}
	
	NSTimeInterval remainingTime = [app backgroundTimeRemaining];
	spreed_me_log("_reconnectionBackgroundTaskId = %lu; Remaining background time %.2f", _reconnectionBackgroundTaskId, remainingTime);
	
	
	if (_wantsToConnect)
	{
		spreed_me_log("Setup reconnect timer with app state %s", (appState == UIApplicationStateActive ? "active" : (appState == UIApplicationStateBackground ? "background" : "inactive")));
		if (_reconnectTime < kMaxReconnectTimeInterval) {
			_reconnectTime += kReconnectTimeOutIncreaseValue;
		}
		
		[self scheduleNextReconnectAttemptAfter:_reconnectTime];
	}
	
	// Start new connection only if we are disconnected
	if (_state == kSMConnectionStateInternalDisconnected) {
	
		_tryingToReconnect = YES;
		[_currentLoginOperation cancel];
		_currentLoginOperation = nil;
		[_channelingManager closeConnection];
		[self connectUsingCurrentEndpoints];
	}
}


- (void)scheduleNextReconnectAttemptAfter:(NSTimeInterval)time
{
	[_reconnectTimer invalidate];
	_reconnectTimer = nil;
	
	spreed_me_log("Scheduling next reconnect attempt after %3.1f seconds", time);
	_reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:time target:self selector:@selector(tryToReconnect:) userInfo:nil repeats:NO];
}


- (void)stopTryingToReconnect
{
	[_currentLoginOperation cancel];
	_currentLoginOperation = nil;
	
	_tryingToReconnect = NO;
	
	_reconnectTime = 0.0;
	
	[_reconnectTimer invalidate];
	_reconnectTimer = nil;
	
	[[UIApplication sharedApplication] endBackgroundTask:_reconnectionBackgroundTaskId];
	_reconnectionBackgroundTaskId = UIBackgroundTaskInvalid;
}


#pragma mark - Connection

// Always should return 4 strings as endpoints in this sequence: ws, REST, image, well-known
- (NSArray *)composeEndpointsURLsWithUserServerString:(NSString *)userServerString
{
    NSMutableArray *endpoints = [NSMutableArray array];
    
    // Check if user has given us scheme.
    NSArray *comp = [userServerString componentsSeparatedByString:@"://"];
    // we check here for exactly 1 component if we have 2 components then we have scheme,
    // if we have 3 or more components then user server string is invalid and will fail later
    if ([comp count] == 1) {
        
        // user has not given us scheme assume secure websocket
        userServerString = [NSString stringWithFormat:@"wss://%@", userServerString];
    }
    
    NSURL *serverURL = [NSURL URLWithString:userServerString];
    
    NSString *host = [serverURL host];
    NSString *scheme = [serverURL scheme];
    NSString *httpScheme = nil;
    NSString *wsScheme = nil;
    
    int serverPort = 0;
    if ([scheme isEqualToString:@"wss"] || [scheme isEqualToString:@"https"] || !scheme) {
        serverPort = [[serverURL port] intValue] != 0 ? [[serverURL port] intValue] : 443;
        wsScheme = @"wss";
        httpScheme = @"https";
    } else if ([scheme isEqualToString:@"ws"] || [scheme isEqualToString:@"http"]) {
        serverPort = [[serverURL port] intValue] != 0 ? [[serverURL port] intValue] : 80;
        wsScheme = @"ws";
        httpScheme = @"http";
    }
    
    BOOL hasTrailingSlash = NO;
    if ([[serverURL absoluteString] hasSuffix:@"/"]) {
        hasTrailingSlash = YES;
    }
    
    NSString *path = [serverURL path];
    
    NSString *webSocketEndpoint = [NSString stringWithFormat:@"%@://%@:%d%@", wsScheme, host, serverPort, [path stringByAppendingPathComponent:kWebSocketEndpoint]];
    NSString *RESTAPIEndpoint = [NSString stringWithFormat:@"%@://%@:%d%@", httpScheme, host, serverPort, [path stringByAppendingPathComponent:kRESTAPIEndpoint]];
    NSString *imagesEndpoint =  [NSString stringWithFormat:@"%@://%@:%d%@", httpScheme, host, serverPort, [path stringByAppendingPathComponent:kImagesEndpoint]];
    NSString *wellKnownEndpoint =  [NSString stringWithFormat:@"%@://%@:%d%@", httpScheme, host, serverPort, kWellKnownEndpoint];
    
    [endpoints addObject:webSocketEndpoint];
    [endpoints addObject:RESTAPIEndpoint];
    [endpoints addObject:imagesEndpoint];
    [endpoints addObject:wellKnownEndpoint];
    
    return [NSArray arrayWithArray:endpoints];
}


- (void)refreshEndpointsURLsWithUserServerString:(NSString *)userServerString
{
	_currentServer = userServerString;
	
    NSArray *endpoints = [self composeEndpointsURLsWithUserServerString:userServerString];
	
    _currentWebSocketEndpoint = endpoints[0];
	_currentRESTAPIEndpoint = endpoints[1];
	_currentImagesEndpoint =  endpoints[2];
    _currentWellKnownEndpoint =  endpoints[3];
}


- (void)refreshEndpointsURLsWithOwnCloudServerString:(NSString *)ownCloudServerString andSpreedMeServerString:(NSString *)spreedMEServerString
{
    _currentServer = ownCloudServerString;
    
    NSArray *ownCloudEndpoints = [self composeEndpointsURLsWithUserServerString:ownCloudServerString];
    
    _currentOwnCloudServer = ownCloudServerString;
    _currentOwnCloudRESTAPIEndpoint = ownCloudEndpoints[1];
    _currentWellKnownEndpoint =  ownCloudEndpoints[3];
    
    NSArray *spreedMeEndpoints = [self composeEndpointsURLsWithUserServerString:spreedMEServerString];
    
    _currentWebSocketEndpoint = spreedMeEndpoints[0];
    _currentRESTAPIEndpoint = spreedMeEndpoints[1];
    _currentImagesEndpoint =  spreedMeEndpoints[2];
    
    [[SettingsController sharedInstance] discoverServicesFromServer:_currentWellKnownEndpoint withCompletionBlock:^(NSError *error) {
        if (!error) {
            spreed_me_log("Discovered services while refreshing endpoints.");
        } else {
            spreed_me_log("No services discovered while refreshing endpoints.");
        }
    }];
    
}


- (void)disconnect
{
	[self disconnectWithInactivityReason:kSMDisconnectionReasonClosedByUser];
}


- (void)disconnectWithInactivityReason:(SMDisconnectionReason)disconnectionReason
{
	[self stopTryingToReconnect];
	
	if (disconnectionReason == kSMDisconnectionReasonClosedByUser) {
		[UsersManager defaultManager].currentUser.wasConnected = NO;
        [self notifyConnectionHasChangedState:kSMConnectionStateDisconnected];
	}
	
	[self connectionDisconnectedWithReason:disconnectionReason];
}


- (void)connectionDisconnectedWithReason:(SMDisconnectionReason)disconnectionReason
{
	[_channelingManager closeConnection];

	// 1. first notify login failure since we make use of '_lastLoginFailReason'
	[self connectionHasBecomeInactiveWithReason:disconnectionReason];
	// 2. set it to default state after notification
	_lastLoginFailReason = kSMLoginFailReasonNotFailed;
	_state = kSMConnectionStateInternalDisconnected;
}


- (void)reconnectToCurrentServer
{
	[self disconnectWithInactivityReason:kSMDisconnectionReasonClosedByUser];
	[self stopTryingToReconnect];
	[self connectUsingCurrentEndpoints];
}


- (void)connectToNewServer:(NSString *)newServer
{
    _ownCloudMode = NO;
	
    [UsersManager defaultManager].currentUser = [[SMLocalUser alloc] init];
	[UsersManager defaultManager].currentUser.settings.serverString = newServer;
    [UsersManager defaultManager].currentUser.room = nil;
	
	// if new server string is empty stop connecting
	if ([newServer length] <= 0) {
		_currentServer = nil;
		_wantsToConnect = NO;
		[UsersManager defaultManager].currentUser.sessionToken = nil;
		self.lastServerVersion = nil;
		[self disconnect];
		
		return;
	}
	
	// refresh API endpoints with new server
	[self refreshEndpointsURLsWithUserServerString:newServer];

	// stop previous reconnects and clean up server url related stuff
	[self stopTryingToReconnect];
	self.lastServerVersion = nil;
	[_channelingManager closeConnection];
    
	NSString *lastHost = [[NSURL URLWithString:self.currentWebSocketEndpoint] host];
	NSString *newHost = [[NSURL URLWithString:newServer] host];
	if (![lastHost isEqualToString:newHost]){
		[[ReachabilityManager sharedInstance] removeReachabilityWithHostName:lastHost];
	}
    
    [[SettingsController sharedInstance] discoverServicesFromServer:[_currentWellKnownEndpoint copy] withCompletionBlock:^(NSError *error) {
        if (!error) {
            spreed_me_log("Discovered services while connecting to new server: %s", [_currentWellKnownEndpoint cDescription]);
        } else {
            spreed_me_log("No services discovered while connecting to new server: %s", [_currentWellKnownEndpoint cDescription]);
        }
        
        [self connectUsingCurrentEndpoints];
    }];
}


- (void)connectToOwnCloudService:(NSString *)ownCloudServer withSpreedMEService:(NSString *)spreedMEServer
{
    [UsersManager defaultManager].currentUser.settings.serverString = ownCloudServer;
    
    // if new server string is empty stop connecting
    if ([ownCloudServer length] <= 0) {
        _currentServer = nil;
        _wantsToConnect = NO;
        [UsersManager defaultManager].currentUser.sessionToken = nil;
        self.lastServerVersion = nil;
        [self disconnect];
        
        return;
    }
    
    _ownCloudMode = YES;
    _currentOwnCloudServer = ownCloudServer;
    [SettingsController sharedInstance].ownCloudMode = YES;
    [SettingsController sharedInstance].lastConnectedOCServer = ownCloudServer;
    [SettingsController sharedInstance].lastConnectedOCSMServer = spreedMEServer;
    
    [[UsersManager defaultManager] saveCurrentUser];
    
    // refresh API endpoints with new server
    [self refreshEndpointsURLsWithOwnCloudServerString:ownCloudServer andSpreedMeServerString:spreedMEServer];
    
    // stop previous reconnects and clean up server url related stuff
    [self stopTryingToReconnect];
    self.lastServerVersion = nil;
    [_channelingManager closeConnection];
    NSString *lastHost = [[NSURL URLWithString:self.currentWebSocketEndpoint] host];
    NSString *newHost = [[NSURL URLWithString:ownCloudServer] host];
    if (![lastHost isEqualToString:newHost]){
        [[ReachabilityManager sharedInstance] removeReachabilityWithHostName:lastHost];
    }
    
    //Check for the Spreed.ME service server config first. Maybe we need to accept another certificate before presenting Login screen.
    NSString *serverConfigString = [_currentRESTAPIEndpoint stringByAppendingString:kServerConfigEndpoint];
    [[SettingsController sharedInstance] getServerConfigWithServer:serverConfigString withCompletionBlock:^(NSError *error) {
        if (!error) {
            [self connectUsingCurrentEndpoints];
        } else {
            NSLog(@"Error getting Spreed.ME service server configuration");
        }
    }];
}


- (void)connectToOwnCloudService:(NSString *)ownCloudServer withSpreedMEService:(NSString *)spreedMEServer username:(NSString *)username password:(NSString *)password
{
    [UsersManager defaultManager].currentUser.settings.serverString = ownCloudServer;
    
    // if new server string is empty stop connecting
    if ([ownCloudServer length] <= 0) {
        _currentServer = nil;
        _wantsToConnect = NO;
        [UsersManager defaultManager].currentUser.sessionToken = nil;
        self.lastServerVersion = nil;
        [self disconnect];
        
        return;
    }
    
    _ownCloudMode = YES;
    _currentOwnCloudServer = ownCloudServer;
    [SettingsController sharedInstance].ownCloudMode = YES;
    [SettingsController sharedInstance].lastConnectedOCServer = ownCloudServer;
    [SettingsController sharedInstance].lastConnectedOCSMServer = spreedMEServer;
    
    [[UsersManager defaultManager] saveCurrentUser];
    
    // refresh API endpoints with new server
    [self refreshEndpointsURLsWithOwnCloudServerString:ownCloudServer andSpreedMeServerString:spreedMEServer];
    
    // stop previous reconnects and clean up server url related stuff
    [self stopTryingToReconnect];
    self.lastServerVersion = nil;
    [_channelingManager closeConnection];
    NSString *lastHost = [[NSURL URLWithString:self.currentWebSocketEndpoint] host];
    NSString *newHost = [[NSURL URLWithString:ownCloudServer] host];
    if (![lastHost isEqualToString:newHost]){
        [[ReachabilityManager sharedInstance] removeReachabilityWithHostName:lastHost];
    }
    
    [[SMConnectionController sharedInstance] loginOCWithUsername:username password:password serverEndpoint:[SMConnectionController sharedInstance].currentOwnCloudRESTAPIEndpoint];
}


- (void)presentLoginScreenToGetSpreedMEConfigurationInOwnCloudServer:(NSString *)ownCloudServer
{
    _ownCloudMode = YES;
    _ownCloudAppNotEnabled = YES;
    _currentOwnCloudServer = ownCloudServer;
    self.appLoginState = kSMAppLoginStatePromptUserToLogin;
}


- (void)connectUsingCurrentEndpoints
{
	if (_spreedMeMode) {
		if ([UsersManager defaultManager].currentUser.sessionToken ||
			[UsersManager defaultManager].currentUser.applicationToken) {
			self.appLoginState = kSMAppLoginStateWaitForAutomaticLogin;
		} else {
			self.appLoginState = kSMAppLoginStatePromptUserToLogin;
		}
		
		[self connectUsingCurrentEndpointsInSpreedMeMode];
    } else if (_ownCloudMode) {
        if ([SettingsController sharedInstance].lastConnectedUserId &&
            [SettingsController sharedInstance].lastConnectedOCUserPass) {
            spreed_me_log("Reconnecting to OwnCloud server with saved credentials");
            self.appLoginState = kSMAppLoginStateWaitForAutomaticLogin;
        } else {
            self.appLoginState = kSMAppLoginStatePromptUserToLogin;
        }
        
        [self connectUsingCurrentEndpointsInOwnCloudMode];
    }else {
		self.appLoginState = kSMAppLoginStateNoLoginRequired;
		[self connectUsingCurrentEndpointsInNonSpreedMeMode];
	}
    
    [self notifyConnectionHasChangedState:kSMConnectionStateConnecting];
}


- (void)connectOCModeWithSessionToken:(NSString *)serverConfigString
{
    // if we have sessionToken it means we have already went through login process and now we need only to reconnect
    self.appLoginState = kSMAppLoginStateWaitForAutomaticLogin;
    _currentLoginOperation = [[SettingsController sharedInstance] getServerConfigWithServer:serverConfigString withCompletionBlock:^(NSError *error) {
        if (!error) {
            if (_state == kSMConnectionStateInternalWaitingForServerConfig) {
                _state = kSMConnectionStateInternalWaitingForAuthorizedSelf;
                [_channelingManager connectToServer:[_currentWebSocketEndpoint copy] withToken:[UsersManager defaultManager].currentUser.sessionToken];
            } else {
                spreed_me_log("ERROR STATE!");
                [self connectionDisconnectedWithReason:kSMDisconnectionReasonFailed];
            }
        } else {
            // This can be annoying for user who denies certificate untrusted certificate as it will try to reconnect,
            // which means that certificate proposal would popup all the time.
            [self connectionDisconnectedWithReason:kSMDisconnectionReasonFailed];
        }
    }];
}


- (void)connectSMModeWithSessionToken:(NSString *)serverConfigString
{
    // if we have sessionToken it means we have already went through login process and now we need only to reconnect
    self.appLoginState = kSMAppLoginStateWaitForAutomaticLogin;
    _currentLoginOperation = [[SettingsController sharedInstance] getServerConfigWithServer:serverConfigString withCompletionBlock:^(NSError *error) {
        if (!error) {
            if (_state == kSMConnectionStateInternalWaitingForServerConfig) {
                _state = kSMConnectionStateInternalWaitingForAuthorizedSelf;
                [_channelingManager connectToServer:[_currentWebSocketEndpoint copy] withToken:[UsersManager defaultManager].currentUser.sessionToken];
            } else {
                spreed_me_log("ERROR STATE!");
                [self connectionDisconnectedWithReason:kSMDisconnectionReasonFailed];
            }
        } else {
            // This can be annoying for user who denies certificate untrusted certificate as it will try to reconnect,
            // which means that certificate proposal would popup all the time.
            [self connectionDisconnectedWithReason:kSMDisconnectionReasonFailed];
        }
    }];
}


- (void)connectSMModeWithApplicationToken:(NSString *)serverConfigString
{
    _currentLoginOperation = [[SettingsController sharedInstance] getServerConfigWithServer:serverConfigString withCompletionBlock:^(NSError *error) {
        if (!error) {
            if (_state == kSMConnectionStateInternalWaitingForServerConfig) {
                _state = kSMConnectionStateInternalWaitingForRefreshedUserComboAndSecret;
                self.appLoginState = kSMAppLoginStateWaitForAutomaticLogin;
                
                _currentLoginOperation = [[SMLoginManager sharedInstance]
                                          refreshUserComboAndSecretWithAppToken:[UsersManager defaultManager].currentUser.applicationToken
                                          clientId:[SMAppIdentityController sharedInstance].clientId
                                          clientSecret:[SMAppIdentityController sharedInstance].clientSecret
                                          completionBlock:^(NSDictionary *jsonResponse, NSError *error) {
                                              if (jsonResponse && !error) {
                                                  NSString *userCombo = [jsonResponse objectForKey:NSStr(kLCUserComboKey)];
                                                  NSString *secret = [jsonResponse objectForKey:NSStr(kLCSecretKey)];
                                                  
                                                  UsersManager *defaultUserManager = [UsersManager defaultManager];
                                                  
                                                  defaultUserManager.currentUser.lastUserIdCombo = userCombo;
                                                  defaultUserManager.currentUser.lastUserIdComboSecret = secret;
                                                  NSArray *userIdComboComponents = [userCombo componentsSeparatedByString:@":"];
                                                  if (userIdComboComponents.count == 3) {
                                                      NSString *userId = [userIdComboComponents objectAtIndex:1];
                                                      if (![defaultUserManager.currentUser.userId isEqualToString:userId]){
                                                          spreed_me_log("incorrect userIdCombo!!!");
                                                          [self userFailedToLoginWithReason:kSMLoginFailReasonIncorrectUserIdWithAuthorizedSelf];
                                                      } else {
                                                          _state = kSMConnectionStateInternalWaitingForSelf;
                                                          [_channelingManager connectToServer:[_currentWebSocketEndpoint copy]
                                                                                    withToken:nil];
                                                      }
                                                  }
                                              } else if (jsonResponse) {
                                                  BOOL success = [[jsonResponse objectForKey:NSStr(kLCSuccessKey)] boolValue];
                                                  if (!success) {
                                                      
                                                      NSString *code = [jsonResponse objectForKey:NSStr(kLCCodeKey)];
                                                      if ([code isEqualToString:@"failed"]) {
                                                          [self userFailedToLoginWithReason:kSMLoginFailReasonCouldNotRefreshToken];
                                                      } else if ([code isEqualToString:@"expired"]) {
                                                          [self userFailedToLoginWithReason:kSMLoginFailReasonAppTokenExpired];
                                                      } else {
                                                          [self userFailedToLoginWithReason:kSMLoginFailReasonNetworkFailure];
                                                      }
                                                      
                                                  } else {
                                                      spreed_me_log("Error success==true while request failed!");
                                                      [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                                  }
                                                  
                                              } else {
                                                  [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                              }
                                          }];
            } else {
                spreed_me_log("ERROR STATE!");
                [self connectionDisconnectedWithReason:kSMDisconnectionReasonFailed];
            }
        } else {
            // This can be annoying for user who denies certificate untrusted certificate as it will try to reconnect,
            // which means that certificate proposal would popup all the time.
            [self connectionDisconnectedWithReason:kSMDisconnectionReasonFailed];
        }
    }];
}


- (void)connectUsingCurrentEndopointsInSpreedMeModeInternal
{
    _state = kSMConnectionStateInternalWaitingForServerConfig;
    _wantsToConnect = YES;
    
    NSString *serverConfigString = [_currentRESTAPIEndpoint stringByAppendingString:kServerConfigEndpoint];
    
    if ([UsersManager defaultManager].currentUser.sessionToken) {
        
        [self connectSMModeWithSessionToken:serverConfigString];
        
    } else {
        if ([UsersManager defaultManager].currentUser.applicationToken) {
            
            [self connectSMModeWithApplicationToken:serverConfigString];
            
        } else {
            _state = kSMConnectionStateInternalWaitingForAppToken;
            self.appLoginState = kSMAppLoginStatePromptUserToLogin;
            [self disconnect];
        }
    }
}


- (void)connectUsingCurrentEndpointsInSpreedMeMode
{
    if (fabs(self.lastAppVersionCheck - [[[NSDate alloc]init] timeIntervalSince1970]) > kSMDefaultAppVersionCheckInterval) {
        
        self.lastAppVersionCheck = [[[NSDate alloc]init] timeIntervalSince1970];
        
        [_versionChecker getApplicationInformationVersionWithComplBlock:^(NSString *minimalVersion, NSString *newestAvailVersion) {
            
            SMApplicationVersionCheckState versionState = [self checkAppVersionsWithMinimal:minimalVersion newestAvailable:newestAvailVersion];
            switch (versionState) {
                case kSMAVCSOldSupported:
                    
                    [_versionChecker notifyUserAboutAvailableUpdateToVersion:newestAvailVersion];
                    // FALLTHROUGH!!!
                    
                case kSMAVCSNewestAvailble:
                case kSMAVCSNewDev:
                    self.appHasFailedVersionCheck = NO;
                    [self connectUsingCurrentEndopointsInSpreedMeModeInternal];
                break;
                    
                case kSMAVCSTooOldUnsupported:
                {
                    self.lastAppVersionCheck = 0.0; // Should check version again next time
                    NSString *currentBundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
                    [self failDueToTooOldVersion:currentBundleVersion withMinimal:minimalVersion];
                }
                break;
                
                case kSMAVCSError:
                default:
                    self.appHasFailedVersionCheck = NO;
                    self.lastAppVersionCheck = 0.0; // Should check version again next time
                    [self connectionDisconnectedWithReason:kSMDisconnectionReasonFailed];
                break;
            }
        }];
    
    } else {
        [self connectUsingCurrentEndopointsInSpreedMeModeInternal];
    }
}


- (void)connectUsingCurrentEndpointsInNonSpreedMeMode
{
	_state = kSMConnectionStateInternalWaitingForServerConfig;
	
	_wantsToConnect = YES;
	
	NSURL *serverURL = [NSURL URLWithString:_currentWebSocketEndpoint];
	NSString *host = [[serverURL host] lowercaseString];
	
	//TODO: Maybe remove dev.spreed.me from allowed hosts for non spreed me mode.
	if (!_spreedMeMode && ([host hasSuffix:@"spreed.me"] && ![host hasSuffix:@"dev.spreed.me"])) {
		
		NSString *alertMessage = NSLocalizedStringWithDefaultValue(@"message_body_connect-to-spreed-me-in-own-spreed-mode",
																   nil, [NSBundle mainBundle],
																   @"It seems you are trying to connect to spreed.me server while you are not in spreed me mode. If you want to connect to spreed.me server please select spreed me mode.",
																   @"Explanation that user cannot connect to spreed.me server in ownSpreed mode");
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
														message:alertMessage
													   delegate:nil
											  cancelButtonTitle:kSMLocalStringSadOKButton
											  otherButtonTitles:nil];
		[alert show];
		
		_wantsToConnect = NO;
		
		[self disconnect];
		
		return;
	}
	
	NSString *serverConfigString = [_currentRESTAPIEndpoint stringByAppendingString:kServerConfigEndpoint];
	
	[[SettingsController sharedInstance] getServerConfigWithServer:serverConfigString withCompletionBlock:^(NSError *error) {
		if (!error) {
			
			if (_state == kSMConnectionStateInternalWaitingForServerConfig) {
				_state = kSMConnectionStateInternalWaitingForSelf;
			} else {
				spreed_me_log("ERROR STATE!");
			}
			
			[_channelingManager connectToServer:[_currentWebSocketEndpoint copy] withToken:[UsersManager defaultManager].currentUser.sessionToken];
			
		} else {
			// This can be annoying for user who denies certificate untrusted certificate as it will try to reconnect,
			// which means that certificate proposal would popup all the time.
            if (error.code == 101 || error.code == -1012) {
                NSLog(@"Error trying to get server configuration.");
                [self disconnect];
            } else {
                [self connectionDisconnectedWithReason:kSMDisconnectionReasonFailed];
            }
		}
	}];
}


- (void)connectUsingCurrentEndpointsInOwnCloudMode
{
    _state = kSMConnectionStateInternalWaitingForServerConfig;
    _wantsToConnect = YES;
    
    NSString *serverConfigString = [_currentRESTAPIEndpoint stringByAppendingString:kServerConfigEndpoint];
    
    if ([UsersManager defaultManager].currentUser.sessionToken) {
        
        [self connectOCModeWithSessionToken:serverConfigString];
        
    } else if ([SettingsController sharedInstance].lastConnectedUserId &&
               [SettingsController sharedInstance].lastConnectedOCUserPass &&
               [SettingsController sharedInstance].lastConnectedOCServer &&
               [SettingsController sharedInstance].lastConnectedOCSMServer) {
        [self loginOCWithUsername:[SettingsController sharedInstance].lastConnectedUserId password:[SettingsController sharedInstance].lastConnectedOCUserPass serverEndpoint:_currentOwnCloudRESTAPIEndpoint];
    } else {
        self.appLoginState = kSMAppLoginStatePromptUserToLogin;
        [self disconnect];
    }
}


- (BOOL)shouldReconnectBecauseOfServerVersionHasChangedFrom:(NSString *)oldVersion to:(NSString *)newVersion
{
	BOOL answer = NO;
	
	if ([oldVersion length] > 0) {
		if (![oldVersion isEqualToString:newVersion]) {
			// server has changed version
			self.lastServerVersion = newVersion;
			answer = YES;
		} else {
			// it is the same version. Do nothing
		}
	} else {
		// this is first version setting. just set new serverVersion
		self.lastServerVersion = newVersion;
	}
	
	return answer;
}


- (void)userFailedToLoginWithReason:(SMLoginFailReason)failReason
{
	// 1. Set last fail reason to be picked up by notification's user info in 'disconnectWithInactivityReason'
	self.lastLoginFailReason = failReason;
	
	// If token expired or userId is incorrect, delete appToken from current local user in order to
	// prompt login again.
	if (failReason == kSMLoginFailReasonAppTokenExpired ||
		failReason == kSMLoginFailReasonCouldNotRefreshToken ||
		failReason == kSMLoginFailReasonIncorrectUserIdWithAuthorizedSelf) {
		[UsersManager defaultManager].currentUser.applicationToken = nil;
		[UsersManager defaultManager].currentUser.userId = nil;
		[[UsersManager defaultManager] saveCurrentUser];
	}
	
	// 2. Set app state so we present user login screen
	self.appLoginState = kSMAppLoginStatePromptUserToLogin;
	// 3. Disconnect with reason 'kSMDisconnectionReasonUserFailedToLogin' to present user reason why login has failed
	[self disconnectWithInactivityReason:kSMDisconnectionReasonUserFailedToLogin];
}


#pragma mark - Login / logout

- (void)loginWithUsername:(NSString *)username password:(NSString *)password
{
	if (username.length == 0 || password.length == 0) {
		[self userFailedToLoginWithReason:kSMLoginFailReasonIncorrectUserNameOrPassword];
        return;
	}
	
	[self stopTryingToReconnect];

	_state = kSMConnectionStateInternalWaitingForAppToken;
	
	[UsersManager defaultManager].currentUser.username = username;
    
    NSString *serverConfigString = [_currentRESTAPIEndpoint stringByAppendingString:kServerConfigEndpoint];
    _currentLoginOperation = [[SettingsController sharedInstance] getServerConfigWithServer:serverConfigString withCompletionBlock:^(NSError *error) {
        if (!error) {
            _currentLoginOperation = [[SMLoginManager sharedInstance]
                                      getUserComboUsername:username
                                      password:password
                                      clientId:[SMAppIdentityController sharedInstance].clientId
                                      clientSecret:[SMAppIdentityController sharedInstance].clientSecret
                                      completionBlock:^(NSDictionary *jsonResponse, NSError *error) {
                                          
                                          if (jsonResponse && !error) {
                                              
                                              BOOL success = [[jsonResponse objectForKey:NSStr(kLCSuccessKey)] boolValue];
                                              if (success) {
                                                  NSString *accessToken = [jsonResponse objectForKey:NSStr(kLCAccess_TokenKey)];
                                                  NSString *userCombo = [jsonResponse objectForKey:NSStr(kLCUserComboKey)];
                                                  NSString *secret = [jsonResponse objectForKey:NSStr(kLCSecretKey)];
                                                  
                                                  UsersManager *defaultUserManager = [UsersManager defaultManager];
                                                  
                                                  defaultUserManager.currentUser.lastUserIdCombo = userCombo;
                                                  defaultUserManager.currentUser.lastUserIdComboSecret = secret;
                                                  NSArray *userIdComboComponents = [userCombo componentsSeparatedByString:@":"];
                                                  if (userIdComboComponents.count == 3) {
                                                      defaultUserManager.currentUser.userId = [userIdComboComponents objectAtIndex:1];
                                                      if (defaultUserManager.currentUser.userId.length > 0) {
                                                          //Try to load user with this id
                                                          NSString *hashedName = [SMHmacHelper sha256Hash:defaultUserManager.currentUser.userId];
                                                          NSString *dir = [[defaultUserManager savedUsersDirectory] stringByAppendingPathComponent:hashedName];
                                                          SMLocalUser *savedUser = [[UsersManager defaultManager] loadUserFromDir:dir];
                                                          // if we have user with such Id we should grab settings from it
                                                          // but not appToken, combo, secret or sessionToken
                                                          if (savedUser) {
                                                              defaultUserManager.currentUser.displayName = savedUser.displayName;
                                                              defaultUserManager.currentUser.iconImage = savedUser.iconImage;
                                                              defaultUserManager.currentUser.statusMessage = savedUser.statusMessage;
                                                              defaultUserManager.currentUser.base64Image = savedUser.base64Image;
                                                              defaultUserManager.currentUser.room = savedUser.room;
                                                              defaultUserManager.currentUser.roomsList = savedUser.roomsList;
                                                              defaultUserManager.currentUser.Ua = savedUser.Ua;
                                                              defaultUserManager.currentUser.settings = savedUser.settings;
                                                          } else {
                                                              // If there is no saved user we need to add a room with user name as name
                                                              SMRoom *userNameRoom = [SMRoom new];
                                                              userNameRoom.name = username;
                                                              userNameRoom.displayName = username;
                                                              NSMutableArray *roomsList = [NSMutableArray new];
                                                              if ([[[SettingsController sharedInstance].serverConfig objectForKey:kServerConfigDefaultRoomEnabledKey] boolValue]) {
                                                                  [roomsList addObject:[SMRoom defaultRoomInstance]];
                                                              }
                                                              [roomsList addObject:userNameRoom];
                                                              defaultUserManager.currentUser.roomsList = roomsList;
                                                              defaultUserManager.currentUser.room = userNameRoom;
                                                              // Since we create rooms artificially we need to add them to visited list manually
                                                              [defaultUserManager addVisitedRoom:defaultUserManager.currentUser.room.name];
                                                          }
                                                      } else {
                                                          spreed_me_log("UserId length is zero. This is error!");
                                                          [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                                          return;
                                                      }
                                                  } else {
                                                      spreed_me_log("incorrect userIdCombo!!!");
                                                      [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                                      return;
                                                  }
                                                  
                                                  _currentLoginOperation = [[SMLoginManager sharedInstance] getAppTokenWithAccessToken:accessToken
                                                                                                                         applicationId:[SMAppIdentityController sharedInstance].applicationId
                                                                                                                       applicationName:[SMAppIdentityController sharedInstance].applicationName
                                                                                                                              clientId:[SMAppIdentityController sharedInstance].clientId
                                                                                                                          clientSecret:[SMAppIdentityController sharedInstance].clientSecret
                                                                                                                       completionBlock:^(NSDictionary *jsonResponse, NSError *error) {
                                                                                                                           
                                                                                                                           if (jsonResponse && !error) {
                                                                                                                               BOOL success = [[jsonResponse objectForKey:NSStr(kLCSuccessKey)] boolValue];
                                                                                                                               if (success) {
                                                                                                                                   NSString *appToken = [jsonResponse objectForKey:NSStr(kLCApplication_TokenKey)];
                                                                                                                                   [UsersManager defaultManager].currentUser.applicationToken = appToken;
                                                                                                                                   _state = kSMConnectionStateInternalWaitingForSelf;
                                                                                                                                   [_channelingManager closeConnection];
                                                                                                                                   [_channelingManager connectToServer:_currentWebSocketEndpoint withToken:nil];
                                                                                                                               }
                                                                                                                           } else if (jsonResponse) {
                                                                                                                               BOOL success = [[jsonResponse objectForKey:NSStr(kLCSuccessKey)] boolValue];
                                                                                                                               if (!success) {
                                                                                                                                   
                                                                                                                                   NSString *code = [jsonResponse objectForKey:NSStr(kLCCodeKey)];
                                                                                                                                   if ([code isEqualToString:@"failed"]) {
                                                                                                                                       [self userFailedToLoginWithReason:kSMLoginFailReasonIncorrectUserNameOrPassword];
                                                                                                                                   } else if ([code isEqualToString:@"expired"]) {
                                                                                                                                       [self userFailedToLoginWithReason:kSMLoginFailReasonAppTokenExpired];
                                                                                                                                   } else {
                                                                                                                                       [self userFailedToLoginWithReason:kSMLoginFailReasonNetworkFailure];
                                                                                                                                   }
                                                                                                                                   
                                                                                                                               } else {
                                                                                                                                   spreed_me_log("Error success==true while request failed!");
                                                                                                                                   [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                                                                                                               }
                                                                                                                               
                                                                                                                           } else {
                                                                                                                               [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                                                                                                           }
                                                                                                                       }];
                                                  
                                              } else {
                                                  spreed_me_log("Error success==false while request has succeded!");
                                                  [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                              }
                                          } else if (jsonResponse) {
                                              BOOL success = [[jsonResponse objectForKey:NSStr(kLCSuccessKey)] boolValue];
                                              if (!success) {
                                                  
                                                  NSString *code = [jsonResponse objectForKey:NSStr(kLCCodeKey)];
                                                  if ([code isEqualToString:@"failed"]) {
                                                      [self userFailedToLoginWithReason:kSMLoginFailReasonIncorrectUserNameOrPassword];
                                                  } else {
                                                      [self userFailedToLoginWithReason:kSMLoginFailReasonNetworkFailure];
                                                  }
                                                  
                                              } else {
                                                  spreed_me_log("Error success==true while request failed!");
                                                  [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                              }
                                              
                                          } else {
                                              [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                          }
                                      }];
        } else {
            [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
        }
    }];
}


- (void)logout
{
	if (_spreedMeMode) {
		[self disconnect];
		[SettingsController sharedInstance].lastConnectedUserId = nil;
		[UsersManager defaultManager].currentUser = [[SMLocalUser alloc] init];
		[UsersManager defaultManager].currentUser.room = nil;
        [[UsersActivityController sharedInstance] purgeAllHistory];
		self.appLoginState = kSMAppLoginStatePromptUserToLogin;
		
		// go to rooms view controller
		[[UserInterfaceManager sharedInstance] presentRoomsViewController];
	}
}


#pragma mark - Login Owncloud

- (void)loginOCWithUsername:(NSString *)username password:(NSString *)password serverEndpoint:(NSString *)serverRESTAPIEndpoint
{
    if (username.length == 0 || password.length == 0) {
        [self userFailedToLoginWithReason:kSMLoginFailReasonIncorrectUserNameOrPassword];
        return;
    }
    
    [self stopTryingToReconnect];
    
    _state = kSMConnectionStateInternalWaitingForAppToken;
    
    [self refreshEndpointsURLsWithOwnCloudServerString:[SettingsController sharedInstance].lastConnectedOCServer andSpreedMeServerString:[SettingsController sharedInstance].lastConnectedOCSMServer];
    
    NSDictionary *services = [[SettingsController sharedInstance] servicesConfig];
    NSString *authEndpoint = nil;
    
    if (services) {
        authEndpoint = [services objectForKey:kServiceConfigAuthorizationEndpointKey];
    }
    
    [UsersManager defaultManager].currentUser.username = username;
    
    _currentLoginOperation = [[OCLoginManager sharedInstance]
                              getUserComboUsername:username
                              password:password serverEndpoint:serverRESTAPIEndpoint
                              completionBlock:^(NSDictionary *jsonResponse, NSError *error) {
                                  
                                  if (jsonResponse && !error) {
                                      
                                      BOOL success = [[jsonResponse objectForKey:NSStr(kLCSuccessKey)] boolValue];
                                      if (success) {
                                          NSString *userIdCombo = [jsonResponse objectForKey:NSStr(kLCUserIdComboKey)];
                                          NSString *secret = [jsonResponse objectForKey:NSStr(kLCSecretKey)];
                                          UsersManager *defaultUserManager = [UsersManager defaultManager];
                                          defaultUserManager.currentUser.lastUserIdCombo = userIdCombo;
                                          defaultUserManager.currentUser.lastUserIdComboSecret = secret;
                                          
                                          NSArray *userIdComboComponents = [userIdCombo componentsSeparatedByString:@":"];
                                          if (userIdComboComponents.count >= 2) {
                                              defaultUserManager.currentUser.userId = [userIdComboComponents objectAtIndex:1];
                                              if (defaultUserManager.currentUser.userId.length > 0) {
                                                  //Try to load user with this id
                                                  NSString *hashedName = [SMHmacHelper sha256Hash:defaultUserManager.currentUser.userId];
                                                  NSString *dir = [[defaultUserManager savedUsersDirectory] stringByAppendingPathComponent:hashedName];
                                                  SMLocalUser *savedUser = [[UsersManager defaultManager] loadUserFromDir:dir];
                                                  // if we have user with such Id we should grab settings from it
                                                  // but not appToken, combo, secret or sessionToken
                                                  if (savedUser) {
                                                      defaultUserManager.currentUser.displayName = savedUser.displayName;
                                                      defaultUserManager.currentUser.iconImage = savedUser.iconImage;
                                                      defaultUserManager.currentUser.statusMessage = savedUser.statusMessage;
                                                      defaultUserManager.currentUser.base64Image = savedUser.base64Image;
                                                      defaultUserManager.currentUser.room = savedUser.room;
                                                      defaultUserManager.currentUser.roomsList = savedUser.roomsList;
                                                      defaultUserManager.currentUser.Ua = savedUser.Ua;
                                                      defaultUserManager.currentUser.settings = savedUser.settings;
                                                  } else {
                                                      SMRoom *defaultRoom = [SMRoom defaultRoomInstance];
                                                      NSMutableArray *roomsList = [NSMutableArray new];
                                                      if ([[[SettingsController sharedInstance].serverConfig objectForKey:kServerConfigDefaultRoomEnabledKey] boolValue]) {
                                                          [roomsList addObject:defaultRoom];
                                                          defaultUserManager.currentUser.room = defaultRoom;
                                                          // Since we create rooms artificially we need to add them to visited list manually
                                                          [defaultUserManager addVisitedRoom:defaultUserManager.currentUser.room.name];
                                                      }
                                                      defaultUserManager.currentUser.roomsList = roomsList;
                                                  }
                                                  
                                                  _currentLoginOperation = [[OCLoginManager sharedInstance]
                                                                            getUserConfigUsername:username
                                                                            password:password serverEndpoint:serverRESTAPIEndpoint
                                                                            completionBlock:^(NSDictionary *jsonResponse, NSError *error) {
                                                                                
                                                                                if (jsonResponse && !error) {
                                                                                    
                                                                                    BOOL success = [[jsonResponse objectForKey:NSStr(kLCSuccessKey)] boolValue];
                                                                                    if (success) {
                                                                                        NSString *displayName = [jsonResponse objectForKey:NSStr(kOCDisplayNameKey)];
                                                                                        [UsersManager defaultManager].currentUser.displayName = displayName;
                                                                                        BOOL isAdmin = [[jsonResponse objectForKey:NSStr(kOCIsAdminKey)] boolValue];
                                                                                        [UsersManager defaultManager].currentUser.isAdmin = isAdmin;
                                                                                        BOOL isSpreedMeAdmin = [[jsonResponse objectForKey:NSStr(kOCIsSpreedMEAdminKey)] boolValue];
                                                                                        [UsersManager defaultManager].currentUser.isSpreedMeAdmin = isSpreedMeAdmin;
                                                                                        
                                                                                        _state = kSMConnectionStateInternalWaitingForSelf;
                                                                                        [_channelingManager closeConnection];
                                                                                        [SettingsController sharedInstance].lastConnectedUserId = defaultUserManager.currentUser.userId;
                                                                                        [SettingsController sharedInstance].lastConnectedOCUserPass = password;
                                                                                        [_channelingManager connectToServer:_currentWebSocketEndpoint withToken:nil];
                                                                                        
                                                                                    } else {
                                                                                        spreed_me_log("Error success==false while request getUserConfig has succeded!");
                                                                                        [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                                                                    }
                                                                                } else {
                                                                                    [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                                                                }
                                                                            }];
                                                  
                                              } else {
                                                  spreed_me_log("UserId length is zero. This is error!");
                                                  [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                                  return;
                                              }
                                          } else {
                                              spreed_me_log("incorrect userIdCombo!!!");
                                              [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                              return;
                                          }
                                          
                                      } else {
                                          spreed_me_log("Error success==false while request getUserCombo has succeded!");
                                          [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                      }
                                  } else if (jsonResponse) {
                                      BOOL success = [[jsonResponse objectForKey:NSStr(kLCSuccessKey)] boolValue];
                                      if (!success) {
                                          
                                          NSString *code = [jsonResponse objectForKey:NSStr(kLCCodeKey)];
                                          if ([code isEqualToString:@"failed"]) {
                                              [self userFailedToLoginWithReason:kSMLoginFailReasonIncorrectUserNameOrPassword];
                                          } else {
                                              [self userFailedToLoginWithReason:kSMLoginFailReasonNetworkFailure];
                                          }
                                          
                                      } else {
                                          spreed_me_log("Error success==true while request failed!");
                                          [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                      }
                                      
                                  } else {
                                      [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
                                  }
                              }];
}


- (void)checkPermissionToUseSpreedMEAppWithUsername:(NSString *)username password:(NSString *)password serverEndpoint:(NSString *)serverRESTAPIEndpoint
{
    if (username.length == 0 || password.length == 0) {
        [self userFailedToLoginWithReason:kSMLoginFailReasonIncorrectUserNameOrPassword];
        return;
    }
    
    NSString *configEndpoint = [serverRESTAPIEndpoint stringByAppendingString:@"/api/v1/config"];
    
    [self stopTryingToReconnect];
    
    [[SettingsController sharedInstance] getServerConfigWithServer:configEndpoint userName:username password:password withCompletionBlock:^(NSString *spreedMEURL, NSError *error) {
        // Stop login proccess if failed.
        if (!error && spreedMEURL) {
            NSString *owncloudServiceURL = [[SettingsController sharedInstance] removeServerConfigEndpointFromServer:configEndpoint];
            [[SMConnectionController sharedInstance] connectToOwnCloudService:owncloudServiceURL withSpreedMEService:spreedMEURL username:username password:password];
        } else {
            [self userFailedToLoginWithReason:kSMLoginFailReasonUnknown];
        }
    }];
}


#pragma mark - Reset

- (void)resetConnectionController
{
	[self disconnect];
    [SettingsController sharedInstance].ownCloudMode = NO;
	[SettingsController sharedInstance].lastConnectedUserId = nil;
    [SettingsController sharedInstance].lastConnectedOCUserPass = nil;
	
	_channelingManager.spreedMeMode = _spreedMeMode;
    _ownCloudMode = NO;
	
	[SettingsController sharedInstance].spreedMeMode = _spreedMeMode;
	
	// reset user
	[UsersManager defaultManager].currentUser = [[SMLocalUser alloc] init];
	[UsersManager defaultManager].currentUser.room = nil;
    
    if (_spreedMeMode) {
        [self setupAppVersionCheckerPeriodicChecks];
    } else {
        [_versionChecker stopPeriodicChecks];
    }
    
	
	if (_spreedMeMode) {
		[self refreshEndpointsURLsWithUserServerString:kDefaultServer];
		self.appLoginState = kSMAppLoginStatePromptUserToLogin;
	} else {
		self.appLoginState = kSMAppLoginStateNoLoginRequired;
		_currentImagesEndpoint = nil;
		_currentRESTAPIEndpoint = nil;
		_currentWebSocketEndpoint = nil;
	}
	[UsersManager defaultManager].currentUser.wasConnected = NO; // user shouldn't connect automatically after reset
	
	//TODO: Maybe move this from SMConnectionController
	[[ResourceDownloadManager sharedInstance] cancelAllTasks];
	[[ResourceDownloadManager sharedInstance] registerSecurityPolicyClass:_spreedMeMode ? [SpreedMeStrictSSLSecurityPolicy class] : [SpreedSSLSecurityPolicy class]];
}


#pragma mark - Notifications

- (void)userHasResetApplication:(NSNotification *)notification
{
	// We need this in order to reconnect and pretend as if were connected already.
	_wantsToConnect = YES;
	
	
	// Prevent double call of resetConnectionController which will happen if mode was not spreedMe
	if (!self.spreedMeMode) {
		self.spreedMeMode = YES;
	} else {
		[self resetConnectionController];
	}
	

	[[UsersManager defaultManager] deleteAllSavedUsers];
	
	
	// go to rooms view controller
	[[UserInterfaceManager sharedInstance] presentRoomsViewController];
	
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:ConnectionControllerHasProcessedResetOfApplicationNotification
															object:self
														  userInfo:nil];
	});
}


- (void)SSLStoreHasAddedNewCertificate:(NSNotification *)notification
{
	if (notification.object == [TrustedSSLStore sharedTrustedStore] && [UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
		// We can assume that user has accepted certificate in question. Don't wait and reconnect immidiately. Also reset accumulated reconnect time.
		if (_reconnectTimer.isValid && _tryingToReconnect && !self.isConnected) {
			_reconnectTime = 0.0;
			[self tryToReconnect:nil];
		}
	}
}


- (void)applicationWillResignActive:(NSNotification *)notification
{
	if ([UsersManager defaultManager].currentUser.settings.shouldDisconnectOnBackground && ![PeerConnectionController sharedInstance].inCall) {
		BOOL isConnected = self.isConnected;
		[self disconnectWithInactivityReason:kSMDisconnectionReasonClosedByUserButShouldReconnectNextTime];
		[UsersManager defaultManager].currentUser.wasConnected = YES; // we need not to set [UsersManager defaultManager].currentUser.wasConnected to NO
		// For spreedMe mode we also need to set proper app login state
		if (_spreedMeMode && isConnected &&
			[UsersManager defaultManager].currentUser.applicationToken) {
			_appLoginState = kSMAppLoginStateWaitForAutomaticLogin;
		}
		
		[[UsersManager defaultManager] saveCurrentUser];
	}
	
	//[self stopTryingToReconnect]; still try to reconnect
	
	[self.ndController saveStatisticsToDir:[SMNetworkDataStatisticsController savedStatisticsDir]];
}


- (void)applicationDidBecomeActive:(NSNotification *)notification
{
	[self reconnectIfNeeded];
}


- (void)reachabilityHasChanged:(NSNotification *)notification
{
	NetworkStatus status = (NetworkStatus)[[notification.userInfo objectForKey:ReachabilityNotificationNetworkStatusKey] integerValue];
	NSString *host = [notification.userInfo objectForKey:ReachabilityNotificationHostNameKey];
	if ([_currentWebSocketEndpoint rangeOfString:host].location != NSNotFound && status != NotReachable) {
		[self reconnectIfNeeded];
	}
}


- (void)networkDataBytesHaveBeenSent:(NSNotification *)notification
{
	uint64_t bytesSent = [[notification.userInfo objectForKey:kSTNetworkDataNotificationUserInfoBytesKey] unsignedLongLongValue];
	NSString *serviceName = [notification.userInfo objectForKey:kSTNetworkDataNotificationUserInfoServiceNameKey];
	[self.ndController addSentBytes:bytesSent forServiceName:serviceName];
}


- (void)networkDataBytesHaveBeenReceived:(NSNotification *)notification
{
	uint64_t bytesReceived = [[notification.userInfo objectForKey:kSTNetworkDataNotificationUserInfoBytesKey] unsignedLongLongValue];
	NSString *serviceName = [notification.userInfo objectForKey:kSTNetworkDataNotificationUserInfoServiceNameKey];
	[self.ndController addReceivedBytes:bytesReceived forServiceName:serviceName];
}


- (void)userDidAcceptCertificate:(NSNotification *)notification
{
    [self reconnectToCurrentServer];
}


- (void)userDidRejectCertificate:(NSNotification *)notification
{
    [self disconnect];
}


#pragma mark - Setters/Getters

- (void)setSpreedMeMode:(BOOL)spreedMeMode
{
	if (_spreedMeMode != spreedMeMode) {
		
		[self disconnect];
		
		_spreedMeMode = spreedMeMode;
		
		[self resetConnectionController];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:UserHasChangedApplicationModeNotification
															object:self
														  userInfo:@{kApplicationModeKey : @(_spreedMeMode)}];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ConnectionControllerHasProcessedChangeOfApplicationModeNotification
															object:self
														  userInfo:nil];
	}
}


- (void)setAppLoginState:(SMAppLoginState)appLoginState
{
	if (_appLoginState != appLoginState) {
		SMAppLoginState oldState = _appLoginState;
		_appLoginState = appLoginState;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:SMAppLoginStateHasChangedNotification
															object:self
														  userInfo:@{kSMOldAppLoginStateKey : @(oldState),
																	 kSMNewAppLoginStateKey : @(_appLoginState)}];
	}
}


- (SMConnectionState)connectionState
{
    SMConnectionState connectionState = kSMConnectionStateDisconnected;
    
    switch (_state) {
        
        case kSMConnectionStateInternalConnected:
            connectionState = kSMConnectionStateConnected;
            break;
            
        case kSMConnectionStateInternalWaitingForAppToken:
        case kSMConnectionStateInternalWaitingForAuthorizedSelf:
        case kSMConnectionStateInternalWaitingForNonce:
        case kSMConnectionStateInternalWaitingForRefreshedUserComboAndSecret:
        case kSMConnectionStateInternalWaitingForSelf:
        case kSMConnectionStateInternalWaitingForServerConfig:
            connectionState = kSMConnectionStateConnecting;
            break;
        
        case kSMConnectionStateInternalDisconnected:
        default:
            connectionState = kSMConnectionStateDisconnected;
            break;
    }
    
    return connectionState;
}


#pragma mark - Hello and user status functionality

- (void)scheduleNewSelfUpdateIfNeededWithTTL:(NSTimeInterval)ttl
{
	if (!_iceServerUpdateTimer) {
		[self scheduleNewSelfUpdateWithTTL:ttl];
	}
}


- (void)scheduleNewSelfUpdateWithTTL:(NSTimeInterval)ttl
{
	if (_iceServerUpdateTimer) {
		[_iceServerUpdateTimer invalidate];
		_iceServerUpdateTimer = nil;
	}
	
	_iceServerUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)ttl target:self selector:@selector(sendEmptySelf:) userInfo:nil repeats:NO];
}


- (void)sendEmptySelf:(NSTimer *)timer
{
	[self.channelingManager sendEmptySelf];
}


#pragma mark - Connectivity functionality

- (void)connectionHasBecomeActive
{
	_currentLoginOperation = nil;
	_isConnected = YES;
	_state = kSMConnectionStateInternalConnected;
	
	if (_spreedMeMode) {
		self.appLoginState = kSMAppLoginStateUserIsLoggedIn;
	} else {
		self.appLoginState = kSMAppLoginStateNoLoginRequired;
	}
	
	[self stopTryingToReconnect];
	
	[self notifyConnectionHasBecomeActive];
    [self notifyConnectionHasChangedState:kSMConnectionStateConnected];
	[self scheduleNewSelfUpdateIfNeededWithTTL:kDefaultTTL];
	
	// if user doesn't have userId assume that it is non spreed me mode and it is general user
	NSString *lastConnectedUserId = [UsersManager defaultManager].currentUser.userId;
	if (lastConnectedUserId.length == 0) {
		lastConnectedUserId = [[[SMAppIdentityController sharedInstance] defaultUserUID] copy];
	}
	[SettingsController sharedInstance].lastConnectedUserId = lastConnectedUserId;
	[[UsersManager defaultManager] saveCurrentUser];
	
	[self.channelingManager sayHelloToRoom:[UsersManager defaultManager].currentUser.room.name];
}


- (void)connectionHasBecomeInactiveWithReason:(SMDisconnectionReason)reason
{
	_isConnected = NO;
	_state = kSMConnectionStateInternalDisconnected;
	[self notifyConnectionHasBecomeInactiveWithReason:reason];
	
	switch (reason) {
		case kSMDisconnectionReasonUnspecified:
		case kSMDisconnectionReasonFailed:
			[self reconnectToServerAfterFailure];
			break;
			
		case kSMDisconnectionReasonClosedByUser:
			
			break;
		default:
			break;
	}
}


#pragma mark - Notifying functionality

- (void)notifyConnectionHasBecomeActive
{
	[[NSNotificationCenter defaultCenter] postNotificationName:ChannelingConnectionBecomeActiveNotification object:self];
}


- (void)notifyConnectionHasBecomeInactiveWithReason:(SMDisconnectionReason)reason
{
	NSDictionary *userInfo = nil;
	if (reason == kSMDisconnectionReasonUserFailedToLogin) {
		userInfo = @{kChannelingConnectionBecomeInactiveReasonKey : @(reason),
					 kChannelingConnectionBecomeInactiveLoginFailedReasonKey : @(self.lastLoginFailReason)};
	} else {
		userInfo = @{kChannelingConnectionBecomeInactiveReasonKey : @(reason)};
	}
	
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ChannelingConnectionBecomeInactiveNotification
														object:self
													  userInfo:userInfo];
}


- (void)notifyConnectionHasChangedState:(SMConnectionState)newState
{
    [[NSNotificationCenter defaultCenter] postNotificationName:ConnectionHasChangedStateNotification
                                                        object:self
                                                      userInfo:@{kConnectionHasChangedStateNotificationNewStateKey : @(newState)}];
}


- (void)notifyApplicationVersionCheckHasFailed
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMAppVersionCheckStateChangedNotification
                                                        object:self
                                                      userInfo:@{kSMAppVersionCheckStateNotificationKey : @(NO)}];
}


- (void)notifyApplicationVersionCheckHasSucceeded
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMAppVersionCheckStateChangedNotification
                                                        object:self
                                                      userInfo:@{kSMAppVersionCheckStateNotificationKey : @(YES)}];
}


#pragma mark - Utilities related to self

- (NSArray *)parseAndUpdateIceServersWithTurnDict:(NSDictionary *)turnDict stunArray:(NSArray *)stunArray
{
	NSString *userName = [turnDict objectForKey:NSStr(kLCUserNameKey)];
	NSString *password = [turnDict objectForKey:NSStr(kLCPasswordKey)];
	
	NSArray *turnUrls = [turnDict objectForKey:NSStr(kLCUrlsKey)];
	if (![turnUrls isKindOfClass:[NSArray class]]) {
		turnUrls = nil;
	}
	
	NSMutableArray *servers = [NSMutableArray array];
	for (NSString *turnUrl in turnUrls) {
		NSDictionary *server = @{NSStr(kLCUserNameKey) : userName, NSStr(kLCPasswordKey) : password, NSStr(kLCUrlKey) : turnUrl};
		[servers addObject:server];
	}
	for (NSString *stunUrl in stunArray) {
		NSDictionary *server = @{NSStr(kLCUrlKey) : stunUrl};
		[servers addObject:server];
	}
	
	return [NSArray arrayWithArray:servers];
}


#pragma mark - ChannelingManager Observer

- (void)channelingManagerDidConnectToServer:(ChannelingManager *)channelingManager
{
	/*
	 As agreed with Simon on 08.01.2014, if we have already ID and sessionToken we can assume that this is reconnection
	 and use last saved self document without receiving new Self document.
	 */
	if ([[UsersManager defaultManager].currentUser.sessionId length] > 0 &&
		[[UsersManager defaultManager].currentUser.sessionToken length] > 0) {
		
		// check here for userId
		[self connectionHasBecomeActive];
	} else {
		
	}
}


- (void)channelingManagerDidDisconnectFromServer:(ChannelingManager *)manager
{
	[self connectionDisconnectedWithReason:kSMDisconnectionReasonFailed];
}


- (void)channelingManager:(ChannelingManager *)manager didReceiveSelf:(NSDictionary *)selfDict
{
	NSString *serverVersion = [[selfDict objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kVersionKey)];
	if (serverVersion && [serverVersion isKindOfClass:[NSString class]]) {
		BOOL shouldReconnect = [self shouldReconnectBecauseOfServerVersionHasChangedFrom:self.lastServerVersion to:serverVersion];
		if (shouldReconnect) {
			// We should reconnect since server version has changed and possibly other options could change.
			// TODO: check if we need to reload server config in this case
			[self reconnect];
			return;
		}
	} else {
		spreed_me_log("No server version in self document!");
	}

	
	SMLocalUser *currentUser = [UsersManager defaultManager].currentUser;
	
	NSString *newSessionId = [[[selfDict objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kIdKey)] copy];
	NSString *newSecSessionId = [[[selfDict objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kSIdKey)] copy];
	NSString *newUserId = [[[selfDict objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kUserIdKey)] copy];
	NSString *newSecUserId = [[[selfDict objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kSUserIdKey)] copy];
	NSString *token = [[[selfDict objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kTokenKey)] copy];
	
	if (![currentUser.sessionId isEqualToString:newSessionId]) {
		spreed_me_log("received Self message with new session id %s old session id %s",
					  [newSessionId cStringUsingEncoding:NSUTF8StringEncoding],
					  [currentUser.sessionId cStringUsingEncoding:NSUTF8StringEncoding]);
		currentUser.sessionId = [newSessionId copy];
		[[PeerConnectionController sharedInstance] sessionIdHasChanged:currentUser.sessionId];
		_signallingHandler->SetSelfId(std::string([currentUser.sessionId cStringUsingEncoding:NSUTF8StringEncoding]));
	}
	currentUser.secSessionId = newSecSessionId;
	currentUser.sessionToken = token;
	
	
	if ((_spreedMeMode || _ownCloudMode) && _state == kSMConnectionStateInternalWaitingForSelf) {
		_state = kSMConnectionStateInternalWaitingForNonce;
		 _currentLoginOperation = [[LoginManager sharedInstance]
								   getNonceWithSessionId:currentUser.sessionId
										 secureSessionId:currentUser.secSessionId
											 userIdCombo:currentUser.lastUserIdCombo
												  secret:currentUser.lastUserIdComboSecret
										 completionBlock:^(NSDictionary *jsonResponse, NSError *error) {
											 if (!error) {
												 NSString *nonce = [jsonResponse objectForKey:NSStr(kLCNonceKey)];
												 NSString *userId = [jsonResponse objectForKey:NSStr(kLCUserIdKey)];
												 
												 _state = kSMConnectionStateInternalWaitingForAuthorizedSelf;
												 
												 [self.channelingManager sendAuthenticationRequestWithUserId:userId nonce:nonce];
											 } else {
												 [self userFailedToLoginWithReason:kSMLoginFailReasonCouldNotGetNonce];
											 }
										 }];
		
		return;
	}

	
	if (_state == kSMConnectionStateInternalWaitingForSelf && (!_spreedMeMode && !_ownCloudMode)) {
		
//		currentUser.userId = newUserId; we shouldn't set userId for non spreed me mode
			
		[self.channelingManager sendStatusWithDisplayName:currentUser.displayName statusMessage:currentUser.statusMessage picture:currentUser.base64Image];
		
		currentUser.wasConnected = YES;
		
		[self connectionHasBecomeActive];
		
	} else if ((_spreedMeMode || _ownCloudMode) && _state == kSMConnectionStateInternalWaitingForAuthorizedSelf) {
		
		if ([currentUser.userId isEqualToString:newUserId]) {
			currentUser.userId = newUserId;
			currentUser.secUserId = newSecUserId;

			[self.channelingManager sendStatusWithDisplayName:currentUser.displayName statusMessage:currentUser.statusMessage picture:currentUser.base64Image];
			
			currentUser.wasConnected = YES;
			
			[self connectionHasBecomeActive];
		} else {
			[self userFailedToLoginWithReason:kSMLoginFailReasonIncorrectUserIdWithAuthorizedSelf];
			return;
		}
			
	}
	
	int ttl = [[[[selfDict objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kTurnKey)] objectForKey:NSStr(kLCTtlKey)] intValue];
	if (ttl < 1) {
		ttl = 3600;
	}

	ttl = (int)(ttl * 0.9);
	spreed_me_log("90%% of received ttl is %d", ttl);

	[self scheduleNewSelfUpdateWithTTL:ttl];

	NSDictionary *turnDict = [[[selfDict objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kTurnKey)] copy];
	if (!(turnDict && [turnDict isKindOfClass:[NSDictionary class]])) {
		turnDict = nil;
	}
	NSArray *stunArray = [[[selfDict objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kStunKey)] copy];
	if (!(stunArray && [stunArray isKindOfClass:[NSArray class]])) {
		stunArray = nil;
	}

	NSArray *servers = [self parseAndUpdateIceServersWithTurnDict:turnDict
														stunArray:stunArray];
	[[NSNotificationCenter defaultCenter] postNotificationName:SelfMessageReceivedNotification object:self userInfo:@{kSelfMessageIceServersKey : servers}];
}


- (void)channelingManager:(ChannelingManager *)manager didReceiveAliveMessage:(NSDictionary *)aliveDict
{
	
}


- (void)channelingManager:(ChannelingManager *)manager
	didReceiveChatMessage:(NSDictionary *)chatDict
			transportType:(ChannelingMessageTransportType)transportType
{
	[[ChatManager defaultManager] receivedChatMessage:chatDict transportType:transportType];
}


@end
