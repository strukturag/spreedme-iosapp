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

#import "RoundedRectButton.h"

typedef enum SpreedMeButton
{
	kSpreedMeButtonTypeUndefined = 0,
	kSpreedMeButtonTypeCall,
	kSpreedMeButtonTypeVideoCall,
	kSpreedMeButtonTypeAddToCall,
    kSpreedMeButtonTypeHangUp,
    kSpreedMeButtonTypeVolume,
    kSpreedMeButtonTypeAddParticipants,
	kSpreedMeButtonTypeChat,
	kSpreedMeButtonTypeFile,
    kSpreedMeButtonTypeFullInfo,
    kSpreedMeButtonTypeChangeServer,
    kSpreedMeButtonTypeAbout,
    kSpreedMeButtonTypeLogOut,
    kSpreedMeButtonTypeLogIn,
    kSpreedMeButtonTypeChangeVideoOptions,
	kSpreedMeButtonTypeDisconnect,
	kSpreedMeButtonTypeConnect,
    kSpreedMeButtonTypeCreate,
    kSpreedMeButtonTypeReload,
	kSpreedMeButtonTypeAcceptWithVideo,
	kSpreedMeButtonTypeAcceptNoVideo,
	kSpreedMeButtonTypeRejectCall,
	kSpreedMeButtonTypeCancelOutgoingCall,
    kSpreedMeButtonTypeSignIn
}
SpreedMeButtonType;

@interface SpreedMeRoundedButton : RoundedRectButton

- (void)configureButtonWithButtonType:(SpreedMeButtonType)type;

@end
