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

#import "CommonDefinitions.h"

NSString * const UserHasResetApplicationNotification		= @"UserHasResetApplicationNotification";
NSString * const UserHasChangedApplicationModeNotification	= @"UserHasChangedApplicationModeNotification";

// App login state notification and its user info key
NSString * const SMAppLoginStateHasChangedNotification		= @"SMAppLoginStateHasChangedNotification";
NSString * const kSMNewAppLoginStateKey		= @"SMNewAppLoginStateKey";
NSString * const kSMOldAppLoginStateKey		= @"SMOldAppLoginStateKey";

NSString * const kApplicationModeKey				= @"kApplicationModeKey";
NSString * const kLoginScreenShouldBeVisibleKey		= @"kLoginScreenShouldBeVisibleKey";


NSString * const kSMSpreedMeModeOnString			= @"SMSpreed.ME mode";
NSString * const kSMSpreedMeModeOffString			= @"ownSpreed mode";
NSString * const kOCOwnCloudModeOnString			= @"ownCloud mode";


// Application version related notifications
NSString * const SMAppVersionCheckStateChangedNotification  = @"SMAppVersionCheckStateChangedNotification";
NSString * const kSMAppVersionCheckStateNotificationKey     = @"SMAppVersionCheckStateNotificationKey";

// Local User related notifications 
NSString * const UserHasChangedDisplayNameNotification		= @"UserHasChangedDisplayNameNotification";
NSString * const UserHasChangedStatusMessageNotification	= @"UserHasChangedStatusMessageNotification";
NSString * const UserHasChangedDisplayImageNotification		= @"UserHasChangedDisplayImageNotification";
NSString * const UserHasBeenChangedNotification				= @"UserHasBeenChangedNotification";
