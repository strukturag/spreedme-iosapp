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

#import "ResourceDownloadManager.h"

#import "ResourceDownloaderPerHost.h"
#import "ResourceDownloadTask.h"
#import "STQueue.h"


@interface ResourceDownloadManager() <ResourceDownloaderPerHostDelegate>
{
	NSMutableDictionary *_downloaders;
	
	STQueue *_generalQueue;
	NSUInteger _activeTasks;
	
	uint64_t _numberBase;
	
	uint64_t _totalProcessed;
	
	Class _securityPolicyClass;
}


@end


@implementation ResourceDownloadManager

+ (ResourceDownloadManager *)sharedInstance
{
	static dispatch_once_t once;
    static ResourceDownloadManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


#pragma mark - Object lifecycle

- (instancetype)init
{
	self = [super init];
	if (self) {
		
		_totalNumberOfSimultaneousDownloads = 10;
		_numberOfSimultaneousDownloadsPerHost = 5;
		
		_numberBase = 1;
		
		_generalQueue = [[STQueue alloc] init];
		
		_downloaders = [[NSMutableDictionary alloc] init];
		
		_securityPolicyClass = [AFSecurityPolicy class];
	}
	return self;
}


#pragma mark - Utility Methods

// Number 0 is not a valid number of task. 0 signals error.
- (uint64_t)getNewNumberForTask
{
	uint64_t newNumber = 0;
	if (_numberBase < UINT64_MAX) {
		newNumber = _numberBase;
		++_numberBase;
	} else {
		newNumber = 1;
		_numberBase = 2;
	}
	
	return newNumber;
}


- (NSString *)composeHostKeyFromURL:(NSURL *)url
{
	NSString *hostKey = nil;
	
	NSString *urlScheme = [url scheme];
	NSString *urlHost = [url host];
	
	if (urlHost && urlScheme) {
		
		NSNumber *urlPort = [url port];
		// Default to port 80
		if (!urlPort) {
			urlPort = @(80);
		}
		
		hostKey = [NSString stringWithFormat:@"%@:%@:%@", urlScheme, urlHost, urlPort];
	} else {
		spreed_me_log("Can't retreive host and/or scheme from url %s", [url cDescription]);
	}
	
	return hostKey;
}


- (void)processGeneralQueue
{
	if (self.totalNumberOfSimultaneousDownloads <= _activeTasks) {
		return;
	}
	
	ResourceDownloadTask *task = (ResourceDownloadTask *)[_generalQueue pop];
	
	if (task) {
		
		[self enqueueTask:task];
		if (self.totalNumberOfSimultaneousDownloads < _activeTasks) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[self processGeneralQueue];
			});
		}
	} else {
//		NSLog(@"%@ _general queue is empty", self);
	}
}


- (NSArray *)activeTasks
{
	NSMutableArray *array = [NSMutableArray new];
	for (NSString *key in [_downloaders allKeys]) {
		ResourceDownloaderPerHost *downloader = [_downloaders objectForKey:key];
		[array addObjectsFromArray:[downloader activeTasks]];
	}
	
	return [NSArray arrayWithArray:array];
}


- (void)enqueueTask:(ResourceDownloadTask *)task
{
	ResourceDownloaderPerHost *downloader = [_downloaders objectForKey:task.hostKey];
	
	if (!downloader) {
		downloader = [[ResourceDownloaderPerHost alloc] initWithMaxNumberOfSimultaneousDownloads:self.numberOfSimultaneousDownloadsPerHost
																			  withSecurityPolicy:[_securityPolicyClass defaultPolicy]];
		downloader.delegate = self;
		[_downloaders setObject:downloader forKey:task.hostKey];
	}
	
	if ([downloader canAddTask]) {
		++_totalProcessed;
		[downloader enqueueInMemoryDownloadTask:task];
		while ([downloader processNextTaskInQueue]) {};
	} else {
		spreed_me_log("Can't add new task when this should be possible!");
	}
	
	++_activeTasks;
}


- (void)cancelTask:(ResourceDownloadTask *)task
{
	ResourceDownloaderPerHost *downloader = [_downloaders objectForKey:task.hostKey];
	[downloader cancelTask:task];
}


- (void)taskHasBeenFinished:(ResourceDownloadTask *)task
{
	--_activeTasks;
	
	ResourceDownloaderPerHost *downloader = [_downloaders objectForKey:task.hostKey];
	
	[self processGeneralQueue];
	
	if ([[downloader activeTasks] count] == 0 && [downloader numberOfQueuedTasks] == 0) {
		[_downloaders removeObjectForKey:task.hostKey];
	}
}


- (void)taskHasBeenCanceled:(ResourceDownloadTask *)task
{
	--_activeTasks;
	
	[self processGeneralQueue];
}


#pragma mark - Public Methods

- (void)registerSecurityPolicyClass:(Class)securityPolicyClass
{
	if (securityPolicyClass) {
		_securityPolicyClass = securityPolicyClass;
	} else {
		_securityPolicyClass = [AFSecurityPolicy class];
	}
}


- (uint64_t)enqueueInMemoryDownloadTaskWithURL:(NSURL *)url completionHandler:(ResourceDownloadCompletionBlock)completionHandler
{
	uint64_t taskNumber = 0;
	
	if (url && completionHandler) {
	
		taskNumber = [self getNewNumberForTask];
		NSString *hostKey = [self composeHostKeyFromURL:url];

		if (taskNumber && hostKey) {
			ResourceDownloadTask *task = [[ResourceDownloadTask alloc] init];
			task.url = url;
			task.block = completionHandler;
			task.number = taskNumber;
			task.hostKey = hostKey;
			
			if ([_generalQueue canPushNewObject]) {
				[_generalQueue push:task];
				[self processGeneralQueue];
			} else {
				spreed_me_log("%s %p: general queue is full with length %llu", [NSStringFromClass([self class]) cDescription], self, _generalQueue.length);
				NSAssert(@"NO", @"general queue is full");
			}
			
		} else {
			spreed_me_log("Error couldn't create taskNumber or hostKey for url %s", [url cDescription]);
			NSAssert(NO, @"Error couldn't create taskNumber or hostKey");
		}
	} else {
		spreed_me_log("%s: url or/and completionHandler nil", [NSStringFromClass([self class]) cDescription]);
	}
	
	return taskNumber;
}


- (void)cancelTaskWithNumber:(uint64_t)taskNumber
{
	BOOL found = NO;
	
	for (ResourceDownloadTask *task in [self activeTasks]) {
		if (task.number == taskNumber) {
			found = YES;
			[self cancelTask:task];
			break;
		}
	}
	
	if (!found) {
		spreed_me_log("Couldn't find task with task number %llu in %s", taskNumber, [self cDescription]);
	}
}


- (NSArray *)activeTasksNumbers
{
	NSMutableArray *numbers = [NSMutableArray array];
	NSArray *activeTasks = [self activeTasksNumbers];
	
	for (ResourceDownloadTask *task in activeTasks) {
		[numbers addObject:@(task.number)];
	}
	
	return [NSArray arrayWithArray:numbers];
}


- (void)cancelAllTasks
{
	[_generalQueue clear];
	for (NSString *host in _downloaders) {
		ResourceDownloaderPerHost *downloader = [_downloaders objectForKey:host];
		[downloader cancelAllTasks];
	}
	
	[_downloaders removeAllObjects];
}


#pragma mark - Public Getters/Setters

- (void)setNumberOfSimultaneousDownloadsPerHost:(NSUInteger)numberOfSimultaneousDownloadsPerHost
{
	NSAssert(numberOfSimultaneousDownloadsPerHost != 0, @"numberOfSimultaneousDownloadsPerHost can't be zero");
	_numberOfSimultaneousDownloadsPerHost = numberOfSimultaneousDownloadsPerHost;
}


- (void)setTotalNumberOfSimultaneousDownloads:(NSUInteger)totalNumberOfSimultaneousDownloads
{
	NSAssert(totalNumberOfSimultaneousDownloads != 0, @"totalNumberOfSimultaneousDownloads can't be zero");
	_totalNumberOfSimultaneousDownloads = totalNumberOfSimultaneousDownloads;
}


#pragma mark - ResourceDownloaderPerHostDelegate Delegate

- (void)downloader:(ResourceDownloaderPerHost *)downloader hasCanceledTask:(ResourceDownloadTask *)task
{
	[self taskHasBeenCanceled:task];
}


- (void)downloader:(ResourceDownloaderPerHost *)downloader hasFinishedTask:(ResourceDownloadTask *)task withResponseObject:(id)responseObject withError:(NSError *)error
{
	[self taskHasBeenFinished:task];
	
	if (!error && [responseObject isKindOfClass:[NSData class]]) {
		if (task.block) {
			task.block(responseObject, nil);
		}
	} else if (error) {
		if (task.block) {
			task.block(nil, error);
		}
	} else if (!error && ![responseObject isKindOfClass:[NSData class]]) {
		spreed_me_log("Response object is NOT data!!!");
		NSAssert(NO, @"Response object is NOT data!!!");
	}
}


@end
