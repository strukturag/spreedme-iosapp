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

#import "SMAppIdentityController.h"

#import "AES256Encryptor.h"
#import "NSData+Conversion.h"
#import "NSData+XorData.h"
#import "UICKeyChainStore.h"
#import "UIDevice+Hardware.h"


NSString * const kSMClientIdKey						= @"SMclientId";
NSString * const kSMApplicationIdKey				= @"SMapplicationId";
NSString * const kSMApplicationNameKey				= @"SMApplicationName";
NSString * const kSMVersionForAuthenticationKey		= @"SMauthVersion";

NSString * const kInstallationUIDKey			= @"installationUID";
NSString * const kDefaultUserUIDKey				= @"defaultUserUID";

NSString * const kClientSecretKeyChainKey		= @"ClientSecretKeyChainKey";
NSString * const kSMBigAppIdentifier			= @"SMBigAppIdentifier";

NSString * const kSMFirstTimeLaunchCheckFileName = @"instUID.txt";


static NSString *savedSettingsFilePath();

static NSString *savedSettingsFilePath()
{
	NSString *generalAppSettingsFile = nil;
	
	NSString *appSupportDir = applicationSupportDirectory();
	if (appSupportDir) {
		generalAppSettingsFile = [appSupportDir stringByAppendingPathComponent:@"app.settings"];
	}
	
	return generalAppSettingsFile;
}


@interface SMAppIdentityController ()
{
	NSString *_devicePlatform;
	
	BOOL _isFirstLaunch;
}

@end


@implementation SMAppIdentityController

+ (instancetype)sharedInstance
{
	static dispatch_once_t once;
    static SMAppIdentityController *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] initOnce];
    });
    return sharedInstance;
}


- (instancetype)initOnce
{
	self = [super init];
	if (self) {
		_clientSecret = [UICKeyChainStore stringForKey:kClientSecretKeyChainKey];
	}
	return self;
}


- (instancetype)init
{
	self = nil;
	return nil;
}


#pragma mark - Public methods

- (void)initForFirstAppLaunch
{
    // Remove leftovers of previous installation
    // since iOS persists keychain between app installations
    [UICKeyChainStore removeAllItems];
    
    [UICKeyChainStore setString:@"1" forKey:kSMVersionForAuthenticationKey];
    
    NSString *installationUID = [[NSUUID UUID] UUIDString];
    [UICKeyChainStore setString:installationUID forKey:kInstallationUIDKey];
    
    NSString *defaultUserUID = [[NSUUID UUID] UUIDString];
    [UICKeyChainStore setString:defaultUserUID forKey:kDefaultUserUIDKey];
    
    NSString *applicationId = [NSString stringWithFormat:@"%@ - %@", [[UIDevice currentDevice] name], [[NSUUID UUID] UUIDString]];
    [UICKeyChainStore setString:applicationId forKey:kSMApplicationIdKey];
    
    _clientSecret = [[AES256Encryptor randomDataOfLength:32] hexadecimalString];
    [UICKeyChainStore setString:_clientSecret forKey:kClientSecretKeyChainKey];
    
    NSData *bigAppIdentifier = [AES256Encryptor randomDataOfLength:37];
    
    // XOR(obfuscate) encryption key before storing it in keychain
    NSData *xData = [[installationUID stringByReplacingOccurrencesOfString:@"-" withString:@""] dataUsingEncoding:NSUTF8StringEncoding];
    bigAppIdentifier = [bigAppIdentifier dataXORedWithData:xData];
    
    [UICKeyChainStore setData:bigAppIdentifier forKey:kSMBigAppIdentifier];
}

- (void)setClientSecret:(NSString *)clientSecret
{
	_clientSecret = [clientSecret copy];
	[UICKeyChainStore setString:_clientSecret forKey:kClientSecretKeyChainKey];
}


- (NSInteger)version
{
	NSInteger version = -1;
	
	NSString *versionString = [UICKeyChainStore stringForKey:kSMVersionForAuthenticationKey];
	if (versionString) {
		version = [versionString integerValue];
	}
	
	return version;
}


- (NSString *)clientId
{
	return @"spreedme-ios";
}


- (NSString *)applicationId
{
	return [[UICKeyChainStore stringForKey:kSMApplicationIdKey] copy];
}


- (NSString *)applicationName
{
	return @"Spreed.ME iOS app";
}


- (NSString *)installationUID
{
	return [[UICKeyChainStore stringForKey:kInstallationUIDKey] copy];
}


- (NSString *)defaultUserUID
{
	return [[UICKeyChainStore stringForKey:kDefaultUserUIDKey] copy];
}


- (BOOL)isFirstAppLaunch
{
	return _isFirstLaunch;
}


- (NSData *)appBigIdentifier
{
	// deXOR(deobfuscate) encryption key before giving it for usage
	NSString *trimmedInstUID = [[self installationUID] stringByReplacingOccurrencesOfString:@"-" withString:@""];
	NSData *xData = [trimmedInstUID dataUsingEncoding:NSUTF8StringEncoding];
	NSData *decData = [UICKeyChainStore dataForKey:kSMBigAppIdentifier];
	NSData *xorData = [decData dataXORedWithData:xData];
	return xorData;
}


#pragma mark - Utilities - Device model

- (NSString *)deviceModelName
{
	iOSDeviceModel model = [self deviceModel];
	
	NSString *modelName = nil;
	
	
	switch (model) {
		case kiOSDeviceiPhone4:
			modelName = @"iPhone4";
			break;
		case kiOSDeviceiPhone4s:
			modelName = @"iPhone4s";
			break;
		case kiOSDeviceiPhone5:
			modelName = @"iPhone5";
			break;
		case kiOSDeviceiPhone5c:
			modelName = @"iPhone5c";
			break;
		case kiOSDeviceiPhone5s:
			modelName = @"iPhone5s";
			break;
		case kiOSDeviceiPhone6:
			modelName = @"iPhone6";
			break;
		case kiOSDeviceiPhone6Plus:
			modelName = @"iPhone6 Plus";
			break;
		case kiOSDeviceiPad2:
			modelName = @"iPad2";
			break;
		case kiOSDeviceiPad3:
			modelName = @"New iPad";
			break;
		case kiOSDeviceiPad4:
			modelName = @"iPad4";
			break;
		case kiOSDeviceiPadAir:
			modelName = @"iPad Air";
			break;
		case kiOSDeviceiPadMini1:
			modelName = @"iPad mini";
			break;
		case kiOSDeviceiPadMini2:
			modelName = @"iPad mini Retina";
			break;
		case kiOSDeviceiPod4:
			modelName = @"iPod4";
			break;
		case kiOSDeviceiPod5:
			modelName = @"iPod5";
			break;
			
		case kiOSDeviceUnsupported:
		default:
			break;
	}

	return modelName;
}


// Based on http://www.everyi.com/by-identifier/ipod-iphone-ipad-specs-by-model-identifier.html
- (iOSDeviceModel)deviceModel
{
	if (!_devicePlatform) {
		_devicePlatform = [[UIDevice currentDevice] platform];
	}
	
	iOSDeviceModel model = kiOSDeviceUnsupported;
	
	if ([_devicePlatform rangeOfString:@"iPhone3"].location != NSNotFound) {
		model = kiOSDeviceiPhone4;
	} else if ([_devicePlatform rangeOfString:@"iPhone4"].location != NSNotFound) {
		model = kiOSDeviceiPhone4s;
	} else if ([_devicePlatform rangeOfString:@"iPhone5,1"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPhone5,2"].location != NSNotFound) {
		model = kiOSDeviceiPhone5;
	} else if ([_devicePlatform rangeOfString:@"iPhone5,3"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPhone5,4"].location != NSNotFound) {
		model = kiOSDeviceiPhone5c;
	} else if ([_devicePlatform rangeOfString:@"iPhone6"].location != NSNotFound) {
		model = kiOSDeviceiPhone5s;
	} else if ([_devicePlatform rangeOfString:@"iPhone7,1"].location != NSNotFound) {
		model = kiOSDeviceiPhone6Plus;
	} else if ([_devicePlatform rangeOfString:@"iPhone7,2"].location != NSNotFound) {
		model = kiOSDeviceiPhone6;
	} else if ([_devicePlatform rangeOfString:@"iPad2,1"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad2,2"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad2,3"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad2,4"].location != NSNotFound) {
		model = kiOSDeviceiPad2;
	} else if ([_devicePlatform rangeOfString:@"iPad2,5"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad2,6"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad2,7"].location != NSNotFound ) {
		model = kiOSDeviceiPadMini1;
	} else if ([_devicePlatform rangeOfString:@"iPad3,1"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad3,2"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad3,3"].location != NSNotFound) {
		model = kiOSDeviceiPad3;
	} else if ([_devicePlatform rangeOfString:@"iPad3,4"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad3,5"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad3,6"].location != NSNotFound) {
		model = kiOSDeviceiPad4;
	} else if ([_devicePlatform rangeOfString:@"iPad4,1"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad4,2"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad4,3"].location != NSNotFound ) {
		model = kiOSDeviceiPad4; 
	} else if ([_devicePlatform rangeOfString:@"iPad4,4"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad4,5"].location != NSNotFound ||
			   [_devicePlatform rangeOfString:@"iPad4,6"].location != NSNotFound ) {
		model = kiOSDeviceiPadMini2;
	} else if ([_devicePlatform rangeOfString:@"iPod4"].location != NSNotFound) {
		model = kiOSDeviceiPod4;
	} else if ([_devicePlatform rangeOfString:@"iPod5"].location != NSNotFound) {
		model = kiOSDeviceiPod5;
	}
	
	return model;
}


@end
