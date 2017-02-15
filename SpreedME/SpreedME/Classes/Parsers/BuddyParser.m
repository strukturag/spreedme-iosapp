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

#import "BuddyParser.h"

#import <QuartzCore/QuartzCore.h>

#import "ChannelingConstants.h"
#import "ResourceDownloadManager.h"
#import "SMConnectionController.h"
#import "UIImage+RoundedCorners.h"
#import "UsersManager.h"


NSString * const BuddyImageHasBeenUpdatedNotification		= @"BuddyImageHasBeenUpdatedNotification";

NSString * const UserSessionIdUserInfoKey					= @"UserSessionIdUserInfoKey";
NSString * const BuddyImageUserInfoKey						= @"BuddyImageUserInfoKey";
NSString * const SMUserImageRevisionUserInfoKey				= @"SMUserImageRevisionUserInfoKey";


NSString * const base64APIImageHeader = @"data:image/jpeg;base64,";


@interface SMUserParserHelper : NSObject <UserUpdatesProtocol>
{
    uint32_t _numberForUnknownUser;
    NSMutableDictionary *_sessionsWithoutDisplayNames;
    
    dispatch_queue_t _workerQueue;
	
	NSString *_unknownUserNameString;
}

+ (instancetype)sharedInstance;

- (NSString *)generateUserDisplayNameForSessionId:(NSString *)sessionId;


@end


@implementation SMUserParserHelper


+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static SMUserParserHelper *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        _workerQueue = dispatch_queue_create("SMUserParserHelper", DISPATCH_QUEUE_SERIAL);
		_unknownUserNameString = NSLocalizedStringWithDefaultValue(@"user_base-for-generated-display-user-name",
																   nil, [NSBundle mainBundle],
																   @"Anonymous",
																   @"Base for generating display user name when user has not setup his name. Generated name look like Anonymus 1 or Anonymus 134");
        _sessionsWithoutDisplayNames = [[NSMutableDictionary alloc] init];
        _numberForUnknownUser = 0;
        
        [[UsersManager defaultManager] subscribeForUpdates:self];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasChangedAppModeOrResetApp:) name:ConnectionControllerHasProcessedChangeOfApplicationModeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasChangedAppModeOrResetApp:) name:ConnectionControllerHasProcessedResetOfApplicationNotification object:nil];
        
    }
    return self;
}


- (void)dealloc
{
    [[UsersManager defaultManager] unsubscribeForUpdates:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Notifications

- (void)userSessionHasLeft:(User *)user disconnectedFromServer:(BOOL)yesNo
{
    NSString *sessionId = user.sessionId;
    dispatch_async(_workerQueue, ^{
        [_sessionsWithoutDisplayNames removeObjectForKey:sessionId];
    });
}


- (void)userHasChangedAppModeOrResetApp:(NSNotification *)notification
{
     dispatch_async(_workerQueue, ^{
         [_sessionsWithoutDisplayNames removeAllObjects];
         _numberForUnknownUser = 0;
     });
}

#pragma mark - DisplayName generation

- (NSString *)generateUserDisplayNameForSessionId:(NSString *)sessionId
{
    uint32_t __block number = 0;
    
    dispatch_sync(_workerQueue, ^{
        if (sessionId && ![sessionId isEqualToString:[UsersManager defaultManager].currentUser.sessionId]) {
            number = [[_sessionsWithoutDisplayNames objectForKey:sessionId] unsignedIntegerValue];
            
            if (number == 0) {
                
                if (_numberForUnknownUser == 0) {
                    _numberForUnknownUser = 1;
                } else {
                    if (_numberForUnknownUser + 1 == UINT32_MAX) {
                        _numberForUnknownUser = 1;
                    } else {
                        _numberForUnknownUser += 1;
                    }
                }
                number = _numberForUnknownUser;
                [_sessionsWithoutDisplayNames setObject:@(number) forKey:sessionId];
            }
        }
    });
    
    return [NSString stringWithFormat:@"%@ %d", _unknownUserNameString, number];
}

@end



#pragma mark - BuddyParser -

@implementation BuddyParser


- (User *)createBuddyFromDictionary:(NSDictionary*)buddyDic withType:(BuddyDictionaryType)type
{
    User *newBuddy = nil;
    
	switch (type) {
		case kBuddyDictionaryTypeUsers:
		{
			newBuddy = [self createBuddyFromUsersDictionary:buddyDic];
			NSDictionary *statusDic = [[buddyDic objectForKey:NSStr(kStatusKey)] isKindOfClass:[NSDictionary class]] ? [buddyDic objectForKey:NSStr(kStatusKey)] : nil;
			uint64_t statusRev = [[buddyDic objectForKey:NSStr(kRevKey)] unsignedLongLongValue];
			[self updateBuddy:newBuddy withDictionary:statusDic withType:type userId:newBuddy.userId statusRevision:statusRev];
		}
		break;
			
		case kBuddyDictionaryTypeJoined:
		{
			newBuddy = [self createBuddyFromJoinedDictionary:buddyDic];
			NSDictionary *statusDic = [[buddyDic objectForKey:NSStr(kStatusKey)] isKindOfClass:[NSDictionary class]] ? [buddyDic objectForKey:NSStr(kStatusKey)] : nil;
			uint64_t statusRev = [[buddyDic objectForKey:NSStr(kRevKey)] unsignedLongLongValue];
			if (statusDic) {
				[self updateBuddy:newBuddy withDictionary:statusDic withType:kBuddyDictionaryTypeStatus userId:newBuddy.userId statusRevision:statusRev];
			}
		}
		break;
			
		default:
			spreed_me_log("Unknown BuddyDictionaryType!");
			break;
	}
    
    return newBuddy;
}


- (User *)createBuddyFromUsersDictionary:(NSDictionary *)buddyDic
{
	User *newBuddy = nil;
	if (buddyDic) {
		newBuddy = [[User alloc] init];
		newBuddy.sessionId = [[buddyDic objectForKey:NSStr(kIdKey)] isKindOfClass:[NSString class]] ? [buddyDic objectForKey:NSStr(kIdKey)] : [[buddyDic objectForKey:NSStr(kIdKey)] stringValue];
		newBuddy.userId = [[buddyDic objectForKey:NSStr(kUserIdKey)] isKindOfClass:[NSString class]] ? [buddyDic objectForKey:NSStr(kUserIdKey)] : [[buddyDic objectForKey:NSStr(kUserIdKey)] stringValue];
		newBuddy.Ua = [[buddyDic objectForKey:NSStr(kUserAgentKey)] isKindOfClass:[NSString class]] ? [buddyDic objectForKey:NSStr(kUserAgentKey)] : [[buddyDic objectForKey:NSStr(kUserAgentKey)] stringValue];
	}
	return newBuddy;
}


- (User *)createBuddyFromJoinedDictionary:(NSDictionary *)buddyDic
{
	User *newBuddy = nil;
	if (buddyDic) {
		/*	As of now users dictionary and joined dictionary have the same structure in terms of ID and Ua fields.
			In future this might change so you might need to rewrite this method*/
		newBuddy = [self createBuddyFromUsersDictionary:buddyDic];
	}
	
	return newBuddy;
}



- (NSArray *)createBuddyListFromUsersArray:(NSArray *)buddyArray
{
    NSMutableArray *newBuddyArray = [[NSMutableArray alloc] init];
        
    for (NSDictionary *buddyDic in buddyArray) {
        User *newBuddy = [self createBuddyFromDictionary:buddyDic withType:kBuddyDictionaryTypeUsers];
        [newBuddyArray addObject:newBuddy];
    }
    return [NSArray arrayWithArray:newBuddyArray];
}


- (NSString *)constructImageDownloadUrlWithServerURL:(NSURL *)serverURL imageString:(NSString *)imageString
{
	//TODO: optimize, there is no need to calculate server URL all the time
	
	NSString *server = [serverURL host];
	NSString *scheme = [serverURL scheme];
	int serverPort = 0;
	if ([scheme isEqualToString:@"wss"] || [scheme isEqualToString:@"https"]) {
		serverPort = [[serverURL port] intValue] != 0 ? [[serverURL port] intValue] : 443;
		scheme = @"https";
	} else if ([scheme isEqualToString:@"ws"] || [scheme isEqualToString:@"http"]) {
		serverPort = [[serverURL port] intValue] != 0 ? [[serverURL port] intValue] : 80;
		scheme = @"http";
	}
	server = [server stringByAppendingFormat:@":%d", serverPort];
	NSString *path = [[serverURL path] stringByDeletingLastPathComponent];
	server = [server stringByAppendingFormat:@"%@", [path isEqualToString:@"/"] ? @"" : path];
	NSString *pictureURL = [NSString stringWithFormat:@"%@://%@%@%@", scheme, server, @"/static/img/buddy/s46/", [imageString substringFromIndex:4]];
	
	return pictureURL;
}


- (void)updateBuddy:(User *)buddy
	 withDictionary:(NSDictionary *)dictionary
		   withType:(BuddyDictionaryType)type
			 userId:(NSString *)userId
	 statusRevision:(uint64_t)statusRev
{
	if (buddy && dictionary) {
		switch (type) {
			case kBuddyDictionaryTypeStatus:
			case kBuddyDictionaryTypeUsers:
			{
				buddy.userId = userId;
				
				NSString *buddyPicture = [[dictionary objectForKey:NSStr(kLCBuddyPictureKey)] isKindOfClass:[NSString class]] ? [dictionary objectForKey:NSStr(kLCBuddyPictureKey)] : nil;
				NSString *buddyDisplayName = [dictionary objectForKey:NSStr(kLCDisplayNameKey)];
				NSNumber *isBuddyMixer = [dictionary objectForKey:NSStr(kLCIsMixerKey)];
				NSString *statusMessage = [dictionary objectForKey:NSStr(kLCMessageKey)];
				
				if (buddy.statusRevision > statusRev) {
					spreed_me_log("User status dictionary revision is older than users status revision. Do not update!");
					return;
				}
				
				buddy.statusRevision = statusRev;
				
				if ([statusMessage isKindOfClass:[NSString class]]) {
					buddy.statusMessage = statusMessage;
				} else {
					buddy.statusMessage = nil;
				}
				
				if (isBuddyMixer && [isBuddyMixer isKindOfClass:[NSNumber class]]) {
					buddy.isMixer = [isBuddyMixer intValue] > 0 ? YES : NO;
				}
				
				if ([buddyDisplayName isKindOfClass:[NSString class]]) {
					if  ([buddyDisplayName length]) {
						buddy.displayName = buddyDisplayName;
					} else {
						buddy.displayName = [[self class] defaultUserDisplayNameForSessionId:buddy.sessionId];
					}
				} else {
					buddy.displayName = [[self class] defaultUserDisplayNameForSessionId:buddy.sessionId];
				}

				
				if (![buddy.base64Image isEqualToString:buddyPicture] && [buddyPicture rangeOfString:@"data:"].location == 0) {
					buddy.base64Image = buddyPicture;
					NSString *pureImageString = [buddy.base64Image substringFromIndex:23];
					
					UIImage *newBuddyImage = [[self class] imageFromBase64String:pureImageString];
					
					[self updateBuddyDisplayImage:buddy withImage:newBuddyImage];
				} else if ([buddyPicture rangeOfString:@"img:"].location == 0) {
					
					// static/img/buddy/s46/
					NSURL *serverURL = [NSURL URLWithString:[SMConnectionController sharedInstance].currentImagesEndpoint];
					
					NSString *pictureURL = [[serverURL URLByAppendingPathComponent:@"buddy/s46/"] absoluteString];
					
					NSString *userSessionId = [buddy.sessionId copy];
					NSString *picturePath = [buddyPicture substringFromIndex:4];
					pictureURL = [pictureURL stringByAppendingFormat:@"%@", picturePath];

					[[ResourceDownloadManager sharedInstance] enqueueInMemoryDownloadTaskWithURL:[NSURL URLWithString:pictureURL] completionHandler: ^(NSData *data, NSError *error) {
						if (!error) {
							
							UIImage *image = [[UIImage alloc] initWithData:data];
							[self asynchronousUpdateImageForUserWithSessionId:userSessionId withImage:image imageRevision:statusRev];
						} else {
							spreed_me_log("Error downloading image %s", [error cDescription]);
							[self asynchronousUpdateImageForUserWithSessionId:userSessionId withImage:nil imageRevision:statusRev];
						}
					}];	
				} else {
					[self updateBuddyDisplayImage:buddy withImage:nil];
				}
			}
			break;
				
			default:
				spreed_me_log("Unknown BuddyDictionaryType!");
				break;
		}
		
	} else {
		spreed_me_log("No buddy or buddyDic to update!!!");
	}
}


- (void)updateBuddyDisplayImage:(User *)buddy withImage:(UIImage *)image
{
	if (!image) {
		image = [UIImage imageNamed:@"buddy_icon.png"];
	}
    
    UIImage *roundedImage = [image roundCornersWithRadius:kViewCornerRadius];
    
    buddy.iconImage = roundedImage;
}


- (void)asynchronousUpdateImageForUserWithSessionId:(NSString *)userSessionId withImage:(UIImage *)image imageRevision:(uint64_t)rev
{
	if ([userSessionId length]) {
		if (!image) {
			image = [UIImage imageNamed:@"buddy_icon.png"];
		}
		
		UIImage *roundedImage = [image roundCornersWithRadius:kViewCornerRadius];
		
		NSDictionary *userInfo = @{UserSessionIdUserInfoKey : userSessionId,
								   BuddyImageUserInfoKey : roundedImage,
								   SMUserImageRevisionUserInfoKey : @(rev)};
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSNotificationCenter defaultCenter] postNotificationName:BuddyImageHasBeenUpdatedNotification object:self userInfo:userInfo];
		});
	}
}


#pragma mark - Convenience default image creation

+ (UIImage *)defaultUserImage
{
	UIImage *image = [UIImage imageNamed:@"buddy_icon.png"];
	UIImage *roundedImage = [image roundCornersWithRadius:kViewCornerRadius];
	return roundedImage;
}


+ (NSString *)defaultUserDisplayNameForSessionId:(NSString *)sessionId
{
	return [[SMUserParserHelper sharedInstance] generateUserDisplayNameForSessionId:sessionId];
}


#pragma mark - Convenience Base64 string based images conversions

+ (UIImage *)imageFromBase64String:(NSString *)base64ImageString
{
	UIImage *image = nil;
	
	if (![base64ImageString isKindOfClass:[NSNull class]] && [base64ImageString length] > 10)
    {
		NSData *imageData = nil;
		
		if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7.0) {
			imageData = [[NSData alloc] initWithBase64Encoding:base64ImageString];
		} else {
			imageData = [[NSData alloc] initWithBase64EncodedString:base64ImageString options:NSDataBase64DecodingIgnoreUnknownCharacters];
		}
		
        image = [UIImage imageWithData:imageData];
    }
	
	return image;
}


+ (UIImage *)imageFromBase64StringWithFormatPrefix:(NSString *)base64ImageString
{
	UIImage *image = nil;
	
	if (![base64ImageString isKindOfClass:[NSNull class]] && [base64ImageString length] > 10)
    {
		NSString *pureImageString = [base64ImageString substringFromIndex:23];
        image = [self imageFromBase64String:pureImageString];
    }
	
	return image;
}


+ (NSString *)base64EncodedStringFromImage:(UIImage *)image
{
	NSData *pngData = UIImageJPEGRepresentation(image, 1.0);
	
	NSString *imageString = nil;
	
	if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7.0) {
		imageString = [pngData base64Encoding];
	} else {
		imageString = [pngData base64EncodedStringWithOptions:0];
	}
	
	return imageString;
}


+ (NSString *)base64EncodedStringWithFormatPrefixFromImage:(UIImage *)image
{
	NSString *imageString = [self base64EncodedStringFromImage:image];

	if (imageString) {
		imageString = [base64APIImageHeader stringByAppendingString:imageString];
	}
	
	return imageString;
}



@end
