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

@interface STLocalNotificationManager : NSObject

@property (nonatomic, assign) NSInteger applicationIconBadgeNumber;

+ (instancetype)sharedInstance;

/*
 This method returns nil if the local notifications can not be posted due to user notification settings for the app.
 NOTE: We can check user notification settings only on iOS 8.
 */
- (UILocalNotification *)createLocalNotificationWithSoundName:(NSString *)soundName
                                                    alertBody:(NSString *)alertBody
                                                  alertAction:(NSString *)alertAction;

/*
 This method returns NO if the local notifications can not be posted due to user notification settings for the app.
 NOTE: We can check user notification settings only on iOS 8. On <iOS7 this method will return YES but notications
       won't be shown due to user settings.
 */
- (BOOL)postLocalNotificationWithSoundName:(NSString *)soundName
                                 alertBody:(NSString *)alertBody
                               alertAction:(NSString *)alertAction;

@end
