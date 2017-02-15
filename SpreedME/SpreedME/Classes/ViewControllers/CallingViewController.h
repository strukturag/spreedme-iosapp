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

#import <UIKit/UIKit.h>

#import "User.h"
#import "BuddyCollectionViewCell.h"
#import "PeerConnectionController.h"


@class CallingViewController;

@protocol CallingViewControllerUserActionsDelegate <NSObject>
@required
- (void)userHangUpInCallingViewController:(CallingViewController *)callingVC;
- (void)userCanceledOutgoingCall:(CallingViewController *)callingVC;
- (void)callingViewController:(CallingViewController *)callingVC userRejectedIncomingCall:(User *)from;
- (void)callingViewController:(CallingViewController *)callingVC userAcceptedIncomingCall:(User *)from withVideo:(BOOL)withVideo;

/* 
 In this case withVideo is advisory. If call already doesn't have video even if you set withVideo=YES it doesn't matter.
 If call already has video setting withVideo to NO has effect;
*/
- (void)callingViewController:(CallingViewController *)callingVC userAddedBuddyToCall:(User *)buddy withVideo:(BOOL)withVideo;

@optional
- (void)callingViewController:(CallingViewController *)callingVC userSetSoundMuted:(BOOL)muted;
- (void)callingViewController:(CallingViewController *)callingVC userSetVideoMuted:(BOOL)muted;
- (NSArray *)getCamerasListForCallingViewController:(CallingViewController *)callingVC;

@end


@interface CallingViewController : UIViewController <UserIntefaceCallbacks>

@property (nonatomic, weak) id<CallingViewControllerUserActionsDelegate> userActionsDelegate;

@property (nonatomic, readonly) NSMutableArray *buddiesOnCall;

@property (nonatomic, assign) BOOL hasScreenSharingUsers;

- (void)addToCallUserSessionId:(NSString *)userSessionId withVisualState:(UserCallVisualState)visualState;
- (void)userHasStartedScreensharing:(NSString *)userSessionId;
- (void)removeFromCallUserSessionId:(NSString *)userSessionId;

@end
