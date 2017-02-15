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

#import "SMSettingsProtocols.h"


@interface SMVideoSettings : NSObject 

@property (nonatomic, copy) NSString *deviceId;
@property (nonatomic, assign) NSInteger frameWidth;
@property (nonatomic, assign) NSInteger frameHeight;
@property (nonatomic, assign) NSInteger fps;

+ (instancetype)defaultSettings;

@end


@interface SMLocalUserSettings : NSObject <SMSettingsDictionaryRepresentation>

// Background settings
@property (nonatomic, readwrite) BOOL shouldDisconnectOnBackground;
@property (nonatomic, readwrite) BOOL shouldClearDataOnBackground;

// Server settings
@property (nonatomic, copy) NSString *serverString;
@property (nonatomic, strong) NSMutableArray *serverHistory; // contains server URLs as NSStrings

// Video settings
@property (nonatomic, copy) NSString *videoDeviceId;
@property (nonatomic, assign) NSInteger frameWidth;
@property (nonatomic, assign) NSInteger frameHeight;
@property (nonatomic, assign) NSInteger fps;

@end



void SMSetVideoSettingsToLocalUserSettings(SMVideoSettings *videoSettings, /*out*/ SMLocalUserSettings *localUserSettings);
void SMSetLocalUserSettingsToVideoSettings(SMLocalUserSettings *localUserSettings, /*out*/ SMVideoSettings *videoSettings);
SMVideoSettings * SMVideoSettingsFromLocalUserSettings(SMLocalUserSettings *localUserSettings);
