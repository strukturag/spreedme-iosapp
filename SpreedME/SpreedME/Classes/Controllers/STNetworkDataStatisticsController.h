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

#import "STByteCount.h"


extern NSString * const STNetworkDataBytesHaveBeenSentNotification;
extern NSString * const STNetworkDataBytesHaveBeenReceivedNotification;

extern NSString * const kSTNetworkDataNotificationUserInfoBytesKey; // Value is NSNumber with uint64_t
extern NSString * const kSTNetworkDataNotificationUserInfoServiceNameKey; // Value is NSString

extern NSString * const kSTNetworkDataSaveDirInAppSupportDir;


uint64_t STCalculateNSURLRequestSize(NSURLRequest *request);



@class STNetworkDataStatisticsController;

@protocol STNetworkDataStatisticsControllerDataProvider <NSObject>
@required
- (STByteCount)sentByteCountForNetworkDataStatisticsController:(STNetworkDataStatisticsController *)controller;
- (STByteCount)receivedByteCountForNetworkDataStatisticsController:(STNetworkDataStatisticsController *)controller;
- (void)resetDataStatisticsForNetworkDataStatisticsController:(STNetworkDataStatisticsController *)controller;


@end


/*
 This class is used to count network data usage for different services.
 This class is intended to be subclassed in order to save data persistently.
 You can use the class to count data as is but it will not save data. 
 Please keep in mind that if you call save data it will still reset data counters.
 */

@interface STNetworkDataStatisticsController : NSObject
{
	NSMutableDictionary *_dataProviders;
	
	NSMutableDictionary *_dataStatistics;
	NSMutableDictionary *_lastSavedStatistics;
	
	NSDate *_lastStatisticsResetDate;
	NSDate *_lastStatisticsSaveDate;
}

- (instancetype)initWithSavedEncryptedStatisticsInDir:(NSString *)dir;


/* 
 If you register data provider for service name 
 the method nulifies previously counted bytes for this service.
 Thus this is your respondibility to save it
 before setting data data provider.
 */
- (void)registerDataProvider:(id<STNetworkDataStatisticsControllerDataProvider>)dataProvider
			  forServiceName:(NSString *)serviceName; // This will retain dataProvider! 'serviceName' must not be nil!
/*
 When unregistering data provider for service name
 the method removes previously counted bytes for this service.
 You should handle previously counted bytes before setting provider for the service.
 */
- (void)unregisterDataProviderForServiceName:(NSString *)serviceName; //'serviceName' must not be nil!


- (void)addSentBytes:(uint64_t)sentBytes forServiceName:(NSString *)serviceName;
- (void)addReceivedBytes:(uint64_t)receivedBytes forServiceName:(NSString *)serviceName;
- (void)setSentBytes:(uint64_t)sentBytes forServiceName:(NSString *)serviceName;
- (void)setReceivedBytes:(uint64_t)receivedBytes forServiceName:(NSString *)serviceName;


- (void)addSentByteCount:(STByteCount)sentByteCount forServiceName:(NSString *)serviceName;
- (void)addReceivedByteCount:(STByteCount)receivedByteCount forServiceName:(NSString *)serviceName;
- (void)setSentByteCount:(STByteCount)sentByteCount forServiceName:(NSString *)serviceName;
- (void)setReceivedByteCount:(STByteCount)receiveddByteCount forServiceName:(NSString *)serviceName;


- (STByteCount)sentByteCountForServiceName:(NSString *)serviceName;
- (STByteCount)receivedByteCountForServiceName:(NSString *)serviceName;
- (STByteCount)totalByteCountForServiceName:(NSString *)serviceName;

- (STByteCount)sentByteCountForAllServices;
- (STByteCount)receivedByteCountForAllServices;
- (STByteCount)totalByteCountForAllServices;

- (NSSet *)servicesNames;

- (NSDate *)lastStatisticsResetDate;
- (NSDate *)lastStatisticsSaveDate;
- (void)resetStatistics;
- (void)saveStatisticsToDir:(NSString *)dir;


// these methods should be overriden in subclasses
+ (NSString *)savedStatisticsDir;
- (void)saveStatistics:(NSDictionary *)jsonRepresentedDict toDir:(NSString *)dir;
- (NSDictionary *)loadJsonRepresentedStatisticsFromDir:(NSString *)dir;


@end


@interface STNetworkDataValue : NSObject
{
	STByteCount _sent;
	STByteCount _received;
}

@property (nonatomic, assign) STByteCount sent;
@property (nonatomic, assign) STByteCount received;

@property (nonatomic, readonly) STByteCount total; // dynamic, calculated as sent+received;

@end
