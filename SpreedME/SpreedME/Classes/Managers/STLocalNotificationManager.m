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

#import "STLocalNotificationManager.h"


@implementation STLocalNotificationManager


#pragma mark - Class methods

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static STLocalNotificationManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


#pragma mark - Object lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
            UIUserNotificationSettings *currentSettings = [[UIApplication
                                                            sharedApplication] currentUserNotificationSettings];
            if ((currentSettings.types & UIUserNotificationTypeBadge) != 0) {
                _applicationIconBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber;
            } else {
                _applicationIconBadgeNumber = 0;
            }
        } else {
            _applicationIconBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber;
        }
    }
    return self;
}


#pragma mark - Setters/Getters

- (void)setApplicationIconBadgeNumber:(NSInteger)applicationIconBadgeNumber
{
    _applicationIconBadgeNumber = applicationIconBadgeNumber;
    BOOL badgesAllowed = YES;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        UIUserNotificationSettings *currentSettings = [[UIApplication
                                                        sharedApplication] currentUserNotificationSettings];
        if ((currentSettings.types & UIUserNotificationTypeBadge) == 0) {
            badgesAllowed = NO;
        }
    }
    
    if (badgesAllowed) {
        [UIApplication sharedApplication].applicationIconBadgeNumber = _applicationIconBadgeNumber;
    }
}


#pragma mark - Public methods

- (UILocalNotification *)createLocalNotificationWithSoundName:(NSString *)soundName
                                                    alertBody:(NSString *)alertBody
                                                  alertAction:(NSString *)alertAction
{
    UILocalNotification *localNotification = nil;
    self.applicationIconBadgeNumber += 1;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        UIUserNotificationSettings *currentSettings = [[UIApplication
                                                        sharedApplication] currentUserNotificationSettings];
        if (currentSettings.types != UIUserNotificationTypeNone) {
            localNotification = [[UILocalNotification alloc] init];
            localNotification.alertBody = alertBody;
            localNotification.alertAction = alertAction;
            if ((currentSettings.types & UIUserNotificationTypeSound) != 0) {
                localNotification.soundName = soundName;
            }
            if ((currentSettings.types & UIUserNotificationTypeBadge) != 0) {
                localNotification.applicationIconBadgeNumber = self.applicationIconBadgeNumber;
            }
        }
    } else {
        localNotification = [[UILocalNotification alloc] init];
        localNotification.alertBody = alertBody;
        localNotification.alertAction = alertAction;
        localNotification.soundName = soundName;
        localNotification.applicationIconBadgeNumber = self.applicationIconBadgeNumber;
    }
    
    return localNotification;
}


- (BOOL)postLocalNotificationWithSoundName:(NSString *)soundName
                                 alertBody:(NSString *)alertBody
                               alertAction:(NSString *)alertAction
{
    UIApplication *app = [UIApplication sharedApplication];
    UILocalNotification *localNotification = [self createLocalNotificationWithSoundName:soundName
                                                                              alertBody:alertBody
                                                                            alertAction:alertAction];
    if (localNotification) {
        [app presentLocalNotificationNow:localNotification];
        return YES;
    }
    
    return NO;
}

@end
