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

typedef void (^ResourceDownloadCompletionBlock)(NSData *data, NSError *error);


@interface ResourceDownloadManager : NSObject

@property (nonatomic, assign) NSUInteger totalNumberOfSimultaneousDownloads; // Default 10.
@property (nonatomic, assign) NSUInteger numberOfSimultaneousDownloadsPerHost; // Host here is in broader meaning (scheme + hostname + port). By default 5.

+ (ResourceDownloadManager *)sharedInstance;

// At the moment 'securityPolicyClass' should be a AFSecurityPolicy subclass.
// AFSecurityPolicy is a class from AFNetworking 2.0 library.
- (void)registerSecurityPolicyClass:(Class)securityPolicyClass;

/*
 Number is valid only per one instance of ResourceDownloadManager.
 Number 0 is not a valid number of task. 0 signals error.
 */
- (uint64_t)enqueueInMemoryDownloadTaskWithURL:(NSURL *)url completionHandler:(ResourceDownloadCompletionBlock)completionHandler;
- (void)cancelTaskWithNumber:(uint64_t)taskNumber;

- (NSArray *)activeTasksNumbers; // Returns array of NSNumbers containing numbers of tasks.

- (void)cancelAllTasks;

@end
