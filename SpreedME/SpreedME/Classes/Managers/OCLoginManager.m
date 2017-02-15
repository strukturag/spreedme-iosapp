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

#import "OCLoginManager.h"

#import "AFNetworking.h"
#import "SMConnectionController.h"
#import "SettingsController.h"
#import "SpreedSSLSecurityPolicy.h"


typedef void (^GetUserComboCompletionBlock)(NSDictionary *jsonResponse, NSError *error);


@interface OCLoginManager ()
{    
    AFHTTPRequestOperationManager *_httpRequestOpManager;
}

@end


@implementation OCLoginManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static OCLoginManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        _httpRequestOpManager = [[AFHTTPRequestOperationManager alloc] init];
        _httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
        _httpRequestOpManager.requestSerializer = [[AFHTTPRequestSerializer alloc] init];
        _httpRequestOpManager.securityPolicy = [SpreedSSLSecurityPolicy defaultPolicy];
    }
    return self;
}


- (LoginManagerOperation *)getUserComboUsername:(NSString *)userName
                                       password:(NSString *)password
                                 serverEndpoint:(NSString *)serverRESTAPIEndpoint
                                completionBlock:(GetAuthCookieDataCompletionBlock)block
{
    if (_httpRequestOpManager) {
        NSString *server = serverRESTAPIEndpoint;
        
        _httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
        
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *each in cookieStorage.cookies) {
            [cookieStorage deleteCookie:each];
        }
                
        [_httpRequestOpManager.requestSerializer setAuthorizationHeaderFieldWithUsername:userName password:password];
        
        server = [server stringByAppendingFormat:@"/user/token"];
        
        GetUserComboCompletionBlock copiedBlock = [block copy];
        
        AFHTTPRequestOperation *operation = [_httpRequestOpManager GET:server
                                                             parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                                 NSDictionary *responseDict = nil;
                                                                 
                                                                 if ([operation.responseObject isKindOfClass:[NSDictionary class]]) {
                                                                     responseDict = operation.responseObject;
                                                                 } else {
                                                                     responseDict = @{@"error" : operation.responseObject};
                                                                 }
                                                                 
                                                                 if (copiedBlock) {
                                                                     copiedBlock(responseDict, nil);
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


- (LoginManagerOperation *)getUserConfigUsername:(NSString *)userName
                                        password:(NSString *)password
                                  serverEndpoint:(NSString *)serverRESTAPIEndpoint
                                 completionBlock:(GetAuthCookieDataCompletionBlock)block
{
    if (_httpRequestOpManager) {
        NSString *server = serverRESTAPIEndpoint;
        
        _httpRequestOpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
        
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *each in cookieStorage.cookies) {
            [cookieStorage deleteCookie:each];
        }
        
        [_httpRequestOpManager.requestSerializer setAuthorizationHeaderFieldWithUsername:userName password:password];
        
        server = [server stringByAppendingFormat:@"/user/config"];
        
        GetUserComboCompletionBlock copiedBlock = [block copy];
        
        AFHTTPRequestOperation *operation = [_httpRequestOpManager GET:server
                                                            parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
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


- (LoginManagerOperation *)getAccessToken:(NSString *)userName
                                 password:(NSString *)password
                           serverEndpoint:(NSString *)serverEndpoint
                          completionBlock:(GetAccessTokenCompletionBlock)block
{
    if (_httpRequestOpManager) {
        
        _httpRequestOpManager.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
        
        NSString *server = serverEndpoint;
        
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *each in cookieStorage.cookies) {
            [cookieStorage deleteCookie:each];
        }
        
        [_httpRequestOpManager.requestSerializer setAuthorizationHeaderFieldWithUsername:userName password:password];
        
        server = [server stringByAppendingFormat:@"/user/token"];
        
        NSDictionary *services = [[SettingsController sharedInstance] servicesConfig];
        NSString *authEndpoint = nil;
        NSString *nonce = [self generateNonceForAccessToken];
        NSString *state = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        
        if (services) {
            authEndpoint = [services objectForKey:kServiceConfigAuthorizationEndpointKey];
            NSString *openIDtail = [NSString stringWithFormat:@"?response_type=token&redirect_url=http://localhost&nonce=%@&state=%@&prompt=none&scope=openid", nonce, state];
            server = [authEndpoint stringByAppendingString:openIDtail];
        }
        
        GetAccessTokenCompletionBlock copiedBlock = [block copy];
        
        AFHTTPRequestOperation *operation = [_httpRequestOpManager GET:server
                                                            parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                                if (copiedBlock) {
                                                                    copiedBlock(nil, 0, nil);
                                                                }
                                                            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                if (copiedBlock) {
                                                                    copiedBlock(nil, 0, error);
                                                                }
                                                            }];
        
        LoginManagerOperation *loginOperation = [[LoginManagerOperation alloc] init];
        loginOperation.requestOperation = operation;
        
        [operation setRedirectResponseBlock:^NSURLRequest *(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *redirectResponse) {
            if (redirectResponse == nil) {
                return request;
            } else {
                NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)redirectResponse;
                NSError *error = [NSError errorWithDomain:@"Application domain" code:1 userInfo:@{@"error" : @"Could not get access token from server."}];
                if ([httpResponse respondsToSelector:@selector(allHeaderFields)]) {
                    NSDictionary *headers = [httpResponse allHeaderFields];
                    NSString *location = [headers objectForKey:@"Location"];
                    
                    NSArray *locationComponents = [[NSArray alloc] initWithArray:[location componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"#&"]]];
                    
                    if ([locationComponents count] > 2) {
                        NSString *accessTokenPrefix = @"access_token=";
                        NSString *accessToken = [locationComponents objectAtIndex:1];
                        if ([accessToken hasPrefix:accessTokenPrefix]) {
                            accessToken = [accessToken substringFromIndex:[accessTokenPrefix length]];
                        } else {
                            accessToken = nil;
                        }
                        
                        NSString *expiresInPrefix = @"expires_in=";
                        NSString *expiresIn = [locationComponents objectAtIndex:2];
                        if ([expiresIn hasPrefix:expiresInPrefix]) {
                            expiresIn = [expiresIn substringFromIndex:[expiresInPrefix length]];
                        } else {
                            expiresIn = nil;
                        }
                        NSInteger tokenExpiresIn = [expiresIn integerValue];
                        
                        if ([accessToken length] > 0 && [expiresIn length] > 0) {
                            NSArray *segments = [accessToken componentsSeparatedByString:@"."];
                            NSString *base64String = [segments objectAtIndex: 1];
                            
                            int requiredLength = (int)(4 * ceil((float)[base64String length] / 4.0));
                            int nbrPaddings = requiredLength - [base64String length];
                            
                            if (nbrPaddings > 0) {
                                NSString *padding =
                                [[NSString string] stringByPaddingToLength:nbrPaddings
                                                                withString:@"=" startingAtIndex:0];
                                base64String = [base64String stringByAppendingString:padding];
                            }
                            
                            base64String = [base64String stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
                            base64String = [base64String stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
                            
                            NSData *decodedData = nil;
                            
                            if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7.0) {
                                decodedData = [[NSData alloc] initWithBase64Encoding:base64String];
                            } else {
                                decodedData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
                            }
                            
                            NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
                            
                            NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:[decodedString
                                                                                                    dataUsingEncoding:NSUTF8StringEncoding]
                                                                                           options:0 error:nil];
                            
                            NSString *receivedNonce = [jsonDictionary objectForKey:@"nonce"];
                            BOOL sameNonce = [receivedNonce isEqualToString:nonce];
                            
                            if (copiedBlock && sameNonce) {
                                copiedBlock(accessToken, tokenExpiresIn, nil);
                            }
                        } else {
                            if (copiedBlock) {
                                copiedBlock(nil, 0, error);
                            }
                        }
                    } else {
                        if (copiedBlock) {
                            copiedBlock(nil, 0, error);
                        }
                    }
                }
                if (copiedBlock) {
                    copiedBlock(nil, 0, error);
                }
                return nil;
            }
        }];
        
        return loginOperation;
        
    } else {
        spreed_me_log("Error: no _httpRequestOpManager!");
    }
    return nil;
}


- (NSString *)generateNonceForAccessToken
{
    NSString *udid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *timestamp = [NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]];
    
    NSString *nonce = [udid stringByAppendingString:timestamp];
    return nonce;
}


@end
