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

#import "STNetworkDataStatisticsController.h"

NSString * const STNetworkDataBytesHaveBeenSentNotification					= @"STNetworkDataBytesHaveBeenSentNotification";
NSString * const STNetworkDataBytesHaveBeenReceivedNotification				= @"STNetworkDataBytesHaveBeenReceivedNotification";

NSString * const kSTNetworkDataNotificationUserInfoBytesKey					= @"bytes";
NSString * const kSTNetworkDataNotificationUserInfoServiceNameKey			= @"serviceName";


NSString * const kSTNetworkDataSaveDirInAppSupportDir				= @"net_data_usage";

// Keys for json representation dict
NSString * const kSTNetworkDataSaveStatisticsServiceNameKey				= @"serviceName";
NSString * const kSTNetworkDataSaveStatisticsSentBytesKey				= @"sentBytes";
NSString * const kSTNetworkDataSaveStatisticsSentBytesOverflowsKey		= @"sentBytesOverflows";
NSString * const kSTNetworkDataSaveStatisticsReceivedBytesKey			= @"receivedBytes";
NSString * const kSTNetworkDataSaveStatisticsReceivedBytesOverflowsKey	= @"receivedBytesOverflows";
NSString * const kSTNetworkDataSaveStatisticsLastSaveTimeStampKey		= @"lastSaveTimeStamp";
NSString * const kSTNetworkDataSaveStatisticsLastResetTimeStampKey		= @"lastResetTimeStamp";
NSString * const kSTNetworkDataSaveStatisticsServicesArrayKey			= @"servicesArray";




uint64_t STCalculateNSURLRequestSize(NSURLRequest *request)
{
	uint64_t size = 0;
	
	if (request) {
		NSDictionary *headers = [request allHTTPHeaderFields];
		
		NSString *str = @"";
		
		for (NSString *key in [headers allKeys]) {
			str = [str stringByAppendingFormat:@"\r\n\r\n%@:%@", key, [headers objectForKey:key]];
		}
		
		NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
		size = (uint64_t)data.length;
	}

	return size;
}


@implementation STNetworkDataStatisticsController

#pragma mark - Object lifecycle

- (instancetype)init
{
	self = [super init];
	if (self) {
		_dataProviders = [[NSMutableDictionary alloc] init];
		_dataStatistics = [[NSMutableDictionary alloc] init];
		_lastSavedStatistics = [[NSMutableDictionary alloc] init];
		_lastStatisticsResetDate = [NSDate date];
		_lastStatisticsSaveDate = [NSDate date];
	}
	return self;
}


- (instancetype)initWithSavedEncryptedStatisticsInDir:(NSString *)dir
{
	self = [self init];
	if (self) {
		NSDictionary *dict = [self loadJsonRepresentedStatisticsFromDir:dir];
		[self loadStatisticsFromJsonRepresentedDictionary:dict];
	}
	
	return self;
}


#pragma mark - Public -
#pragma mark - DataProviders
- (void)registerDataProvider:(id<STNetworkDataStatisticsControllerDataProvider>)dataProvider
			  forServiceName:(NSString *)serviceName
{
	if (dataProvider) {
		[_dataProviders setObject:dataProvider forKey:serviceName];
		
		// This is needed for proper calculation for all services. We rely on _dataStatistics keys there!
		STNetworkDataValue *valueInStatistics = [_dataStatistics objectForKey:serviceName];
		if (!valueInStatistics) {
			valueInStatistics = [[STNetworkDataValue alloc] init];
		}
		valueInStatistics.sent = STByteCountMakeZero();
		valueInStatistics.received = STByteCountMakeZero();
		[_dataStatistics setObject:valueInStatistics forKey:serviceName];
	}
}


- (void)unregisterDataProviderForServiceName:(NSString *)serviceName
{
	// Check if we have data provider to avoid unintentional removal of valid byteCounts from _dataStatistics
	if ([_dataProviders objectForKey:serviceName]) {
		[_dataProviders removeObjectForKey:serviceName];
	
		[_dataStatistics removeObjectForKey:serviceName];
	}
}


#pragma mark - Accounting bytes

- (void)addSentBytes:(uint64_t)sentBytes forServiceName:(NSString *)serviceName
{
	if (!serviceName) {	return;	}
	
	STNetworkDataValue *data = [_dataStatistics objectForKey:serviceName];
	if (!data) {
		data = [[STNetworkDataValue alloc] init];
	}
	
	STByteCount sent = data.sent;
	STAddBytesToByteCount(sentBytes, &sent);
	data.sent = sent;
	
	[_dataStatistics setObject:data forKey:serviceName];
}


- (void)addReceivedBytes:(uint64_t)receivedBytes forServiceName:(NSString *)serviceName
{
	if (!serviceName) {	return;	}
	
	STNetworkDataValue *data = [_dataStatistics objectForKey:serviceName];
	if (!data) {
		data = [[STNetworkDataValue alloc] init];
	}
	
	STByteCount received = data.received;
	STAddBytesToByteCount(receivedBytes, &received);
	data.received = received;
	
	[_dataStatistics setObject:data forKey:serviceName];

}


- (void)setSentBytes:(uint64_t)sentBytes forServiceName:(NSString *)serviceName
{
	if (!serviceName) {	return;	}
	
	STNetworkDataValue *data = [_dataStatistics objectForKey:serviceName];
	if (!data) {
		data = [[STNetworkDataValue alloc] init];
	}
	
	STByteCount sent = {sentBytes, 0};
	
	data.sent = sent;
	
	[_dataStatistics setObject:data forKey:serviceName];
}


- (void)setReceivedBytes:(uint64_t)receivedBytes forServiceName:(NSString *)serviceName
{
	if (!serviceName) {	return;	}
	
	STNetworkDataValue *data = [_dataStatistics objectForKey:serviceName];
	if (!data) {
		data = [[STNetworkDataValue alloc] init];
	}
	
	STByteCount received = {receivedBytes, 0};
	
	data.received = received;
	
	[_dataStatistics setObject:data forKey:serviceName];
}


- (void)addSentByteCount:(STByteCount)sentByteCount forServiceName:(NSString *)serviceName
{
	if (!serviceName) {	return;	}
	
	STNetworkDataValue *data = [_dataStatistics objectForKey:serviceName];
	if (!data) {
		data = [[STNetworkDataValue alloc] init];
	}
	
	STByteCount sent = data.sent;
	STAddByteCountToByteCount(sentByteCount, &sent);
	data.sent = sent;
	
	[_dataStatistics setObject:data forKey:serviceName];
}


- (void)addReceivedByteCount:(STByteCount)receiveddByteCount forServiceName:(NSString *)serviceName
{
	if (!serviceName) {	return;	}
	
	STNetworkDataValue *data = [_dataStatistics objectForKey:serviceName];
	if (!data) {
		data = [[STNetworkDataValue alloc] init];
	}
	
	STByteCount received = data.received;
	STAddByteCountToByteCount(receiveddByteCount, &received);
	data.received = received;
	
	[_dataStatistics setObject:data forKey:serviceName];
}


- (void)setSentByteCount:(STByteCount)sentByteCount forServiceName:(NSString *)serviceName
{
	if (!serviceName) {	return;	}
	
	STNetworkDataValue *data = [_dataStatistics objectForKey:serviceName];
	if (!data) {
		data = [[STNetworkDataValue alloc] init];
	}
	
	data.sent = sentByteCount;
	
	[_dataStatistics setObject:data forKey:serviceName];
}


- (void)setReceivedByteCount:(STByteCount)receivedByteCount forServiceName:(NSString *)serviceName
{
	if (!serviceName) {	return;	}
	
	STNetworkDataValue *data = [_dataStatistics objectForKey:serviceName];
	if (!data) {
		data = [[STNetworkDataValue alloc] init];
	}
	
	data.received = receivedByteCount;
	
	[_dataStatistics setObject:data forKey:serviceName];
}


#pragma mark - Giving statistics

- (STByteCount)sentByteCountForServiceName:(NSString *)serviceName
{
	STByteCount byteCount = STByteCountMakeInvalid();
	
	if (serviceName) {
		id<STNetworkDataStatisticsControllerDataProvider> dataProvider = [_dataProviders objectForKey:serviceName];
		if (dataProvider) {
			byteCount = [dataProvider sentByteCountForNetworkDataStatisticsController:self];
		} else {
			
			STNetworkDataValue *dataValue = [_dataStatistics objectForKey:serviceName];
			if (dataValue) {
				byteCount = dataValue.sent;
			}
		}
        STNetworkDataValue *savedDataValue = [_lastSavedStatistics objectForKey:serviceName];
        if (savedDataValue) {
            if (STIsByteCountValid(byteCount) && STIsByteCountValid(savedDataValue.sent)) {
                byteCount = STAddByteCounts(byteCount, savedDataValue.sent);
            }
        }
	}
	
	return byteCount;
}


- (STByteCount)receivedByteCountForServiceName:(NSString *)serviceName
{
	STByteCount byteCount = STByteCountMakeInvalid();
	
	if (serviceName) {
		id<STNetworkDataStatisticsControllerDataProvider> dataProvider = [_dataProviders objectForKey:serviceName];
		if (dataProvider) {
			byteCount = [dataProvider receivedByteCountForNetworkDataStatisticsController:self];
		} else {
			
			STNetworkDataValue *dataValue = [_dataStatistics objectForKey:serviceName];
			if (dataValue) {
				byteCount = dataValue.received;
			}
		}
        STNetworkDataValue *savedDataValue = [_lastSavedStatistics objectForKey:serviceName];
        if (savedDataValue) {
            if (STIsByteCountValid(byteCount) && STIsByteCountValid(savedDataValue.received)) {
                byteCount = STAddByteCounts(byteCount, savedDataValue.received);
            }
        }
	}
	
	return byteCount;
}


- (STByteCount)totalByteCountForServiceName:(NSString *)serviceName
{
	STByteCount byteCount = STByteCountMakeInvalid();
	
	if (serviceName) {
        STByteCount sentByteCount = [self sentByteCountForServiceName:serviceName];
        STByteCount receivedByteCount = [self receivedByteCountForServiceName:serviceName];
        if (STIsByteCountValid(sentByteCount) && STIsByteCountValid(receivedByteCount)) {
            byteCount = STAddByteCounts(sentByteCount, receivedByteCount);
        }
	}
	
	return byteCount;
}


- (STByteCount)sentByteCountForAllServices
{
	STByteCount byteCount = STByteCountMakeZero();
	if ([_dataStatistics count]) {
		
		NSArray *services = [_dataStatistics allKeys];
		for (NSString *serviceName in services) {
			
			STByteCount sentBytesForService = [self sentByteCountForServiceName:serviceName];
			
			if (STIsByteCountValid(sentBytesForService)) {
				STAddByteCountToByteCount(sentBytesForService, &byteCount);
			}
		}
	}
	
	return byteCount;
}


- (STByteCount)receivedByteCountForAllServices
{
	STByteCount byteCount = STByteCountMakeZero();
	if ([_dataStatistics count]) {
		
		NSArray *services = [_dataStatistics allKeys];
		for (NSString *serviceName in services) {
			
			STByteCount receivedBytesForService = [self receivedByteCountForServiceName:serviceName];
			
			if (STIsByteCountValid(receivedBytesForService)) {
				STAddByteCountToByteCount(receivedBytesForService, &byteCount);
			}
        }
	}
	
	return byteCount;
}


- (STByteCount)totalByteCountForAllServices
{
	STByteCount sent = [self sentByteCountForAllServices];
	STByteCount received = [self receivedByteCountForAllServices];
	return STAddByteCounts(sent, received);
}


#pragma mark - Utilities

- (NSSet *)servicesNames
{
	return [NSSet setWithArray:[_dataStatistics allKeys]];
}


- (void)removeStatisticsFromDisk
{
	NSError *error = nil;
	BOOL success = [[NSFileManager defaultManager] removeItemAtPath:[[self class] savedStatisticsDir] error:&error];
	if (!success) {
		spreed_me_log("Couldn't remove statistics. %s", [error cDescription]);
	}
}


#pragma mark - Saving statistics

- (void)resetStatistics
{
	[self removeStatisticsFromDisk];
	
	
	NSArray *services = [_dataStatistics allKeys];
	for (NSString *serviceName in services) {
		
		id<STNetworkDataStatisticsControllerDataProvider> dataProvider = [_dataProviders objectForKey:serviceName];
		if (dataProvider) {
			// reset dataprovider
			[dataProvider resetDataStatisticsForNetworkDataStatisticsController:self];
			
		}
	}
	
	[_dataStatistics removeAllObjects];
	[_lastSavedStatistics removeAllObjects];
	
	_lastStatisticsResetDate = [NSDate date];
	_lastStatisticsSaveDate = [NSDate date];
}


- (void)saveStatisticsToDir:(NSString *)dir
{
	_lastStatisticsSaveDate = [NSDate date];
	
	if ([_dataStatistics count]) {
		
		NSArray *services = [_dataStatistics allKeys];
		for (NSString *serviceName in services) {
			
			STByteCount receivedBytesForService = STByteCountMakeZero();
			STByteCount sentBytesForService = STByteCountMakeZero();
			
			id<STNetworkDataStatisticsControllerDataProvider> dataProvider = [_dataProviders objectForKey:serviceName];
			if (dataProvider) {
				// grab data
				receivedBytesForService = [dataProvider receivedByteCountForNetworkDataStatisticsController:self];
				sentBytesForService = [dataProvider sentByteCountForNetworkDataStatisticsController:self];
				
				// reset dataprovider
				[dataProvider resetDataStatisticsForNetworkDataStatisticsController:self];
				
			} else {
				
				STNetworkDataValue *dataValue = [_dataStatistics objectForKey:serviceName];
				receivedBytesForService = dataValue.received;
				sentBytesForService = dataValue.sent;
				
				// reset counts
				dataValue.received = STByteCountMakeZero();
				dataValue.sent = STByteCountMakeZero();
				[_dataStatistics setObject:dataValue forKey:serviceName];
			}
		
			STNetworkDataValue *dataValue = [_lastSavedStatistics objectForKey:serviceName];
			if (!dataValue) {
				dataValue = [[STNetworkDataValue alloc] init];
			}
			
			dataValue.sent = STAddByteCounts(dataValue.sent, sentBytesForService);
			dataValue.received = STAddByteCounts(dataValue.received, receivedBytesForService);
			
			[_lastSavedStatistics setObject:dataValue forKey:serviceName];
		}
		
		[self saveStatistics:[self jsonRepresentedDictionaryFromSavedStatistics] toDir:dir];
	}
}


- (NSDictionary *)jsonRepresentedDictionaryFromSavedStatistics
{
	NSMutableDictionary *rootDict = [NSMutableDictionary dictionary];
	
	[rootDict setObject:@((int)[_lastStatisticsSaveDate timeIntervalSince1970])
				 forKey:kSTNetworkDataSaveStatisticsLastSaveTimeStampKey];
	[rootDict setObject:@((int)[_lastStatisticsResetDate timeIntervalSince1970])
				 forKey:kSTNetworkDataSaveStatisticsLastResetTimeStampKey];
	
	NSMutableArray *servicesArray = [NSMutableArray array];
	
	NSArray *services = [_lastSavedStatistics allKeys];
	for (NSString *serviceName in services) {
		STNetworkDataValue *dataValue = [_lastSavedStatistics objectForKey:serviceName];
		
		NSDictionary *serviceDict = @{kSTNetworkDataSaveStatisticsServiceNameKey : serviceName,
									  kSTNetworkDataSaveStatisticsReceivedBytesKey : @(dataValue.received.bytes),
									  kSTNetworkDataSaveStatisticsReceivedBytesOverflowsKey : @(dataValue.received.numberOf64BitOverflows),
									  kSTNetworkDataSaveStatisticsSentBytesKey : @(dataValue.sent.bytes),
									  kSTNetworkDataSaveStatisticsSentBytesOverflowsKey : @(dataValue.sent.numberOf64BitOverflows)};
		
		
		[servicesArray addObject:serviceDict];
	}
	
	[rootDict setObject:servicesArray forKey:kSTNetworkDataSaveStatisticsServicesArrayKey];
	
	
	return [NSDictionary dictionaryWithDictionary:rootDict];
}


- (void)loadStatisticsFromJsonRepresentedDictionary:(NSDictionary *)dict
{
	[_lastSavedStatistics removeAllObjects];
	
	NSNumber *lastStatisticsSaveTimeStamp = [dict objectForKey:kSTNetworkDataSaveStatisticsLastSaveTimeStampKey];
	if (lastStatisticsSaveTimeStamp) {
		_lastStatisticsSaveDate = [NSDate dateWithTimeIntervalSince1970:[lastStatisticsSaveTimeStamp doubleValue]];
	}
	
	NSNumber *lastStatisticsResetTimeStamp = [dict objectForKey:kSTNetworkDataSaveStatisticsLastResetTimeStampKey];
	if (lastStatisticsResetTimeStamp) {
		_lastStatisticsResetDate = [NSDate dateWithTimeIntervalSince1970:[lastStatisticsResetTimeStamp doubleValue]];
	}
	
	NSArray *servicesArray = [dict objectForKey:kSTNetworkDataSaveStatisticsServicesArrayKey];
	
	for (NSDictionary *serviceDict in servicesArray) {
		STNetworkDataValue *dataValue = [STNetworkDataValue new];
		NSString *serviceName = [serviceDict objectForKey:kSTNetworkDataSaveStatisticsServiceNameKey];
		uint64_t bytesSent = [[serviceDict objectForKey:kSTNetworkDataSaveStatisticsSentBytesKey] unsignedLongLongValue];
		uint64_t bytesSentOverflows = [[serviceDict objectForKey:kSTNetworkDataSaveStatisticsSentBytesOverflowsKey] unsignedLongLongValue];
		uint64_t bytesReceived = [[serviceDict objectForKey:kSTNetworkDataSaveStatisticsReceivedBytesKey] unsignedLongLongValue];
		uint64_t bytesReceivedOverflows = [[serviceDict objectForKey:kSTNetworkDataSaveStatisticsReceivedBytesOverflowsKey] unsignedLongLongValue];

		STByteCount sent = STByteCountMakeZero();
		sent.bytes = bytesSent;
		sent.numberOf64BitOverflows = bytesSentOverflows;
		
		STByteCount received = STByteCountMakeZero();
		received.bytes = bytesReceived;
		received.numberOf64BitOverflows = bytesReceivedOverflows;
		
		dataValue.sent = sent;
		dataValue.received = received;
		
		[_lastSavedStatistics setObject:dataValue forKey:serviceName];
	}
}


- (NSDate *)lastStatisticsResetDate
{
	return [_lastStatisticsResetDate copy];
}


- (NSDate *)lastStatisticsSaveDate
{
	return [_lastStatisticsSaveDate copy];
}


#pragma mark - SHOULD BE OVERRIDDEN IN SUBCLASSES

+ (NSString *)savedStatisticsDir
{
	return nil;
}


- (void)saveStatistics:(NSDictionary *)jsonRepresentedDict toDir:(NSString *)dir
{}


- (NSDictionary *)loadJsonRepresentedStatisticsFromDir:(NSString *)dir
{
	return nil;
}


@end

#pragma mark -
#pragma mark - STNetworkDataValue -

@implementation STNetworkDataValue

- (instancetype)init
{
	self = [super init];
	if (self) {
		_sent = STByteCountMakeZero();
		_received = STByteCountMakeZero();
	}
	return self;
}


- (STByteCount)total
{
	return STAddByteCounts(_sent, _received);
}


@end
