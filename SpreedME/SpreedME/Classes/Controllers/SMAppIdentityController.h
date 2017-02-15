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
    kiOSDeviceUnsupported = 0,
	
    kiOSDeviceiPhone4,
    kiOSDeviceiPhone4s,
	kiOSDeviceiPhone5,
	kiOSDeviceiPhone5c,
	kiOSDeviceiPhone5s,
	kiOSDeviceiPhone6,
	kiOSDeviceiPhone6Plus,
	
	kiOSDeviceiPad2,
	kiOSDeviceiPad3, // new iPad
	kiOSDeviceiPad4, // ipad 4
	kiOSDeviceiPadAir, // iPad Air
	
	kiOSDeviceiPadMini1,
	kiOSDeviceiPadMini2, // iPad mini with retina
	
	kiOSDeviceiPod4,
	kiOSDeviceiPod5
	
} iOSDeviceModel;


@interface SMAppIdentityController : NSObject

@property (nonatomic, copy) NSString *clientSecret;

+ (instancetype)sharedInstance;

- (NSInteger)version;
- (NSString *)clientId;
- (NSString *)applicationId;
- (NSString *)applicationName;

- (NSString *)installationUID;
- (NSString *)defaultUserUID;
- (NSData *)appBigIdentifier;

- (void)initForFirstAppLaunch;


@end
