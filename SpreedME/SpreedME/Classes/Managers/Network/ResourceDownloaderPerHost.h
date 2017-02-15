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

#import "ResourceDownloadManager.h"
#import "ResourceDownloadTask.h"

@class ResourceDownloaderPerHost;

@protocol ResourceDownloaderPerHostDelegate <NSObject>
@required
- (void)downloader:(ResourceDownloaderPerHost *)downloader hasFinishedTask:(ResourceDownloadTask *)task withResponseObject:(id)responseObject withError:(NSError *)error;
- (void)downloader:(ResourceDownloaderPerHost *)downloader hasCanceledTask:(ResourceDownloadTask *)task;

@end


@interface ResourceDownloaderPerHost : NSObject

@property (nonatomic, weak) id<ResourceDownloaderPerHostDelegate> delegate;
@property (nonatomic, copy) NSString *hostKey;
@property (nonatomic, assign, readonly) NSUInteger maxNumberOfSimultaneousDownloads;
@property (nonatomic, strong) AFSecurityPolicy *securityPolicy;

- (instancetype)init; //maxNumber - defaults to 5, securityPolicy - nil, which defaults to [AFSecurityPolicy defaultPolicy]
- (instancetype)initWithMaxNumberOfSimultaneousDownloads:(NSUInteger)maxNumber withSecurityPolicy:(AFSecurityPolicy *)securityPolicy;

- (BOOL)canAddTask;

- (BOOL)enqueueInMemoryDownloadTask:(ResourceDownloadTask *)task;
- (void)cancelTask:(ResourceDownloadTask *)task; // Triggers delegate method
- (void)cancelAllTasks; // This cancels all active tasks and wipes all tasks in queue. This call doesn't trigger delegate method

- (NSArray *)activeTasks; // Returns all currently active tasks
- (NSUInteger)numberOfQueuedTasks;

/* 
 If possible starts next (i) task from queue. 
 Returns YES if next (next with regards to 'next' == i + 1) task can be started, 
 NO if there are already maxNumberOfSimultaneousDownloads working or no tasks in queue
 */
- (BOOL)processNextTaskInQueue;


@end
