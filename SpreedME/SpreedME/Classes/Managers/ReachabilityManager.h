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

typedef enum : NSInteger {
    NotReachable = 0,
    ReachableViaWiFi,
    ReachableViaWWAN
} NetworkStatus;


extern NSString * const ReachabilityHasChangedNotification;
extern NSString * const ReachabilityNotificationHostNameKey;
extern NSString * const ReachabilityNotificationNetworkStatusKey;

@interface ReachabilityManager : NSObject

+ (ReachabilityManager *)sharedInstance;

// You can't create 2 reachability objects. If you pass hostName which exists you overwrite previous reachability
- (BOOL)addReachabilityWithHostName:(NSString *)hostName;
- (void)removeReachabilityWithHostName:(NSString *)hostName;

- (NetworkStatus)lastNetworkStatusForHostName:(NSString *)hostName;

@end
