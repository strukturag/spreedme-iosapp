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

#import "ReachabilityManager.h"

#import <SystemConfiguration/SystemConfiguration.h>

NSString * const ReachabilityHasChangedNotification				= @"ReachabilityHasChangedNotification";
NSString * const ReachabilityNotificationHostNameKey			= @"ReachabilityNotificationHostNameKey";
NSString * const ReachabilityNotificationNetworkStatusKey		= @"ReachabilityNotificationNetworkStatusKey";



@interface ReachabilityContainer : NSObject
{
@public
	SCNetworkReachabilityRef reachabilityRef;
}
@property (nonatomic, copy) NSString *hostName;
@end
@implementation ReachabilityContainer
- (void)dealloc
{
	if (reachabilityRef != NULL)
    {
		Boolean success = SCNetworkReachabilitySetDispatchQueue(reachabilityRef, NULL);
		spreed_me_log("Reachability stopped %s", success ? [@"YES" cDescription] : [@"NO" cDescription]);
		
        CFRelease(reachabilityRef);
    }
}
@end


@implementation ReachabilityManager
{
	NSMutableDictionary *_reachabilities;
	NSMutableDictionary *_networkStatusDic;
}

#pragma mark - Supporting functions

#define kShouldPrintReachabilityFlags 1

static void PrintReachabilityFlags(SCNetworkReachabilityFlags flags, const char* comment)
{
#if kShouldPrintReachabilityFlags
	
    spreed_me_log("Reachability Flag Status: %c%c %c%c%c%c%c%c%c %s\n",
          (flags & kSCNetworkReachabilityFlagsIsWWAN)               ? 'W' : '-',
          (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
		  
          (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
          (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
          (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
          (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-',
          comment
          );
#endif
}


static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
#pragma unused (target, flags)
    NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
    NSCAssert([(__bridge NSObject*) info isKindOfClass: [ReachabilityContainer class]], @"info was wrong class in ReachabilityCallback");
	
    ReachabilityContainer* noteObject = (__bridge ReachabilityContainer *)info;
	dispatch_async(dispatch_get_main_queue(), ^{
		[[ReachabilityManager sharedInstance] reachabilityHasChanged:noteObject withNewFlags:flags];
	});

}


#pragma mark - Reachability implementation

+ (ReachabilityManager *)sharedInstance
{
	static dispatch_once_t once;
    static ReachabilityManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (id)init
{
	self = [super init];
	if (self) {
		_reachabilities = [[NSMutableDictionary alloc] init];
		_networkStatusDic = [[NSMutableDictionary alloc] init];
	}
	return self;
}


- (void)reachabilityHasChanged:(ReachabilityContainer *)container withNewFlags:(SCNetworkReachabilityFlags)flags
{
	NetworkStatus status = [self networkStatusForFlags:flags];
	NetworkStatus lastStatus = [[_networkStatusDic objectForKey:container.hostName] integerValue];
	
	spreed_me_log("Reachability has changed. Was %d; now %d;", lastStatus, status);
	
	[_networkStatusDic setObject:@(status) forKey:container.hostName];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ReachabilityHasChangedNotification
														object:self
													  userInfo:@{ReachabilityNotificationNetworkStatusKey : @(status), ReachabilityNotificationHostNameKey : container.hostName}];
}


- (BOOL)addReachabilityWithHostName:(NSString *)hostName
{
	if (![_reachabilities objectForKey:hostName]) {
		SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
		if (reachability != NULL)
		{
			ReachabilityContainer *container = [[ReachabilityContainer alloc] init];
			container->reachabilityRef = reachability;
			container.hostName = hostName;
			
			SCNetworkReachabilityContext context = {0, (__bridge void *)(container), NULL, NULL, NULL};
			
			if (SCNetworkReachabilitySetCallback(reachability, ReachabilityCallback, &context))
			{
				Boolean success = SCNetworkReachabilitySetDispatchQueue(reachability, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
				
				if (success) {
					[_reachabilities setObject:container forKey:hostName];
					[_networkStatusDic setObject:@(ReachableViaWWAN) forKey:hostName];
					return YES;
				}
			}
		}
	} else {
		return YES;
	}
	
    return NO;
}


- (void)removeReachabilityWithHostName:(NSString *)hostName
{
	if (hostName) {
		[_reachabilities removeObjectForKey:hostName];
		[_networkStatusDic removeObjectForKey:hostName];
	}
}


- (NetworkStatus)lastNetworkStatusForHostName:(NSString *)hostName
{
	NetworkStatus status = NotReachable;
	
	NSNumber *statusInNumber = [_networkStatusDic objectForKey:hostName];
	if (statusInNumber) {
		status = [statusInNumber integerValue];
	}
	
	return status;
}


#pragma mark - Network Flag Handling

- (NetworkStatus)localWiFiStatusForFlags:(SCNetworkReachabilityFlags)flags
{
    PrintReachabilityFlags(flags, "localWiFiStatusForFlags");
    BOOL returnValue = NotReachable;
	
    if ((flags & kSCNetworkReachabilityFlagsReachable) && (flags & kSCNetworkReachabilityFlagsIsDirect))
    {
        returnValue = ReachableViaWiFi;
    }
    
    return returnValue;
}


- (NetworkStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
    PrintReachabilityFlags(flags, "networkStatusForFlags");
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
    {
        // The target host is not reachable.
        return NotReachable;
    }
	
    BOOL returnValue = NotReachable;
	
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
    {
        /*
         If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
         */
        returnValue = ReachableViaWiFi;
    }
	
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
		 (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
    {
        /*
         ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
         */
		
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
        {
            /*
             ... and no [user] intervention is needed...
             */
            returnValue = ReachableViaWiFi;
        }
    }
	
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
    {
        /*
         ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
         */
        returnValue = ReachableViaWWAN;
    }
    
    return returnValue;
}


//- (BOOL)connectionRequired
//{
//    NSAssert(reachabilityRef != NULL, @"connectionRequired called with NULL reachabilityRef");
//    SCNetworkReachabilityFlags flags;
//	
//    if (SCNetworkReachabilityGetFlags(reachabilityRef, &flags))
//    {
//        return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
//    }
//	
//    return NO;
//}


//- (NetworkStatus)currentReachabilityStatus
//{
//    NSAssert(reachabilityRef != NULL, @"currentNetworkStatus called with NULL reachabilityRef");
//    NetworkStatus returnValue = NotReachable;
//    SCNetworkReachabilityFlags flags;
//    
//    if (SCNetworkReachabilityGetFlags(reachabilityRef, &flags))
//    {
//        if (localWiFiRef)
//        {
//            returnValue = [self localWiFiStatusForFlags:flags];
//        }
//        else
//        {
//            returnValue = [self networkStatusForFlags:flags];
//        }
//    }
//    
//    return returnValue;
//}



@end
