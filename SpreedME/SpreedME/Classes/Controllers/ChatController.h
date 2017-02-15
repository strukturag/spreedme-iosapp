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

#import "STChatViewController.h"
#import "UserActivityManager.h"


extern NSString * const ChatViewControllerDidAppearNotification; // This notification contains userInfo dictionary with 'userSessionId' value for 'kChatControllerUserSessionIdKey' key
extern NSString * const kChatControllerUserSessionIdKey;

@interface ChatController : NSObject <STChatViewControllerDataSource, STChatViewControllerDelegate, UserActivityManagerListener>

@property (nonatomic, weak) STChatViewController *chatViewController; // This property has to be weak in order not to make retain cycle if ChatController is retained by STChatViewController 

- (id)initWithUserActivityManager:(UserActivityManager *)userActivityManager;

@end
