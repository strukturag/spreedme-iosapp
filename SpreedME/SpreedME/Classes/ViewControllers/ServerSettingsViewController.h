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

#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    kServerSetupStatusDisconnected = 0,
    kServerSetupStatusConnecting,
    kServerSetupStatusConnected,
} ServerSetupStatus;

@class ServerSettingsViewController;

@protocol ServerSettingsViewControllerDelegate <NSObject>
@required
- (void)serverSettingsViewController:(ServerSettingsViewController *)serverSettingsVC didChangeServerTo:(NSString *)newServer;
- (void)userHasPressedDisconnectInServerSettingsViewController:(ServerSettingsViewController *)serverSettingsVC;
- (void)userHasPressedConnectInServerSettingsViewController:(ServerSettingsViewController *)serverSettingsVC;

@end

@interface ServerSettingsViewController : UIViewController

@property (nonatomic, weak) id<ServerSettingsViewControllerDelegate> delegate;

@property (nonatomic, assign) ServerSetupStatus serverSetupStatus;

- (instancetype)initWithServer:(NSString *)server;

@end
