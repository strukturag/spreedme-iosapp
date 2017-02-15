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

#import "LoginManager.h"

#import "AES256Encryptor.h"
#import "AFNetworking.h"
#import "JSONKit.h"
#import "SettingsController.h"
#import "SMConnectionController.h"
#import "SpreedMeStrictSSLSecurityPolicy.h"
#import "SpreedSSLSecurityPolicy.h"


@interface LoginManagerOperation ()

@end

@implementation LoginManagerOperation
- (void)cancel
{
	[self.requestOperation cancel];
}

@end


@interface LoginManager ()
{
	AFHTTPRequestOperationManager *_httpRequestOpManager;
}

@property (nonatomic, strong) User *loggedInUser;

@end


@implementation LoginManager


#pragma mark - Class methods

+ (LoginManager *)sharedInstance
{
	static dispatch_once_t once;
    static LoginManager *sharedInstance;
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
		_httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
		_httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
		_httpRequestOpManager.requestSerializer = [[AFJSONRequestSerializer alloc] init];
	}
	
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Public methods

- (LoginManagerOperation *)getNonceWithSessionId:(NSString *)sessionId
								 secureSessionId:(NSString *)secureSessionId
									 userIdCombo:(NSString *)userIdCombo
										  secret:(NSString *)secret
								 completionBlock:(GetNonceCompletionBlock)block
{
	if (_httpRequestOpManager) {
        
        _httpRequestOpManager.securityPolicy = [SettingsController sharedInstance].spreedMeMode ? [SpreedMeStrictSSLSecurityPolicy defaultPolicy] : [SpreedSSLSecurityPolicy defaultPolicy];
		
		NSDictionary *json = @{@"id" : sessionId,
						   @"sid" : secureSessionId,
						   @"useridcombo" : userIdCombo,
						   @"secret": secret};
		
		NSString *server = [[SMConnectionController sharedInstance].currentRESTAPIEndpoint copy];
		server = [server stringByAppendingFormat:@"/sessions/%@/", sessionId];
		
		GetNonceCompletionBlock copiedBlock = [block copy];
		
		AFHTTPRequestOperation *operation = [_httpRequestOpManager PATCH:server parameters:json success:^(AFHTTPRequestOperation *operation, id responseObject) {
			if (copiedBlock) {
				copiedBlock(operation.responseObject, nil);
			}
		} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			NSDictionary *responseDict = nil;
			
			if ([operation.responseObject isKindOfClass:[NSDictionary class]]) {
				responseDict = operation.responseObject;
			} else if ([operation.responseObject isKindOfClass:[NSString class]]) {
				responseDict = @{@"error" : operation.responseObject};
			}
			
			if (copiedBlock) {
				copiedBlock(responseDict, error);
			}
		}];
		
		LoginManagerOperation *loginOperation = [[LoginManagerOperation alloc] init];
		loginOperation.requestOperation = operation;
		
		return loginOperation;
		
	} else {
		spreed_me_log("Error: no _httpRequestOpManager!");
	}
	return nil;
}


@end
