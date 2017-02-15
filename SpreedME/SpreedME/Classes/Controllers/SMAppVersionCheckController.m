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

#import "SMAppVersionCheckController.h"


#import "JSONKit.h"
#import "SettingsController.h"
#import "SMLocalizedStrings.h"
#import "SpreedMeStrictSSLSecurityPolicy.h"


NSString * const kSMAppVersionCheckResponseNewestAvailableKey   = @"current";
NSString * const kSMAppVersionCheckResponseMinimalKey           = @"minimal";

NSString * const kSMAppVersionCheckControllerDefaultAppStoreLink = @"http://appstore.com/strukturag";

const NSTimeInterval kSMMinimalPeriodicVersionCheckInterval = 30.0;
const NSTimeInterval kSMDefaultPeriodicVersionCheckInterval = 60.0 * 60.0;


typedef enum : NSUInteger {
    kSMAVCNTProposeUserToUpdate = 8267,
    kSMAVCNTNotifyUserAboutOldVersion = 8268,
    kSMAVCNTNotifyUserAboutSuspiciousVersion = 8269,
} SMApplicationVersionCheckNotificationTags;


#pragma mark -
#pragma mark - SMAppVersionCheckNetOperation Class
@interface SMAppVersionCheckNetOperation : NSObject <STNetworkOperation>
@property (nonatomic, strong) AFURLConnectionOperation *afOperation;
- (void)cancel;
@end

@implementation SMAppVersionCheckNetOperation
- (void)cancel { [self.afOperation cancel]; }
@end


#pragma mark -
#pragma mark - Helper functoins

NSArray * SMStringVersionNumberToIntArray(NSString *version)
{
    if (version.length == 0) {
        return nil;
    }
    
    NSArray *components = [version componentsSeparatedByString:@"."];
    NSMutableArray *curb = [NSMutableArray array];
    [components enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [curb addObject:@([obj integerValue])];
    }];
    
    return [NSArray arrayWithArray:curb];
}


NSComparisonResult SMCompareVersionArrays(NSArray *ver1, NSArray *ver2)
{
    NSComparisonResult comparisonResult = NSOrderedSame;
    
    NSUInteger leastCount = ([ver1 count] > [ver2 count]) ? [ver2 count] : [ver1 count];
    
    for (NSUInteger i = 0; i < leastCount; i++) {
        NSInteger ver1El = [[ver1 objectAtIndex:i] integerValue];
        NSInteger ver2El = [[ver2 objectAtIndex:i] integerValue];
        
        if (ver1El > ver2El) {
            comparisonResult = NSOrderedDescending;
            break;
        } else if (ver2El > ver1El) {
            comparisonResult = NSOrderedAscending;
            break;
        }
    }
    
    return comparisonResult;
}


#pragma mark -
#pragma mark - SMAppVersionCheckController

@interface SMAppVersionCheckController ()
{
    NSString *_endpoint;
    AFSecurityPolicy *_securityPolicy;
    NSTimeInterval _versionCheckInterval;
    
    SMReceivedAppVersionsBlock _periodicCheckComplBlock;
    
    NSTimer *_timer;
    SMAppVersionCheckNetOperation *_lastPeriodicRequest;
}
@end


@implementation SMAppVersionCheckController


- (instancetype)init
{
    self = [super init];
    self = nil;
    return self;
}


- (instancetype)initWithEndpoint:(NSString *)endpoint
                  securityPolicy:(AFSecurityPolicy *)policy
{
    self = [super init];
    if (self) {
        
        if (endpoint.length == 0) {
            return nil;
        }
        
        _endpoint = [endpoint copy];
        _securityPolicy = policy;
        
        _periodicCheckComplBlock = nil;
        
        _versionCheckInterval = kSMDefaultPeriodicVersionCheckInterval;
    }
    
    return self;
}


- (id<STNetworkOperation>)getApplicationVersionInformationWithCompletionBlock:(void (^)(NSDictionary *versionDict, NSError *error))block
{
    AFHTTPRequestOperationManager *httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
    httpRequestOpManager.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
    httpRequestOpManager.requestSerializer = [[AFHTTPRequestSerializer alloc] init];
    httpRequestOpManager.securityPolicy = _securityPolicy;
    
    void (^complBlock)(NSDictionary *versionDict, NSError *error) = NULL;
    
    if (block) {
        complBlock = [block copy];
    }
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
    
    // We add an empty dictionary as parameter in order to make AFHTTPRequestSerializer set application/x-www-form-urlencoded as content type.
    AFHTTPRequestOperation *op = [httpRequestOpManager GET:_endpoint parameters:@{} success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString *response = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        NSDictionary *responseDict = [response objectFromJSONString];
        if ([responseDict isKindOfClass:[NSDictionary class]]) {
            if (complBlock) {
                complBlock(responseDict, nil);
            }
        } else {
            spreed_me_log("Wrong version check response");
            if (complBlock) {
                complBlock(nil, [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Wrong version check response"}]);
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        spreed_me_log("Couldn't receive application versions");
        if (complBlock) {
            complBlock(nil, error);
        }
    }];
    
    SMAppVersionCheckNetOperation *wrapperOperation = [SMAppVersionCheckNetOperation new];
    wrapperOperation.afOperation = op;
    
    return wrapperOperation;
}


- (id<STNetworkOperation>)getApplicationInformationVersionWithComplBlock:(SMReceivedAppVersionsBlock)block
{
    SMReceivedAppVersionsBlock complBlock = NULL;
    if (block) {
        complBlock = [block copy];
        
        return [self getApplicationVersionInformationWithCompletionBlock:^(NSDictionary *versionDict, NSError *error) {
            NSString *minimalVersion = nil;
            NSString *newestAvailVersion = nil;
            
            if (!error && [versionDict isKindOfClass:[NSDictionary class]]) {
                minimalVersion = [versionDict objectForKey:kSMAppVersionCheckResponseMinimalKey];
                newestAvailVersion = [versionDict objectForKey:kSMAppVersionCheckResponseNewestAvailableKey];
            }
            
            if (complBlock) {
                complBlock(minimalVersion, newestAvailVersion);
            }
        }];
    }
    return nil;
}


- (void)getApplicatioVersionPeriodic
{
    SMReceivedAppVersionsBlock complBlock = NULL;
    if (_periodicCheckComplBlock) {
        complBlock = [_periodicCheckComplBlock copy];
    }
    
    _lastPeriodicRequest = [self getApplicationInformationVersionWithComplBlock:^(NSString *minimalVersion, NSString *newestAvailVersion) {
        
        _lastPeriodicRequest = nil;
        if (complBlock) {
            complBlock(minimalVersion, newestAvailVersion);
        }
    }];
    
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:_versionCheckInterval
                                              target:self
                                            selector:@selector(getApplicatioVersionPeriodic)
                                            userInfo:nil
                                             repeats:NO];
}


- (void)startPeriodicChecksWithInterval:(NSTimeInterval)interval andCompletionBlock:(SMReceivedAppVersionsBlock)block
{
    if (block) {
        [self stopPeriodicChecks];
        
        [self setPeriodicChecksComplBlock:block];
        [self setVersionCheckInterval:interval];
        [self getApplicatioVersionPeriodic];
    }
}


- (void)stopPeriodicChecks
{
    [_timer invalidate];
    _timer = nil;
    [_lastPeriodicRequest cancel];
    _lastPeriodicRequest = nil;
}


- (void)setVersionCheckInterval:(NSTimeInterval)interval
{
    _versionCheckInterval = interval < kSMMinimalPeriodicVersionCheckInterval ?
        kSMMinimalPeriodicVersionCheckInterval : interval;
}


- (void)setPeriodicChecksComplBlock:(SMReceivedAppVersionsBlock)block
{
    _periodicCheckComplBlock = [block copy];
}



#pragma mark - Public notification methods

- (void)notifyUserAboutAvailableUpdateToVersion:(NSString *)version
{
    if (![SettingsController sharedInstance].shouldNotNotifyAboutNewApplicationVersion) {
    
        NSString *title = NSLocalizedStringWithDefaultValue(@"message_title_application-update-available",
                                                            nil, [NSBundle mainBundle],
                                                            @"App update available",
                                                            @"App update available");
        NSString *message = nil;
        
        NSString *goToAppstoreButtonTitle = kSMLocalStringGoToAppstoreButton;
        
        NSString *doNotAskAgainButtonTitle = kSMLocalStringDoNotShowThisAgainButton;
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:kSMLocalStringOKButton
                                                  otherButtonTitles:goToAppstoreButtonTitle, doNotAskAgainButtonTitle, nil];
        alertView.tag = kSMAVCNTProposeUserToUpdate;
        
        [alertView show];
    }
}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    NSString *iTunesLink = kSMAppVersionCheckControllerDefaultAppStoreLink;
    if (self.appStoreLinkToApp.length > 0) {
        iTunesLink = self.appStoreLinkToApp;
    }
    
    switch (alertView.tag) {
        case kSMAVCNTProposeUserToUpdate:
        {
            if (buttonIndex == alertView.firstOtherButtonIndex) {
                // go to appstore
                
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:iTunesLink]];
                
            } else if (buttonIndex == alertView.firstOtherButtonIndex + 1) {
                // Do not ask again
                [SettingsController sharedInstance].shouldNotNotifyAboutNewApplicationVersion = YES;
            }
        }
        break;
            
        case kSMAVCNTNotifyUserAboutOldVersion:
        {
            if (buttonIndex == alertView.firstOtherButtonIndex) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:iTunesLink]];
            }
        }
        break;
            
        case kSMAVCNTNotifyUserAboutSuspiciousVersion:
        {
            
        }
        break;
            
        default:
            break;
    }
}


@end
