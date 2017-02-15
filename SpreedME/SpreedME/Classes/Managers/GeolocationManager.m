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

#import "GeolocationManager.h"


@interface GeolocationManager() <CLLocationManagerDelegate>
{
    CLLocationManager *_locationManager;
    CLLocation *_lastLocation;
    NSTimer *_locationTimeOutTimer;
    
    NSMutableArray *_completionBlocks;
    
    BOOL _isWorking;
    
}
@end

@implementation GeolocationManager


+ (instancetype)defaultManager
{
	static dispatch_once_t once;
    static GeolocationManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (id)init
{
	self = [super init];
	if (self) {
        _completionBlocks = [[NSMutableArray alloc] init];
	}
	return self;
}


- (void)dealloc
{
    _locationManager = nil;
    _locationManager.delegate = nil;
}


- (void)getCurrentLocationWithCompletionBlock:(void(^)(CLLocation *location, NSError *error))completionBlock
{
    if (!_isWorking) {
        _isWorking = YES;
        
        [_completionBlocks addObject:[completionBlock copy]];
        
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        if (status == kCLAuthorizationStatusNotDetermined || status == kCLAuthorizationStatusAuthorized || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
            const NSTimeInterval kTimeOutAuthStatusNotDetermined = 300.0;
            const NSTimeInterval kTimeOutAuthStatusDetermined = 5.0;
            NSTimeInterval locationTimeOut = (status == kCLAuthorizationStatusNotDetermined) ? kTimeOutAuthStatusNotDetermined : kTimeOutAuthStatusDetermined;
            
            if (!_locationManager) {
                _locationManager = [[CLLocationManager alloc] init];
            }
            
            if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
                [_locationManager requestWhenInUseAuthorization];
            }
            
            _locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
            _locationManager.delegate = self;
            
            [_locationManager startUpdatingLocation];
            
            [_locationTimeOutTimer invalidate];
            _locationTimeOutTimer = [NSTimer scheduledTimerWithTimeInterval:locationTimeOut target:self selector:@selector(timerTicked:) userInfo:nil repeats:YES];
            
        } else if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
            
            NSError *locationError = [[NSError alloc] initWithDomain:kCLErrorDomain code:kCLErrorDenied userInfo:nil];
            if ([_completionBlocks count]) {
                for (GeolocationCompletionBlock block in _completionBlocks) {
                    block(nil, locationError);
                }
                [_completionBlocks removeAllObjects];
            }
            
            _isWorking = NO;
        }
        
    } else {
        [_completionBlocks addObject:[completionBlock copy]];
    }
}


#pragma mark Location Manager Interactions


- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    _lastLocation = [locations lastObject];
    [self stopUpdatingLocation:kGeolocationStopReasonCancelled];
    
    if ([_completionBlocks count]) {
        for (GeolocationCompletionBlock block in _completionBlocks) {
            block(_lastLocation, nil);
        }
        [_completionBlocks removeAllObjects];
    }
    _isWorking = NO;
    
    [_locationTimeOutTimer invalidate];
    _locationTimeOutTimer = nil;
    
    _locationManager.delegate = nil;
}


- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if ([_completionBlocks count]) {
        for (GeolocationCompletionBlock block in _completionBlocks) {
            block(nil, error);
        }
        [_completionBlocks removeAllObjects];
    }
    
     _isWorking = NO;
    
    [_locationTimeOutTimer invalidate];
    _locationTimeOutTimer = nil;
    
    _locationManager.delegate = nil;
    
    [self stopUpdatingLocation:kGeolocationStopReasonError];
}


- (void)stopUpdatingLocation:(GeolocationStopReason)reason {
    switch (reason) {
        case kGeolocationStopReasonCancelled:
        
        break;
        
        case kGeolocationStopReasonTimeOut:
            if ([_completionBlocks count]) {
                NSError *locationError = [[NSError alloc] initWithDomain:kCLErrorDomain code:kCLErrorLocationUnknown userInfo:nil];
                for (GeolocationCompletionBlock block in _completionBlocks) {
                    block(nil, locationError);
                }
                [_completionBlocks removeAllObjects];
            }
        break;
        
        case kGeolocationStopReasonError:
        
        break;
        
        default:
        break;
    }
    
     _isWorking = NO;
    
    [_locationManager stopUpdatingLocation];
    _locationManager.delegate = nil;
}


#pragma mark - Timer

- (void)timerTicked:(NSTimer*)timer
{
    [self stopUpdatingLocation:kGeolocationStopReasonTimeOut];
    [_locationTimeOutTimer invalidate];
    _locationTimeOutTimer = nil;
}

@end
