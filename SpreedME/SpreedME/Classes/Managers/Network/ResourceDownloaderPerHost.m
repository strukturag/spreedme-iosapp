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

#import "ResourceDownloaderPerHost.h"

#import "STQueue.h"
#import "STNetworkDataStatisticsController.h"


NSString * const kResourceDownloadTaskInUserInfoKey			= @"kResourceDownloadTaskInUserInfoKey";

NSString * const kResourceDownloadService	= @"ResourceDownloadService";

@interface GeneralResourceResponseSerializer : AFHTTPResponseSerializer
@end

@implementation GeneralResourceResponseSerializer

- (BOOL)validateResponse:(NSHTTPURLResponse *)response
                    data:(NSData *)data
                   error:(NSError * __autoreleasing *)error
{
    BOOL responseIsValid = YES;
    NSError *validationError = nil;
	
    if (response && [response isKindOfClass:[NSHTTPURLResponse class]]) {		
        if (self.acceptableStatusCodes && ![self.acceptableStatusCodes containsIndex:(NSUInteger)response.statusCode]) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Request failed: %@ (%lu)", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], (unsigned long)response.statusCode],
									   NSURLErrorFailingURLErrorKey:[response URL],
                                       AFNetworkingOperationFailingURLResponseErrorKey: response
                                       };
			
            validationError = [NSError errorWithDomain:AFURLResponseSerializationErrorDomain code:NSURLErrorBadServerResponse userInfo:userInfo];
			
            responseIsValid = NO;
        }
    }
	
    if (error && !responseIsValid) {
        *error = validationError;
    }
	
    return responseIsValid;
}

@end



@interface ResourceDownloaderPerHost ()
{
	STQueue *_queue;
	
	NSUInteger _activeTasksNumber;
	
	NSMutableSet *_activeTasks;
	
	AFHTTPRequestOperationManager *_httpRequestOpManager;
	AFHTTPSessionManager *_httpSessionManager;
	
	
	BOOL _iOS7Environment;
}


@end


@implementation ResourceDownloaderPerHost


- (instancetype)initWithMaxNumberOfSimultaneousDownloads:(NSUInteger)maxNumber withSecurityPolicy:(AFSecurityPolicy *)securityPolicy
{
	self = [super init];
	if (self) {
		_maxNumberOfSimultaneousDownloads = maxNumber;
		
		_queue = [[STQueue alloc] init];
		_activeTasks = [[NSMutableSet alloc] init];
		
		_iOS7Environment = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
		
		if (_iOS7Environment) {
			
			NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
			sessionConfig.timeoutIntervalForResource = 60.0 * 60.0 * 24.0; // one day
			sessionConfig.HTTPMaximumConnectionsPerHost = 5;
			
			_httpSessionManager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:sessionConfig];
			_httpSessionManager.responseSerializer = [[GeneralResourceResponseSerializer alloc] init];
			if (securityPolicy) {
				_httpSessionManager.securityPolicy = securityPolicy;
			}
		} else {
			_httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
			_httpRequestOpManager.responseSerializer = [[GeneralResourceResponseSerializer alloc] init];
			
			_httpRequestOpManager.operationQueue.maxConcurrentOperationCount = maxNumber;
			if (securityPolicy) {
				_httpRequestOpManager.securityPolicy = securityPolicy;
			}
		}
		
	}
	return self;
}


- (instancetype)init
{
	return [self initWithMaxNumberOfSimultaneousDownloads:5 withSecurityPolicy:nil];
}


- (void)dealloc
{
	[self cancelAllTasks];
}


#pragma mark - Public methods

- (BOOL)canAddTask
{
	return [_queue canPushNewObject];
}


- (BOOL)enqueueInMemoryDownloadTask:(ResourceDownloadTask *)task
{
	BOOL answer = NO;
	if (task && [_queue canPushNewObject]) {
		[_queue push:task];
		answer = YES;
	}
	return answer;
}


- (void)cancelTask:(ResourceDownloadTask *)task
{
	if (task) {
		
		[_activeTasks removeObject:task];
		
		for (ResourceDownloadTask *lTask in [_queue allObjects]) {
			if (lTask.number == task.number) {
				[_queue removeObject:lTask];
				break;
			}
		}
		
		if (_iOS7Environment) {
			[self canceliOS7Task:task];
		} else {
			[self cancelPrioriOS7Task:task];
		}
		
		[self processNextTaskInQueue];
	} else {
//		NSLog(@"Error: no task to cancel!");
	}
}


- (void)cancelAllTasks
{
	[_queue clear];
	
	if (_iOS7Environment) {
		for (NSURLSessionTask *task in [_httpSessionManager tasks]) {
			[task cancel];
		}
	} else {
		[_httpRequestOpManager.operationQueue cancelAllOperations];
	}
}


- (NSArray *)activeTasks
{
	return [_activeTasks allObjects];
}


- (NSUInteger)numberOfQueuedTasks
{
	return [_queue size];
}


- (BOOL)processNextTaskInQueue
{
	BOOL answer = NO;
	if ([_queue size] > 0 && [_activeTasks count] < _maxNumberOfSimultaneousDownloads) {
		ResourceDownloadTask *task = (ResourceDownloadTask *)[_queue pop];
		[self startTask:task];
	}
	
	return answer;
}


#pragma mark - Private Methods -

- (void)startTask:(ResourceDownloadTask *)task
{
	if (task) {
	
		if (_iOS7Environment) {
			[self startTaskiOS7:task];
		} else {
			[self startTaskPrioriOS7:task];
		}
		
		[_activeTasks addObject:task];
		
	} else {
//		NSLog(@"Error: no task to start!");
	}
}


- (void)startTaskiOS7:(ResourceDownloadTask *)task
{
	if (_httpSessionManager) {
		
		NSURLSessionDataTask *nsTask = [_httpSessionManager GET:[task.url absoluteString] parameters:nil success:^(NSURLSessionDataTask *urlSessionTask, id responseObject) {
			[self hasFinishedTask:task withResponseObject:responseObject error:nil];
			
			
			if (urlSessionTask.countOfBytesReceived > 0) {
				[[NSNotificationCenter defaultCenter]
				 postNotificationName:STNetworkDataBytesHaveBeenReceivedNotification
				 object:nil
				 userInfo:@{kSTNetworkDataNotificationUserInfoBytesKey : @(urlSessionTask.countOfBytesReceived),
							kSTNetworkDataNotificationUserInfoServiceNameKey : kResourceDownloadService}];
			}
			
			if (urlSessionTask.countOfBytesSent > 0) {
				[[NSNotificationCenter defaultCenter]
				 postNotificationName:STNetworkDataBytesHaveBeenSentNotification
				 object:nil
				 userInfo:@{kSTNetworkDataNotificationUserInfoBytesKey : @(urlSessionTask.countOfBytesSent),
							kSTNetworkDataNotificationUserInfoServiceNameKey : kResourceDownloadService}];
			}
			
		} failure:^(NSURLSessionDataTask *urlSessionTask, NSError *error) {
			
			if (urlSessionTask.countOfBytesReceived > 0) {
				[[NSNotificationCenter defaultCenter]
				 postNotificationName:STNetworkDataBytesHaveBeenReceivedNotification
				 object:nil
				 userInfo:@{kSTNetworkDataNotificationUserInfoBytesKey : @(urlSessionTask.countOfBytesReceived),
							kSTNetworkDataNotificationUserInfoServiceNameKey : kResourceDownloadService}];
			}
			
			if (urlSessionTask.countOfBytesSent > 0) {
				[[NSNotificationCenter defaultCenter]
				 postNotificationName:STNetworkDataBytesHaveBeenSentNotification
				 object:nil
				 userInfo:@{kSTNetworkDataNotificationUserInfoBytesKey : @(urlSessionTask.countOfBytesSent),
							kSTNetworkDataNotificationUserInfoServiceNameKey : kResourceDownloadService}];
			}
			
			
			[self hasFinishedTask:task withResponseObject:nil error:error];
		}];
		
		task.contextNumber = nsTask.taskIdentifier;
		task.pointer = (__bridge void *)nsTask;
		
		uint64_t requestSize = STCalculateNSURLRequestSize(nsTask.currentRequest);
		
		[[NSNotificationCenter defaultCenter] postNotificationName:STNetworkDataBytesHaveBeenSentNotification
															object:nil
														  userInfo:@{kSTNetworkDataNotificationUserInfoBytesKey : @(requestSize),
																	 kSTNetworkDataNotificationUserInfoServiceNameKey : kResourceDownloadService}];
	} else {
//		NSLog(@"Error: no _httpSessionManager!");
	}
}


- (void)startTaskPrioriOS7:(ResourceDownloadTask *)task
{
	if (_httpRequestOpManager) {
		
		NSString *urlString = [task.url absoluteString];
		
		AFHTTPRequestOperation *operation = [_httpRequestOpManager GET:urlString parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
			[self hasFinishedTask:task withResponseObject:responseObject error:nil];
			
			if ([responseObject isKindOfClass:[NSData class]]) {
				NSUInteger dataLength = [responseObject length];
				if (dataLength > 0) {
					[[NSNotificationCenter defaultCenter]
					 postNotificationName:STNetworkDataBytesHaveBeenReceivedNotification
					 object:nil
					 userInfo:@{kSTNetworkDataNotificationUserInfoBytesKey : @(dataLength),
								kSTNetworkDataNotificationUserInfoServiceNameKey : kResourceDownloadService}];
				}
			}
			
		} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			[self hasFinishedTask:task withResponseObject:nil error:error];
			
			if ([operation.responseData isKindOfClass:[NSData class]]) {
				NSUInteger dataLength = [operation.responseData length];
				if (dataLength) {
					[[NSNotificationCenter defaultCenter]
					 postNotificationName:STNetworkDataBytesHaveBeenReceivedNotification
					 object:nil
					 userInfo:@{kSTNetworkDataNotificationUserInfoBytesKey : @(dataLength),
								kSTNetworkDataNotificationUserInfoServiceNameKey : kResourceDownloadService}];
				}
			}
		}];
		
		uint64_t requestSize = STCalculateNSURLRequestSize(operation.request);
		
		if (requestSize > 0) {
			[[NSNotificationCenter defaultCenter]
			 postNotificationName:STNetworkDataBytesHaveBeenSentNotification
			 object:nil
			 userInfo:@{kSTNetworkDataNotificationUserInfoBytesKey : @(requestSize),
						kSTNetworkDataNotificationUserInfoServiceNameKey : kResourceDownloadService}];
		}
		
		
		[operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
			if (bytesWritten > 0) {
				[[NSNotificationCenter defaultCenter]
				 postNotificationName:STNetworkDataBytesHaveBeenSentNotification
				 object:nil
				 userInfo:@{kSTNetworkDataNotificationUserInfoBytesKey : @(bytesWritten),
							kSTNetworkDataNotificationUserInfoServiceNameKey : kResourceDownloadService}];
			}
		}];
		
		operation.userInfo = @{kResourceDownloadTaskInUserInfoKey : task};
		
	} else {
//		NSLog(@"Error: no _httpRequestOpManager!");
	}
}


- (void)hasFinishedTask:(ResourceDownloadTask *)task withResponseObject:(id)responseObject error:(NSError *)error
{
	[self processNextTaskInQueue];
	[_activeTasks removeObject:task];
	[self.delegate downloader:self hasFinishedTask:task withResponseObject:responseObject withError:error];
}


- (void)canceliOS7Task:(ResourceDownloadTask *)task
{
	// Cancel running tasks
	for (NSURLSessionTask *nsTask in [_httpSessionManager tasks]) {
		if (nsTask.taskIdentifier == task.contextNumber) {
			[nsTask cancel];
			
			[self.delegate downloader:self hasCanceledTask:task];
			
			break;
		}
	}
}


- (void)cancelPrioriOS7Task:(ResourceDownloadTask *)task
{
	for (AFHTTPRequestOperation *operation in _httpRequestOpManager.operationQueue.operations) {
		ResourceDownloadTask *lTask = (ResourceDownloadTask *)[operation.userInfo objectForKey:kResourceDownloadTaskInUserInfoKey];
		if (lTask.number == task.number) {
			[operation cancel];
			
			[self.delegate downloader:self hasCanceledTask:task];
			
			break;
		}
	}
}


- (NSString *)toString:(NSURLSessionConfiguration *)sessionConfig
{
	NSString *desc = @"";
	
	if (sessionConfig.identifier) {
		desc = [desc stringByAppendingFormat:@"identifier %@", sessionConfig.identifier];
	}
	
	desc = [desc stringByAppendingFormat:@"\nrequestCachePolicy %u", sessionConfig.requestCachePolicy];
	
	desc = [desc stringByAppendingFormat:@"\ntimeoutIntervalForRequest %.3f", sessionConfig.timeoutIntervalForRequest];
	desc = [desc stringByAppendingFormat:@"\ntimeoutIntervalForResource %.3f", sessionConfig.timeoutIntervalForResource];
	
	desc = [desc stringByAppendingFormat:@"\nnetworkServiceType %d", sessionConfig.networkServiceType];
	
	desc = [desc stringByAppendingFormat:@"\nallowsCellularAccess %@", sessionConfig.allowsCellularAccess ? @"YES" : @"NO"];
	
#if TARGET_OS_IPHONE
	desc = [desc stringByAppendingFormat:@"\ndiscretionary %@", sessionConfig.discretionary ? @"YES" : @"NO"];
	
	desc = [desc stringByAppendingFormat:@"\nsessionSendsLaunchEvents %@", sessionConfig.sessionSendsLaunchEvents ? @"YES" : @"NO"];
#endif
	
	desc = [desc stringByAppendingFormat:@"\nconnectionProxyDictionary %@", sessionConfig.connectionProxyDictionary];
	
	desc = [desc stringByAppendingFormat:@"\nTLSMinimumSupportedProtocol %d", sessionConfig.TLSMinimumSupportedProtocol];
	
	desc = [desc stringByAppendingFormat:@"\nTLSMaximumSupportedProtocol %d", sessionConfig.TLSMaximumSupportedProtocol];
	
	desc = [desc stringByAppendingFormat:@"\nHTTPShouldUsePipelining %@", sessionConfig.HTTPShouldUsePipelining ? @"YES" : @"NO"];
	
	desc = [desc stringByAppendingFormat:@"\nHTTPShouldSetCookies %@", sessionConfig.HTTPShouldSetCookies ? @"YES" : @"NO"];
	
	desc = [desc stringByAppendingFormat:@"\nHTTPCookieAcceptPolicy %u", sessionConfig.HTTPCookieAcceptPolicy];
	
	desc = [desc stringByAppendingFormat:@"\nHTTPAdditionalHeaders %@", sessionConfig.HTTPAdditionalHeaders];
	
	desc = [desc stringByAppendingFormat:@"\nHTTPMaximumConnectionsPerHost %u", sessionConfig.HTTPMaximumConnectionsPerHost];
	
	desc = [desc stringByAppendingFormat:@"\nHTTPCookieStorage %@", sessionConfig.HTTPCookieStorage];
	
	desc = [desc stringByAppendingFormat:@"\nURLCredentialStorage %@", sessionConfig.URLCredentialStorage];
	
	desc = [desc stringByAppendingFormat:@"\nURLCache %@", sessionConfig.URLCache];
	
	desc = [desc stringByAppendingFormat:@"\nprotocolClasses %@", sessionConfig.protocolClasses];
	
	return desc;
}


@end
