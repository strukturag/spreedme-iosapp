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

#import "SMLocalUserSettings.h"


#import "SMVideoDevice.h"

NSString * const kSMBackgroundSettingsShouldDisconnectOnBackgroundKey       = @"disconnOnBg";
NSString * const kSMBackgroundSettingsShouldClearDataOnBackgroundKey        = @"clearData";

NSString * const kSMServerSettingsServerURLKey                              = @"url";
NSString * const kSMServerSettingsHistoryKey                                = @"history";

NSString * const kSMVideoSettingsDeviceIdKey                                = @"deviceId";
NSString * const kSMVideoSettingsFrameWidthKey                              = @"frameWidth";
NSString * const kSMVideoSettingsFrameHeightKey                             = @"frameHeight";
NSString * const kSMVideoSettingsFPSKey                                     = @"FPS";

#pragma mark - SMVideoSettings

@implementation SMVideoSettings

+ (instancetype)defaultSettings
{
    SMVideoSettings *settings = [[self alloc] init];
    
    settings.deviceId = [SMVideoDevice defaultVideoDevice].deviceId;
    settings.frameHeight = 480;
    settings.frameWidth = 640;
    settings.fps = 0;
    
    return settings;
}


@end



#pragma mark - SMLocalUserSettings Class

@implementation SMLocalUserSettings

+ (instancetype)defaultSettings
{
    SMLocalUserSettings *settings = [[self alloc] init];
    
    // Video settings
    settings.videoDeviceId = [SMVideoDevice defaultVideoDevice].deviceId;
    settings.frameHeight = 480;
    settings.frameWidth = 640;
    settings.fps = 0;

    // Server settings
    settings.serverString = nil;
    settings.serverHistory = [[NSMutableArray alloc] init];
    
    // Background settings
    settings.shouldClearDataOnBackground = NO;
    settings.shouldDisconnectOnBackground = NO;
    
    return settings;
}


+ (instancetype)settingsFromDictionary:(NSDictionary *)dictionary
{
    SMLocalUserSettings *settings = nil;
    if (dictionary) {
        settings = [[self alloc] init];
        
        // Video settings
        NSString *deviceId = dictionary[kSMVideoSettingsDeviceIdKey];
        if (!deviceId) {
            settings.videoDeviceId = [SMVideoDevice defaultVideoDevice].deviceId;
        } else {
            settings.videoDeviceId = deviceId;
        }
        
        NSInteger frameHeight = [dictionary[kSMVideoSettingsFrameHeightKey] integerValue];
        NSInteger frameWidth = [dictionary[kSMVideoSettingsFrameWidthKey] integerValue];
        if (frameHeight > 0 && frameWidth) {
            settings.frameHeight = frameHeight;
            settings.frameWidth = frameWidth;
        } else {
            settings.frameHeight = 480;
            settings.frameWidth = 640;
        }
        
        settings.fps = [dictionary[kSMVideoSettingsFPSKey] integerValue];
        
        
        // Server settings
        settings.serverString = dictionary[kSMServerSettingsServerURLKey];
        
        NSArray *history = dictionary[kSMServerSettingsHistoryKey];
        if (history) {
            settings.serverHistory = [NSMutableArray arrayWithArray:history];
        } else {
            settings.serverHistory = [NSMutableArray array];
        }
        
        
        // Background settings
        settings.shouldDisconnectOnBackground = [dictionary[kSMBackgroundSettingsShouldDisconnectOnBackgroundKey] boolValue];
        settings.shouldClearDataOnBackground = [dictionary[kSMBackgroundSettingsShouldClearDataOnBackgroundKey] boolValue];
    }
    
    return settings;
}


- (NSDictionary *)dictionaryFromSettings
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // Video settings
    if (self.videoDeviceId) {
        [dict setObject:self.videoDeviceId forKey:kSMVideoSettingsDeviceIdKey];
    }
    
    [dict setObject:@(self.frameHeight) forKey:kSMVideoSettingsFrameHeightKey];
    [dict setObject:@(self.frameWidth) forKey:kSMVideoSettingsFrameWidthKey];
    [dict setObject:@(self.fps) forKey:kSMVideoSettingsFPSKey];
    
    
    // Server settings
    if (self.serverString) {
        [dict setObject:self.serverString forKey:kSMServerSettingsServerURLKey];
    }
    if (self.serverHistory.count > 0) {
        [dict setObject:self.serverHistory forKey:kSMServerSettingsHistoryKey];
    }
    
    
    // Background settings
    [dict setObject:@(self.shouldDisconnectOnBackground) forKey:kSMBackgroundSettingsShouldDisconnectOnBackgroundKey];
    [dict setObject:@(self.shouldClearDataOnBackground) forKey:kSMBackgroundSettingsShouldClearDataOnBackgroundKey];
    
    return [NSDictionary dictionaryWithDictionary:dict];
}


@end


#pragma mark -
#pragma mark - Convenience convertation functions

void SMSetVideoSettingsToLocalUserSettings(SMVideoSettings *videoSettings, /*out*/ SMLocalUserSettings *localUserSettings)
{
    localUserSettings.videoDeviceId = videoSettings.deviceId;
    localUserSettings.frameWidth = videoSettings.frameWidth;
    localUserSettings.frameHeight = videoSettings.frameHeight;
    localUserSettings.fps = videoSettings.fps;
}


void SMSetLocalUserSettingsToVideoSettings(SMLocalUserSettings *localUserSettings, /*out*/ SMVideoSettings *videoSettings)
{
    videoSettings.deviceId = localUserSettings.videoDeviceId;
    videoSettings.frameWidth = localUserSettings.frameWidth;
    videoSettings.frameHeight = localUserSettings.frameHeight;
    videoSettings.fps = localUserSettings.fps;
}


SMVideoSettings * SMVideoSettingsFromLocalUserSettings(SMLocalUserSettings *localUserSettings)
{
    SMVideoSettings *videoSettings = [[SMVideoSettings alloc] init];
    
    videoSettings.deviceId = localUserSettings.videoDeviceId;
    videoSettings.frameWidth = localUserSettings.frameWidth;
    videoSettings.frameHeight = localUserSettings.frameHeight;
    videoSettings.fps = localUserSettings.fps;
    
    return videoSettings;
}
