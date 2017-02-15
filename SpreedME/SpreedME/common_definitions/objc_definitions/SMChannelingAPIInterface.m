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

#import "SMChannelingAPIInterface.h"


NSString * const ChannelingConnectionBecomeActiveNotification           = @"ChannelingConnectionBecomeActiveNotification";
NSString * const ChannelingConnectionBecomeInactiveNotification         = @"ChannelingConnectionBecomeInactiveNotification";

NSString * const ConnectionHasChangedStateNotification                  = @"ConnectionHasChangedStateNotification";
NSString * const kConnectionHasChangedStateNotificationNewStateKey      = @"kConnectionHasChangedStateNotificationNewStateKey";

NSString * const ConnectionControllerHasProcessedChangeOfApplicationModeNotification	= @"ConnectionControllerHasProcessedChangeOfApplicationModeNotification";
NSString * const ConnectionControllerHasProcessedResetOfApplicationNotification			= @"ConnectionControllerHasProcessedResetOfApplicationNotification";


NSString * const SelfMessageReceivedNotification					= @"SelfMessageReceivedNotification";
NSString * const ByeMessageReceivedNotification						= @"ByeMessageReceivedNotification";

NSString * const LocalUserDidLeaveRoomNotification					= @"LocalUserDidLeaveRoomNotification";
NSString * const LocalUserDidJoinRoomNotification					= @"LocalUserDidJoinRoomNotification";
NSString * const LocalUserDidReceiveDisabledDefaultRoomErrorNotification	= @"LocalUserDidTryToJoinToDisabledDefaultRoomNotification";
NSString * const kRoomUserInfoKey									= @"kRoomUserInfoKey";
NSString * const kRoomLeaveReasonUserInfoKey						= @"kRoomLeaveReasonUserInfoKey";
NSString * const kRoomLeaveReasonRoomChange							= @"kRoomLeaveReasonRoomChange";
NSString * const kRoomLeaveReasonRoomRoomExit						= @"kRoomLeaveReasonRoomRoomExit";


NSString * const RemoteUserHasStartedScreenSharingNotification		= @"RemoteUserHasStartedScreenSharingNotification";

NSString * const BuddyStatusDicNotificationUserInfoKey				= @"BuddyStatusDic";
NSString * const ByeFromNotificationUserInfoKey						= @"ByeFrom";
NSString * const ByeToNotificationUserInfoKey						= @"ByeTo";
NSString * const ByeReasonNotificationUserInfoKey					= @"ByeReason";
NSString * const SelfNotificationInfoKey							= @"SelfMessage";
NSString * const kSelfMessageIceServersKey							= @"kSelfMessageIceServersKey";

NSString * const kScreenSharingUserSessionIdInfoKey					= @"kScreenSharingUserSessionIdInfoKey";
NSString * const kScreenSharingTokenInfoKey							= @"kScreenSharingTokenInfoKey";

NSString * const kChannelingConnectionBecomeInactiveReasonKey				= @"kChannelingConnectionBecomeInactiveReasonKey";
NSString * const kChannelingConnectionBecomeInactiveLoginFailedReasonKey	= @"kChannelingConnectionBecomeInactiveLoginFailedReasonKey";



@implementation SMChannelingRequest

+ (instancetype)requestWithIid:(NSString *)iid type:(NSString *)type
{
	SMChannelingRequest *request = [[SMChannelingRequest alloc] init];
	request.iid = iid;
	request.type = type;
	return request;
}


- (BOOL)isSame:(SMChannelingRequest *)otherRequest
{
	return ([self.iid isEqualToString:otherRequest.iid] &&
			[self.type isEqualToString:otherRequest.type]);
}


@end
