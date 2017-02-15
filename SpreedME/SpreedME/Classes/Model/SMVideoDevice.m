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

#import "SMVideoDevice.h"

#import <AVFoundation/AVFoundation.h>


@implementation SMVideoDeviceCapability
- (NSString *)description
{
    return [NSString stringWithFormat:@"%@; w=%ld, h=%ld, maxFPS=%ld", [super description], _videoFrameWidth, _videoFrameHeight, _maxFPS];
}
@end


@implementation SMVideoDevice

+ (instancetype)defaultVideoDevice
{
    NSString *videoDeviceID = nil;
    NSString *videoDeviceLocalizedName = nil;
    if ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count]) {
        /*
         We assume that the last device will be the front camera. Usually on iphones back
         camera UID is "com.apple.avfoundation.avcapturedevice.built-in_video:0" and the
         front camera UID is "com.apple.avfoundation.avcapturedevice.built-in_video:1".
         However there is ipod 5 without back camera and potentialy there can be devices
         with only one camera, that is why we need to be careful with camera naming in
         the app.
         */
        AVCaptureDevice* device = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] lastObject];
        videoDeviceID = device.uniqueID;
        videoDeviceLocalizedName = device.localizedName;
    }
    
    if (videoDeviceID == nil) {
        spreed_me_log("This iOS device does not have any video camera.");
    }
    
    SMVideoDevice *videoDevice = [[SMVideoDevice alloc] init];
    videoDevice.deviceId = videoDeviceID;
    videoDevice.deviceLocalizedName = videoDeviceLocalizedName;
    
    return videoDevice;
}


- (NSString *)description
{
    return [NSString stringWithFormat:@"%@; id=%@, name=%@", [super description], _deviceId, _deviceLocalizedName];
}


+ (NSString *)localizedNameForDeviceId:(NSString *)deviceId
{
    NSString *localizedName = nil;
    NSArray *captureDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in captureDevices) {
        if ([device.uniqueID isEqualToString:deviceId]) {
            localizedName = device.localizedName;
            break;
        }
    }
    
    return localizedName;
}


@end
