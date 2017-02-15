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

#ifndef __SpreedME__ChannelingConstants__
#define __SpreedME__ChannelingConstants__


extern const char kTypeKey[];
extern const char kLCTypeKey[]; // LC == lower case
extern const char kDataKey[];
extern const char kFromKey[];
extern const char kTokenKey[];
extern const char kLCTokenKey[];
extern const char kAttestationTokenKey[];
extern const char kVersionKey[];
extern const char kToKey[];
extern const char kIdKey[];
extern const char kLCIdKey[];
extern const char kSIdKey[];
extern const char kIidKey[];
extern const char kUserIdKey[];
extern const char kLCUserIdKey[];
extern const char kSUserIdKey[];
extern const char kLCSizeKey[];
extern const char kLCNameKey[];
extern const char kLCUserNameKey[];
extern const char kLCPasswordKey[];
extern const char kLCUrlKey[];
extern const char kLCUrlsKey[];
extern const char kUserAgentKey[];
extern const char kNonceKey[];
extern const char kLCNonceKey[];
extern const char kLCSecretKey[];
extern const char kLCUserIdComboKey[];
extern const char kLCSessionKey[];

extern const char kLCBuddyPictureKey[];
extern const char kLCDisplayNameKey[];
extern const char kLCIsMixerKey[];
extern const char kRevKey[];

extern const char kLCSoftKey[];
extern const char kLCHardKey[];

extern const char kLCSuccessKey[];
extern const char kLCAccess_TokenKey[];
extern const char kLCRefresh_TokenKey[];
extern const char kLCExpires_InKey[];
extern const char kLCUserComboKey[];
extern const char kLCApplication_TokenKey[];

extern const char kLCCodeKey[];

extern const char kOCDisplayNameKey[];
extern const char kOCIsAdminKey[];
extern const char kOCIsSpreedMEAdminKey[];


//Channeling message types
extern const char kAnswerKey[];
extern const char kOfferKey[];
extern const char kCandidateKey[];
extern const char kConferenceKey[];
extern const char kLCConferenceKey[];
extern const char kByeKey[];
extern const char kLCByeKey[];
extern const char kLeftKey[];
extern const char kJoinedKey[];
extern const char kStatusKey[];
extern const char kUsersKey[];
extern const char kChatKey[];
extern const char kTalkingKey[];
extern const char kScreenShareKey[];
extern const char kHelloKey[];
extern const char kSelfKey[];
extern const char kAliveKey[];
extern const char kAuthenticationKey[];
extern const char kSessionsKey[];
extern const char kErrorKey[];
extern const char kCodeKey[];
extern const char kWelcomeKey[];
extern const char kRoomKey[];
extern const char kNameKey[];

extern const char kMessageKey[];
extern const char kLCMessageKey[];
extern const char kTypingKey[];
extern const char kFileInfoKey[];
extern const char kGeolocationKey[];
extern const char kLCAccuracyKey[];
extern const char kLCLatitudeKey[];
extern const char kLCLongitudeKey[];
extern const char kLCAltitudeKey[];
extern const char kLCAltitudeAccuKey[];
extern const char kTimeKey[];
extern const char kMidKey[];
extern const char kStateKey[];
extern const char kLCDeliveredKey[];
extern const char kLCSentKey[];
extern const char kSeenMidsKey[];
extern const char kNoEchoKey[];
extern const char kSuccessKey[];

extern const char kTurnKey[];
extern const char kStunKey[];
extern const char kLCTtlKey[];

extern const char kOfferConferenceKey[];

// Keys used in Bye message
extern const char kByeReasonKey[];
extern const char kByeReasonBusyString[];
extern const char kByeReasonNoAnswerString[];
extern const char kByeReasonRejectString[];
extern const char kByeReasonAbortString[];

// Keys used for a IceCandidate JSON object.
extern const char kCandidateSdpMidKey[];
extern const char kCandidateSdpMlineIndexKey[];
extern const char kCandidateSdpKey[];

// Keys used for a SessionDescription JSON object.
extern const char kSessionDescriptionSdpKey[];

// Keys used in offer related to token data channels
extern const char kDataChannelTokenKey[];
extern const char kDataChannelIdKey[];

extern const char kDataChannelChunkRequestModeKey[];
extern const char kDataChannelChunkRequestModeRequestKey[];
extern const char kDataChannelChunkRequestModeByeKey[];
extern const char kDataChannelChunkSequenceNumberKey[];

// Error codes
extern const char kErrorRoomCodeDefaultRoomDisabled[];
extern const char kErrorRoomCodeAuthorisationRequired[];
extern const char kErrorRoomCodeAuthorisationNotRequired[];
extern const char kErrorRoomCodeInvalidCredentials[];
extern const char kErrorRoomCodeRoomJoinRequiresAccount[];

// Keys used in file transfer
extern const char kLCChunksKey[];

typedef enum ByeReason
{
	kByeReasonNotSpecified = 0,
	kByeReasonBusy, // remote user is in the call
	kByeReasonNoAnswer, // remote user doesn't pickup
	kByeReasonReject, // remote user rejected call
	kByeReasonAbort, // remote user who was calling stopped calling before local user picked up
}
ByeReason;


typedef enum FinishedCallReason
{
	kFinishedCallReasonNotSpecified = 10,
	kFinishedCallReasonLocalUserHungUp,
	kFinishedCallReasonRemoteUserHungUp,
	kFinishedCallReasonLocalUserBusy,
	kFinishedCallReasonRemoteUserBusy,
}
FinishedCallReason;


typedef enum ChannelingMessageTransportType
{
	kTransportTypeAuto = 0, // for sending means auto, for receiving means unknown (should not happen)
	kWebsocketChannelingServer,
	kPeerToPeer,
}
ChannelingMessageTransportType;


#endif /* defined(__SpreedME__ChannelingConstants__) */
