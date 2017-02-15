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

#import "TableViewCellsParameters.h"


typedef enum : NSUInteger {
    kServerConnectionStatusDisconnected = 0,
    kServerConnectionStatusConnecting,
    kServerConnectionStatusConnected,
} ServerConnectionStatus;

@interface STServerSetupTableViewCell : UITableViewCell <CustomTableViewCellProtocol>

@property (nonatomic, strong) UITextField *serverURLTextField;
@property (nonatomic, strong) UILabel *connectionStatusLabel;
@property (nonatomic, strong) UIView *connectionStatusIconView;

@property (nonatomic, assign) ServerConnectionStatus connectionStatus;

@end
