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

// Notifications
extern NSString * const UserHasResetApplicationNotification;
extern NSString * const UserHasChangedApplicationModeNotification;

// App login state notification and its user info key
typedef enum : NSInteger {
    kSMAppLoginStateNoLoginRequired = 0,
    kSMAppLoginStatePromptUserToLogin,
	kSMAppLoginStateWaitForAutomaticLogin,
	kSMAppLoginStateUserIsLoggedIn
} SMAppLoginState;

typedef enum : NSInteger {
    kSMAVCSError = -1, // Error retreiving app version from server
    kSMAVCSTooOldUnsupported = 0,
    kSMAVCSOldSupported, 
    kSMAVCSNewestAvailble,
    kSMAVCSNewDev, // newer than NewestAvailable from server, most likely dev version
} SMApplicationVersionCheckState;

extern NSString * const SMAppLoginStateHasChangedNotification;
extern NSString * const kSMNewAppLoginStateKey;
extern NSString * const kSMOldAppLoginStateKey;

// Keys for notification userInfo dictionaries
extern NSString * const kApplicationModeKey;
extern NSString * const kLoginScreenShouldBeVisibleKey;

// Spreed.ME app mode strings to use in keychain
extern NSString * const kSMSpreedMeModeOnString;
extern NSString * const kSMSpreedMeModeOffString;
extern NSString * const kOCOwnCloudModeOnString;


// Application version related notifications
extern NSString * const SMAppVersionCheckStateChangedNotification;
extern NSString * const kSMAppVersionCheckStateNotificationKey;


// Local user related notifications
extern NSString * const UserHasChangedDisplayNameNotification;
extern NSString * const UserHasChangedStatusMessageNotification;
extern NSString * const UserHasChangedDisplayImageNotification;
extern NSString * const UserHasBeenChangedNotification;