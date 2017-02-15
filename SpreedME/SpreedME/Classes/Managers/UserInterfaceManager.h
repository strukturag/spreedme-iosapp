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


typedef enum : NSUInteger {
    kUserInterfacePlaceUsers,
    kUserInterfacePlaceChats,
    kUserInterfacePlaceFiles,
} UserInterfacePlace;

typedef enum : NSUInteger {
    kTabbarTabsEnableStateIdle,
    kTabbarTabsEnableStateLoginRequired,
    kTabbarTabsEnableStateActiveCall,
} TabbarTabsEnableState;

typedef void (^DismissCallingViewCompletionBlock)(void);

@class FileBrowserControllerViewController;
@class RecentChatsViewController;
@class OptionsViewController;


/*
	This is the helper class for user interface. Please use carefully. 
	Don't forget to update it if you change UI since other classes are going to use it.
 */
@interface UserInterfaceManager : NSObject

@property (nonatomic, strong) UIViewController *callVCPresentationController;

@property (nonatomic, strong) UITabBarController *mainTabbarController;

@property (nonatomic, strong) RecentChatsViewController *recentChatsViewController;
@property (nonatomic, readwrite) NSInteger recentChatsViewControllerTabbarIndex;

@property (nonatomic, strong) FileBrowserControllerViewController *rootFileBrowserVC;
@property (nonatomic, readwrite) NSInteger rootFileBrowserVCTabbarIndex;

@property (nonatomic, strong) UINavigationController *roomsViewControllerNavVC;
@property (nonatomic, readwrite) NSInteger roomsViewControllerTabbarIndex;
@property (nonatomic, strong) UIViewController *currentRoomViewController;

@property (nonatomic, strong) UINavigationController *optionsViewControllerNavVC;
@property (nonatomic, strong) OptionsViewController *optionsViewController;
@property (nonatomic, readwrite) NSInteger optionsViewControllerTabbarIndex;

+ (UserInterfaceManager *)sharedInstance;
- (void)presentRoomsViewController;
- (void)popToCurrentRoomViewControllerAnimated:(BOOL)animated;
- (void)presentSpreedboxNotificationViewController;
- (void)dismissSpreedboxNotificationWithAcceptance:(BOOL)accepted;
- (void)presentServerSettingsViewController;
- (void)presentLoginViewController;
- (void)presentModalCallingViewController:(UIViewController *)callVC;
- (void)presentCurrentModalCallingViewController;
- (void)hideExistingCallToShow:(UserInterfacePlace)place backIconView:(UIView *)iconView text:(NSString *)text;
- (void)dismissCallingViewControllerWithCompletionBlock:(DismissCallingViewCompletionBlock)block;
- (void)setTabbarEnableState:(TabbarTabsEnableState)state;

- (void)tryToGoToFileWithName:(NSString *)fileName;

@end
