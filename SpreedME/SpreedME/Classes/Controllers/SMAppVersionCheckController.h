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

#import "AFNetworking.h"
#import "CommonNetDefinitions.h"

#if defined __cplusplus
extern "C" {
#endif

// This function works correctly only with iOS/Mac versioning scheme 'x.x.x.x' where x is int number
NSArray * SMStringVersionNumberToIntArray(NSString *version);
// This function doesn't check for arguments sanity, it is responsibility of caller to pass correct arguments.
// Please also note that if you pass versions with different length like 1.0.1 and 2.0 they will be compared
// as if we remove numbers from the larger version number, e.g. 1.0(instead of 1.0.1) vs 2.0
NSComparisonResult SMCompareVersionArrays(NSArray *ver1, NSArray *ver2);

#if defined __cplusplus
} // extern "C"
#endif


typedef void (^SMReceivedAppVersionsBlock)(NSString *minimalVersion, NSString *newestAvailVersion);

@interface SMAppVersionCheckController : NSObject <UIAlertViewDelegate>

@property (nonatomic, copy) NSString *appStoreLinkToApp;

- (instancetype)initWithEndpoint:(NSString *)endpoint securityPolicy:(AFSecurityPolicy *)policy;


- (void)startPeriodicChecksWithInterval:(NSTimeInterval)interval
                     andCompletionBlock:(SMReceivedAppVersionsBlock)block;
- (void)stopPeriodicChecks;

// Setting interval or completion block doesn't restart periodic checks but rather apply these changes on the next check.
// If you want to change these settings immediately stop and start periodic changes.
- (void)setVersionCheckInterval:(NSTimeInterval)interval; // Doesn't allow setting interval less than 30s.
- (void)setPeriodicChecksComplBlock:(SMReceivedAppVersionsBlock)block;

- (id<STNetworkOperation>)getApplicationInformationVersionWithComplBlock:(SMReceivedAppVersionsBlock)block;

// Notification methods
- (void)notifyUserAboutAvailableUpdateToVersion:(NSString *)version;


@end
