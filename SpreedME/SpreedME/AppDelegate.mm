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

#import "AppDelegate.h"

#import <AVFoundation/AVFoundation.h>

#import "ChildRotationNavigationController.h"
#import "ChildRotationTabBarController.h"

#import "RecentChatsViewController.h"
#import "SMRoomsViewController.h"
#import "OptionsViewController.h"
#import "FileBrowserControllerViewController.h"

#import "FileSharingManagerObjC.h"
#import "PeerConnectionController.h"
#import "SettingsController.h"
#import "SMAppIdentityController.h"
#import "SMConnectionController.h"
#import "SMLocalUserSettings.h"
#import "SMLocalizedStrings.h"
#import "STLocalNotificationManager.h"
#import "TrustedSSLStore.h"
#import "UICKeyChainStore.h"
#import "UsersActivityController.h"
#import "UserInterfaceManager.h"

@interface AppDelegate ()
{
    UIImageView *_screenshotCoverImageView;
    BOOL _isFirstLaunch;
    BOOL _isKeychainAccessible;
    BOOL _appLaunchedWithoutKeychainAccess;
    NSDictionary *_launchOptions;
	
	BOOL _shouldSetupAudioSessionWhenAppBecomesActive;
}
@end


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    init_spreed_me_log();
    
    _isFirstLaunch = NO;
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"HasLaunchedOnce"])
    {
        _isFirstLaunch = YES;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HasLaunchedOnce"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
	
	// iOS8 local notifications
	if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
		UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert |
																							UIUserNotificationTypeBadge |
																							UIUserNotificationTypeSound
																				 categories:nil];
		[application registerUserNotificationSettings:settings];
	}
    
    [self checkForCameraAndMicrophonePermissions];
	
    [self applicationLaunchProcess:application withOptions:launchOptions];
	
	return YES;
}


- (void)checkForCameraAndMicrophonePermissions
{
    if ([AVCaptureDevice respondsToSelector:@selector(requestAccessForMediaType: completionHandler:)]) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            // Will get here on both iOS 7 & 8 even though camera permissions weren't required
            // until iOS 8. So for iOS 7 permission will always be granted.
            if (!granted) {
                // Permission has been granted. Use dispatch_async for any UI updating
                // code because this block may be executed in a thread.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showPremissionWarningForCamera:YES];
                });
            }
        }];
    }
    
    if ([AVCaptureDevice respondsToSelector:@selector(requestAccessForMediaType: completionHandler:)]) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            if (!granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showPremissionWarningForCamera:NO];
                });
            }
        }];
    }
}


- (void)showPremissionWarningForCamera:(BOOL)camera
{
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    
    NSString *locFormatStrBody = NSLocalizedStringWithDefaultValue(@"message_body-arg6_camera-or-mic-disabled_ios",
                                                                   nil, [NSBundle mainBundle],
                                                                   @"%@ needs %@ to be enabled in order to work properly. Please go to device %@ -> %@ and enable %@ for %@.",
                                                                   @"'appname' needs 'device' to be enabled in order to work properly. Please go to device 'Settings' -> 'Privacy' and enable 'device' for 'appname'. You can move around '%@' but make sure you have 6 of them.");
    
    NSString *errorCameraMsg = [NSString stringWithFormat:locFormatStrBody,
                                appName,
                                kSMLocalStringiOSSettingsCameraLabel,
                                kSMLocalStringiOSSettingsSettingsLabel,
                                kSMLocalStringiOSSettingsPrivacyLabel,
                                kSMLocalStringiOSSettingsCameraLabel,
                                appName];
    
    NSString *errorMicMsg = [NSString stringWithFormat:locFormatStrBody,
                             appName,
                             kSMLocalStringiOSSettingsMicrophoneLabel,
                             kSMLocalStringiOSSettingsSettingsLabel,
                             kSMLocalStringiOSSettingsPrivacyLabel,
                             kSMLocalStringiOSSettingsMicrophoneLabel,
                             appName];
    
    NSString *locFormatStrTitle = NSLocalizedStringWithDefaultValue(@"message_title-arg2_camera-or-mic-disabled",
                                                                    nil, [NSBundle mainBundle],
                                                                    @"%@ is not enabled for %@",
                                                                    @"'device' is not enabled for 'appname'. You can move around '%@' but make sure you have 2 of them.");
    
    NSString *errorCameraTitle = [NSString stringWithFormat:locFormatStrTitle, kSMLocalStringiOSSettingsCameraLabel, appName];
    NSString *errorMicTitle = [NSString stringWithFormat:locFormatStrTitle, kSMLocalStringiOSSettingsMicrophoneLabel, appName];
    
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:(camera) ? errorCameraTitle : errorMicTitle
                                                    message:(camera) ? errorCameraMsg : errorMicMsg
                                                   delegate:nil
                                          cancelButtonTitle:kSMLocalStringSadOKButton
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	[self hideScreenBeforeSystemScreenshot];
	
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	spreed_me_log("applicationDidEnterBackground");
	[self setupKeepAliveTimer:application];
	
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    if (_appLaunchedWithoutKeychainAccess) {
        _appLaunchedWithoutKeychainAccess = NO;
        [self applicationLaunchProcess:application withOptions:_launchOptions]; // We will need to save launchOptions when app launches without keychain access.
    }
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	[self showScreenAfterSystemScreenshot];
	
	[STLocalNotificationManager sharedInstance].applicationIconBadgeNumber  = 0;
	
	if (![PeerConnectionController sharedInstance].inCall && _shouldSetupAudioSessionWhenAppBecomesActive) {
		[self setupAudioSession];
		_shouldSetupAudioSessionWhenAppBecomesActive = NO;
		spreed_me_log("Setup AVAudioSession first time after app was launched in background.");
	}
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
	if (application.applicationState != UIApplicationStateActive) {
		[STLocalNotificationManager sharedInstance].applicationIconBadgeNumber  = 0;
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
	} else {
		
	}
}


- (void)setupKeepAliveTimer:(UIApplication *)application
{
	[application setKeepAliveTimeout:600 handler:^{
		spreed_me_log("Keep alive timeout at %s", [[NSDate date] cDescription]);
		if ([SMConnectionController sharedInstance].connectionState == kSMConnectionStateConnected) {
			[[SMConnectionController sharedInstance].channelingManager sendHeartBeat:nil];
		} else {
			[[SMConnectionController sharedInstance] reconnectIfNeeded];
		}
	}];
}


#pragma mark - Application launching process

- (void)applicationLaunchProcess:(UIApplication *)application withOptions:(NSDictionary *)launchOptions
{
    _appLaunchedWithoutKeychainAccess = YES;
    _launchOptions = launchOptions; // Save launchOptions in case the keychain is not accessible when the app is launched.
    
    if ([self checkKeychainInteractionAvailability]) {
        _appLaunchedWithoutKeychainAccess = NO;
        [self appLaunchInitialization:application withOptions:launchOptions];
    } else {
        _appLaunchedWithoutKeychainAccess = YES;
        [self showKeychainNotAvailableNotification];
    }
}


- (void)appLaunchInitialization:(UIApplication *)application withOptions:(NSDictionary *)launchOptions
{
    [SMAppIdentityController sharedInstance];
    
    if (_isFirstLaunch) {
        [[SMAppIdentityController sharedInstance] initForFirstAppLaunch];
        [UICKeyChainStore setString:kSMSpreedMeModeOnString forKey:kSpreedMeModeSettingsKey];
    }
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = kSMApplicationBackgroundColor;
	
	// Do not setup AVAudioSession if we are launched in background. Postpone it to appDidBecomeActive
	if (application.applicationState == UIApplicationStateBackground) {
		_shouldSetupAudioSessionWhenAppBecomesActive = YES;
		spreed_me_log("Postpone AVAudioSession initial setup to the time when app is active.");
	} else {
		[self setupAudioSession];
	}
	
    [PeerConnectionController sharedInstance]; //start peer connection
	
	// App version
	NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	if (![SettingsController sharedInstance].appVersion) {
		[SettingsController sharedInstance].appVersion = bundleVersion;
		
	} else if ([SettingsController sharedInstance].appVersion.length > 0 &&
			   ![[SettingsController sharedInstance].appVersion isEqualToString:bundleVersion]) {
		
		spreed_me_log("Application is being updated from v:%s to v:%s !",
					  [[SettingsController sharedInstance].appVersion cDescription],
					  [bundleVersion cDescription]);
		// Update app if needed
		[SettingsController sharedInstance].appVersion = bundleVersion;
	}
	
    // Just in case, set video settings to default settings
    SMLocalUserSettings *defaultSettings = [SMLocalUserSettings defaultSettings];
    [[PeerConnectionController sharedInstance] setVideoPreferencesWithCamera:defaultSettings.videoDeviceId
                                                             videoFrameWidth:defaultSettings.frameWidth
                                                            videoFrameHeight:defaultSettings.frameHeight
                                                                         FPS:defaultSettings.fps];
    
    
    /*
     init FileSharingManager. This MUST be done after creation of _peerConnectionWrapperFactory and ChannelingManager.
     At the moment ChannelingManager is created inside of PeerConnectionController so it is safe to create FileSharingManagerObjC after PeerConnectionController.
     */
    [FileSharingManagerObjC defaultManager];
    
    SMRoomsViewController *roomsViewController = [[SMRoomsViewController alloc] initWithNibName:@"SMRoomsViewController" bundle:nil];
    NSString *directory = [[FileSharingManagerObjC defaultManager] fileLocation];
    FileBrowserControllerViewController *fileBrowserViewController = [[FileBrowserControllerViewController alloc] initWithDirectoryPath:directory];
    OptionsViewController *optionsViewController = [[OptionsViewController alloc] initWithNibName:@"OptionsViewController" bundle:nil];
    RecentChatsViewController *recentChatsViewController = [[RecentChatsViewController alloc] initWithUserActivityController:[UsersActivityController sharedInstance]];
    
    ChildRotationTabBarController *tabbar = [[ChildRotationTabBarController alloc] init];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        [[UITabBar appearance] setTintColor:kSpreedMeBlueColor]; /*#00bbd7*/
    } else {
        [[UITabBar appearance] setTintColor:kGrayColor_f5f5f5];
        [[UITabBarItem appearance] setTitleTextAttributes:@{UITextAttributeTextColor : kSpreedMeBlueColor,}
                                                            forState:UIControlStateSelected];
    }
    
    [[UITabBar appearance] setBackgroundColor:kGrayColor_f5f5f5];
    
    ChildRotationNavigationController *roomsViewControllerNavVC = [[ChildRotationNavigationController alloc] initWithRootViewController:roomsViewController];
    ChildRotationNavigationController *fileBrowserViewControllerNavVC = [[ChildRotationNavigationController alloc] initWithRootViewController:fileBrowserViewController];
    ChildRotationNavigationController *profileViewControllerNavVC = [[ChildRotationNavigationController alloc] initWithRootViewController:optionsViewController];
    ChildRotationNavigationController *recentChatsViewControllerNavVC = [[ChildRotationNavigationController alloc] initWithRootViewController:recentChatsViewController];
    
    tabbar.viewControllers = @[roomsViewControllerNavVC, recentChatsViewControllerNavVC, fileBrowserViewControllerNavVC, profileViewControllerNavVC];
    
    [UserInterfaceManager sharedInstance].mainTabbarController = tabbar;
    [UserInterfaceManager sharedInstance].callVCPresentationController = tabbar;
    [UserInterfaceManager sharedInstance].roomsViewControllerNavVC = roomsViewControllerNavVC;
    [UserInterfaceManager sharedInstance].optionsViewControllerNavVC = profileViewControllerNavVC;
    [UserInterfaceManager sharedInstance].optionsViewController = optionsViewController;
    [UserInterfaceManager sharedInstance].recentChatsViewController = recentChatsViewController;
    [UserInterfaceManager sharedInstance].rootFileBrowserVC = fileBrowserViewController;
    [UserInterfaceManager sharedInstance].roomsViewControllerTabbarIndex = 0;
    [UserInterfaceManager sharedInstance].recentChatsViewControllerTabbarIndex = 1;
    [UserInterfaceManager sharedInstance].rootFileBrowserVCTabbarIndex = 2;
    [UserInterfaceManager sharedInstance].optionsViewControllerTabbarIndex = 3;
    
    [TrustedSSLStore sharedTrustedStore].viewControllerForActions = tabbar;
    
    self.window.rootViewController = tabbar;
    [self.window makeKeyAndVisible];
    
    TabbarTabsEnableState tabbarState =
    ([SMConnectionController sharedInstance].appLoginState == kSMAppLoginStatePromptUserToLogin) ?
    kTabbarTabsEnableStateLoginRequired :
    kTabbarTabsEnableStateIdle;
    
    [[UserInterfaceManager sharedInstance] setTabbarEnableState:tabbarState];
    
#ifdef SPREEDME
    if (_isFirstLaunch) {
        [[UserInterfaceManager sharedInstance] presentSpreedboxNotificationViewController];
    }
#endif
    [STLocalNotificationManager sharedInstance].applicationIconBadgeNumber  = 0;
    
    if (application.applicationState == UIApplicationStateBackground) {
        spreed_me_log("Application has been launched in background!");
        [self setupKeepAliveTimer:application];
    }
}


#pragma mark - Screenshot privacy

- (void)hideScreenBeforeSystemScreenshot
{
	UIInterfaceOrientation intOrient = [[UIApplication sharedApplication] statusBarOrientation];
	BOOL landscape = UIInterfaceOrientationIsLandscape(intOrient);
	
	NSString *splashImage = nil;
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		if (landscape) {
			splashImage = [UIScreen mainScreen].scale < 1.1f ? @"Default-Landscape~ipad" : @"Default-Landscape@2x~ipad";
		} else {
			splashImage = [UIScreen mainScreen].scale < 1.1f ? @"Default~ipad" : @"Default@2x~ipad";
		}
	} else {
		if ([UIScreen mainScreen].bounds.size.height == 568.0f) {
			
			if (!landscape) {
				splashImage = @"Default-568h";
			} else {
				splashImage = @"1136x640";
			}
		} else {
			if (!landscape) {
				splashImage = @"Default";
			} else {
				splashImage = @"960x640";
			}
		}
	}
	
	CGAffineTransform t = CGAffineTransformIdentity;
	switch (intOrient) {
		case UIInterfaceOrientationPortraitUpsideDown:
			t = CGAffineTransformMakeRotation(M_PI);
		break;
			
		case UIInterfaceOrientationLandscapeLeft:
			t = CGAffineTransformMakeRotation(- M_PI / 2);
		break;
			
		case UIInterfaceOrientationLandscapeRight:
			t = CGAffineTransformMakeRotation(M_PI / 2);
		break;
			
		case UIInterfaceOrientationPortrait:
		default:
		break;
	}
	
	UIImage *image = [UIImage imageNamed:splashImage];
	
	if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
		_screenshotCoverImageView = [[UIImageView alloc] initWithFrame:self.window.bounds];
	} else {
		CGRect imageRect = CGRectApplyAffineTransform([self.window frame], t);
		imageRect.origin = CGPointZero;
		_screenshotCoverImageView = [[UIImageView alloc] initWithFrame:imageRect];
		_screenshotCoverImageView.transform = t;
	}
	
	_screenshotCoverImageView.center = self.window.center;
	_screenshotCoverImageView.image = image;
	[self.window addSubview:_screenshotCoverImageView];
}


- (void)showScreenAfterSystemScreenshot
{
	[_screenshotCoverImageView removeFromSuperview];
	_screenshotCoverImageView = nil;
}


#pragma mark - Keychain availability test

- (BOOL)checkKeychainInteractionAvailability
{
    NSString *timeStampValue = [NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]];
    NSString *keychainTestKey = [NSString stringWithFormat:@"keychainTestKey%@", timeStampValue];
    
    if ([UICKeyChainStore setString:timeStampValue forKey:keychainTestKey]) {
        [UICKeyChainStore removeItemForKey:keychainTestKey service:[[NSBundle mainBundle] bundleIdentifier] accessGroup:nil];
        _isKeychainAccessible = YES;
    } else {
        _isKeychainAccessible = NO;
    }
    return _isKeychainAccessible;
}


- (void)showKeychainNotAvailableNotification
{
    UIApplication *app = [UIApplication sharedApplication];
    if (app.applicationState != UIApplicationStateActive) {
		NSString *locAlertBody = NSLocalizedStringWithDefaultValue(@"message_body_keychain-locked",
																   nil, [NSBundle mainBundle],
																   @"App could not be initialized because Keychain was locked by your Passcode when the app was launched. Please, launch the app again.",
																   @"App could not be initialized because Keychain was locked by your Passcode when the app was launched. Please, launch the app again.");
        [[STLocalNotificationManager sharedInstance] postLocalNotificationWithSoundName:UILocalNotificationDefaultSoundName
                                                                              alertBody:locAlertBody
                                                                            alertAction:kSMLocalStringGoToAppButton];
    }
}


#pragma mark - Audio Session initial setup

- (void)setupAudioSession
{
	NSError *error = nil;
	BOOL success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient error:&error];
	if (!success) {
		spreed_me_log("Error while setting AudioSession SoloAmbient category in AppDelegate didFinishLaunchingWithOptions %s", [error cDescription]);
	}
	error = nil;
	success = [[AVAudioSession sharedInstance] setActive:YES error:&error];
	if (!success) {
		spreed_me_log("Error while setting AudioSession active in AppDelegate didFinishLaunchingWithOptions %s", [error cDescription]);
	}
}


@end
