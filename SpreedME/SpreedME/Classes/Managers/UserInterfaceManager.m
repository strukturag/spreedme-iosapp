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

#import "UserInterfaceManager.h"

#import "CallWidget.h"
#import "FileBrowserControllerViewController.h"
#import "OptionsViewController.h"
#import "RecentChatsViewController.h"
#import "SMConnectionController.h"
#import "SMInitialNotificationViewController.h"
#import "SMLoginViewController.h"
#import "StatusBarLikeAlert.h"



@implementation UserInterfaceManager
{
	UIViewController *_currentCallVC;
	CallWidget *_currentCallWidget;
    SMLoginViewController *_loginViewController;
    SMInitialNotificationViewController *_initialSpreedboxNotification;
}


+ (UserInterfaceManager *)sharedInstance
{
	static dispatch_once_t once;
    static UserInterfaceManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (id)init
{
    self = [super init];
	if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userLoginStatusHasChanged:) name:SMAppLoginStateHasChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appVersionCheckStateHasChanged:) name:SMAppVersionCheckStateChangedNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasChangedAppModeOrResetApp:) name:ConnectionControllerHasProcessedChangeOfApplicationModeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasChangedAppModeOrResetApp:) name:ConnectionControllerHasProcessedResetOfApplicationNotification object:nil];
	}
	return self;
}


#pragma mark - Notifications

- (void)userHasChangedAppModeOrResetApp:(NSNotification *)notification
{
    [_loginViewController clearFields];
}


- (void)userLoginStatusHasChanged:(NSNotification *)notification
{
    if ([notification.userInfo objectForKey:kSMNewAppLoginStateKey]) {
        SMAppLoginState appLoginState = [[notification.userInfo objectForKey:kSMNewAppLoginStateKey] integerValue];
        if (appLoginState == kSMAppLoginStatePromptUserToLogin) {
            [self presentLoginViewController];
            [self setTabbarEnableState:kTabbarTabsEnableStateLoginRequired];
        } else {
            [self dismissLoginViewControllerAnimated:YES];
            [self setTabbarEnableState:kTabbarTabsEnableStateIdle];
        }
    }
}


- (void)appVersionCheckStateHasChanged:(NSNotification *)notification
{
    if ([notification.userInfo objectForKey:kSMAppVersionCheckStateNotificationKey]) {
        BOOL succeeded = [[notification.userInfo objectForKey:kSMAppVersionCheckStateNotificationKey] boolValue];
        if (!succeeded) {
            [_loginViewController setUIState:kSMLoginViewControllerUIStateAppVersionUnsupported];
        } else {
            [_loginViewController setUIState:kSMLoginViewControllerUIStateNormal];
        }
    }
}


#pragma mark -

- (void)presentRoomsViewController
{
    self.mainTabbarController.selectedIndex = self.roomsViewControllerTabbarIndex;
    [self.roomsViewControllerNavVC popToRootViewControllerAnimated:NO];
}


- (void)popToCurrentRoomViewControllerAnimated:(BOOL)animated
{
    if (self.currentRoomViewController) {
        [self.roomsViewControllerNavVC popToViewController:self.currentRoomViewController animated:animated];
    }
}


- (void)presentLoginViewController
{
    if (!_initialSpreedboxNotification) {
        SMLoginViewControllerUIState loginControllerState = kSMLoginViewControllerUIStateNormal;
        
        if ([SMConnectionController sharedInstance].appHasFailedVersionCheck) {
            loginControllerState = kSMLoginViewControllerUIStateAppVersionUnsupported;
        }
        
        if (![SMConnectionController sharedInstance].spreedMeMode && [SMConnectionController sharedInstance].ownCloudMode) {
            loginControllerState = kSMLoginViewControllerUIStateOwnCloud;
        }
        
        _loginViewController = [[SMLoginViewController alloc] initWithUIState:loginControllerState];
        
        [self presentRoomsViewController];
        [self.roomsViewControllerNavVC presentViewController:_loginViewController animated:YES completion:nil];
    }
}


- (void)dismissLoginViewControllerAnimated:(BOOL)animated
{
    if (_loginViewController) {
        [self presentRoomsViewController];
        [self.roomsViewControllerNavVC dismissViewControllerAnimated:animated completion:nil];
        _loginViewController = nil;
    }
}


- (void)presentSpreedboxNotificationViewController
{
    if (_loginViewController) {
        [self dismissLoginViewControllerAnimated:NO];
    }
    
    _initialSpreedboxNotification = [[SMInitialNotificationViewController alloc] initWithNibName:@"SMInitialNotificationViewController" bundle:nil];
    [self presentRoomsViewController];
    [self.roomsViewControllerNavVC presentViewController:_initialSpreedboxNotification animated:YES completion:nil];
}


- (void)dismissSpreedboxNotificationWithAcceptance:(BOOL)accepted
{
    if (accepted) {
        [self.roomsViewControllerNavVC dismissViewControllerAnimated:YES completion:^{
            [self presentServerSettingsViewController];
        }];
    } else {
        [self.roomsViewControllerNavVC dismissViewControllerAnimated:YES completion:^{
            if ([SMConnectionController sharedInstance].appLoginState == kSMAppLoginStatePromptUserToLogin) {
                [self presentLoginViewController];
            }
        }];
    }
    
    _initialSpreedboxNotification = nil;
}


- (void)presentServerSettingsViewController
{
    [self.optionsViewControllerNavVC popToRootViewControllerAnimated:NO];
    self.mainTabbarController.selectedIndex = self.optionsViewControllerTabbarIndex;
    [self.optionsViewController presentServerSettingsViewController];
}


#pragma mark -

- (void)presentModalCallingViewController:(UIViewController *)callVC
{
	if (callVC && self.callVCPresentationController) {
		
		if (_currentCallVC != callVC) {

		}
		
		[_currentCallWidget dismiss];
		_currentCallWidget = nil;

		
		
		if (self.callVCPresentationController.presentedViewController) {
			[self.callVCPresentationController dismissViewControllerAnimated:NO completion:^{
				[self.callVCPresentationController presentViewController:callVC animated:YES completion:^{
					_currentCallVC = callVC;
				}];
			}];
		} else {
			[self.callVCPresentationController presentViewController:callVC animated:YES completion:^{
				_currentCallVC = callVC;
			}];
		}
        
	} else {
		spreed_me_log("There is no callVC or self.callVCPresentationController to present calling view controller!");
		NSAssert(NO, @"There is no callVC or self.callVCPresentationController to present calling view controller!");
	}
}


- (void)presentCurrentModalCallingViewController
{
    if (_currentCallVC) {
        [self presentModalCallingViewController:_currentCallVC];
    }
}


- (void)hideExistingCallToShow:(UserInterfacePlace)place backIconView:(UIView *)iconView text:(NSString *)text
{
	if (_currentCallVC) {
		
		NSUInteger tabbarIndexToGo = self.mainTabbarController.selectedIndex;
		
		switch (place) {
			
			case kUserInterfacePlaceChats:
				tabbarIndexToGo = self.recentChatsViewControllerTabbarIndex;
				[self.recentChatsViewController.navigationController popToRootViewControllerAnimated:NO];
			break;
			
			case kUserInterfacePlaceFiles:
				tabbarIndexToGo = self.rootFileBrowserVCTabbarIndex;
			break;
		
			case kUserInterfacePlaceUsers:
			default:
				tabbarIndexToGo = self.roomsViewControllerTabbarIndex;
				[self presentRoomsViewController];
			break;
		}
		
		self.mainTabbarController.selectedIndex = tabbarIndexToGo;
		
		[_currentCallVC dismissViewControllerAnimated:YES completion:NULL];
		
        [self setTabbarEnableState:kTabbarTabsEnableStateActiveCall];
		
		if (!_currentCallWidget) {
			_currentCallWidget = [[CallWidget alloc] initWithIconView:iconView text:text];
			UIWindow *appWindow = [[UIApplication sharedApplication].windows firstObject];
			[_currentCallWidget showInView:appWindow at:appWindow.center addPanGesture:YES actionBlock:^{
				[self presentModalCallingViewController:_currentCallVC];
			}];
		}
	}
}


- (void)setTabbarEnableState:(TabbarTabsEnableState)state
{
    UITabBarItem *recentsItem = [self.mainTabbarController.tabBar.items objectAtIndex:self.recentChatsViewControllerTabbarIndex];
    UITabBarItem *filesItem = [self.mainTabbarController.tabBar.items objectAtIndex:self.rootFileBrowserVCTabbarIndex];
    UITabBarItem *preferencesItem = [self.mainTabbarController.tabBar.items objectAtIndex:self.optionsViewControllerTabbarIndex];
    
    switch (state) {
            
        case kTabbarTabsEnableStateLoginRequired:
            recentsItem.enabled = NO;
            filesItem.enabled = YES;
            preferencesItem.enabled = YES;
        break;
        
        case kTabbarTabsEnableStateActiveCall:
            recentsItem.enabled = YES;
            filesItem.enabled = YES;
            preferencesItem.enabled = NO;
        break;
            
        case kTabbarTabsEnableStateIdle:
        default:
            recentsItem.enabled = YES;
            filesItem.enabled = YES;
            preferencesItem.enabled = YES;
        break;
    }
}


- (void)dismissCallingViewControllerWithCompletionBlock:(DismissCallingViewCompletionBlock)block
{
	if (_currentCallVC) {
		[_currentCallVC dismissViewControllerAnimated:YES completion:^{
			_currentCallVC = nil;
            if (block) {
                block();
            }
		}];
		
		[_currentCallWidget dismiss];
		_currentCallWidget = nil;
	}
    
    [self setTabbarEnableState:kTabbarTabsEnableStateIdle];
}


- (void)tryToGoToFileWithName:(NSString *)fileName
{
	if (self.rootFileBrowserVC && [fileName length] > 0) {
		self.mainTabbarController.selectedIndex = self.rootFileBrowserVCTabbarIndex;
		[self.rootFileBrowserVC tryToOpenFileName:fileName recursive:NO];
	}
}


@end
