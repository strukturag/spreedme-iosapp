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

#include <stdio.h>

const char kTypeKey[]				= "Type";
const char kLCTypeKey[]				= "type";
const char kDataKey[]				= "Data";
const char kFromKey[]				= "From";
const char kTokenKey[]				= "Token";
const char kLCTokenKey[]			= "token";
const char kAttestationTokenKey[]	= "A";
const char kVersionKey[]			= "Version";
const char kToKey[]					= "To";
const char kIdKey[]					= "Id";
const char kLCIdKey[]				= "id";
const char kSIdKey[]				= "Sid";
const char kIidKey[]				= "Iid";
const char kUserIdKey[]				= "Userid";
const char kLCUserIdKey[]			= "userid";
const char kSUserIdKey[]			= "Suserid";
const char kLCSizeKey[]				= "size";
const char kLCNameKey[]				= "name";
const char kLCUserNameKey[]			= "username";
const char kLCPasswordKey[]			= "password";
const char kLCUrlKey[]				= "url";
const char kLCUrlsKey[]				= "urls";
const char kUserAgentKey[]			= "Ua";
const char kNonceKey[]				= "Nonce";
const char kLCNonceKey[]			= "nonce";
const char kLCSecretKey[]			= "secret";
const char kLCUserIdComboKey[]		= "useridcombo";
const char kLCSessionKey[]			= "session";

const char kLCSuccessKey[]				= "success";
const char kLCAccess_TokenKey[]			= "access_token";
const char kLCRefresh_TokenKey[]		= "refresh_token";
const char kLCExpires_InKey[]			= "expires_in";
const char kLCUserComboKey[]			= "usercombo";
const char kLCApplication_TokenKey[]	= "application_token";

const char kLCCodeKey[]				= "code";

const char kOCDisplayNameKey[]      = "display_name";
const char kOCIsAdminKey[]          = "is_admin";
const char kOCIsSpreedMEAdminKey[]  = "is_spreedme_admin";

//Channeling message types
const char kAnswerKey[]			= "Answer";
const char kOfferKey[]			= "Offer";
const char kCandidateKey[]		= "Candidate";
const char kConferenceKey[]		= "Conference";
const char kLCConferenceKey[]	= "conference";
const char kByeKey[]			= "Bye";
const char kLCByeKey[]			= "bye";
const char kLeftKey[]			= "Left";
const char kJoinedKey[]			= "Joined";
const char kStatusKey[]			= "Status";
const char kUsersKey[]			= "Users";
const char kChatKey[]			= "Chat";
const char kTalkingKey[]		= "Talking";
const char kScreenShareKey[]	= "Screenshare";
const char kHelloKey[]			= "Hello";
const char kSelfKey[]			= "Self";
const char kAliveKey[]			= "Alive";
const char kAuthenticationKey[] = "Authentication";
const char kSessionsKey[]		= "Sessions";
const char kErrorKey[]			= "Error";
const char kCodeKey[]			= "Code";
const char kWelcomeKey[]		= "Welcome";
const char kRoomKey[]			= "Room";
const char kNameKey[]			= "Name";

const char kLCBuddyPictureKey[]	= "buddyPicture";
const char kLCDisplayNameKey[]	= "displayName";
const char kLCIsMixerKey[]		= "isMixer";
const char kRevKey[]			= "Rev";

const char kLCSoftKey[]			= "soft";
const char kLCHardKey[]			= "hard";

const char kMessageKey[]		= "Message";
const char kLCMessageKey[]		= "message";
const char kTypingKey[]			= "Typing";
const char kFileInfoKey[]		= "FileInfo";
const char kGeolocationKey[]	= "Geolocation";
const char kLCAccuracyKey[]     = "accuracy";
const char kLCLatitudeKey[]     = "latitude";
const char kLCLongitudeKey[]    = "longitude";
const char kLCAltitudeKey[]     = "altitude";
const char kLCAltitudeAccuKey[]	= "altitudeAccuracy";
const char kTimeKey[]			= "Time";
const char kMidKey[]			= "Mid";
const char kStateKey[]			= "State";
const char kLCDeliveredKey[]	= "delivered";
const char kLCSentKey[]			= "sent";
const char kSeenMidsKey[]		= "SeenMids";
const char kNoEchoKey[]			= "NoEcho";
const char kSuccessKey[]		= "Success";

const char kTurnKey[]			= "Turn";
const char kStunKey[]			= "Stun";
const char kLCTtlKey[]			= "ttl";

const char kOfferConferenceKey[]		= "_conference";


// Keys used in Bye message
const char kByeReasonKey[]				= "Reason";
const char kByeReasonBusyString[]		= "busy";
const char kByeReasonNoAnswerString[]	= "pickuptimeout";
const char kByeReasonRejectString[]		= "reject";
const char kByeReasonAbortString[]		= "abort";

// Keys used for a IceCandidate JSON object.
const char kCandidateSdpMidKey[]				= "sdpMid";
const char kCandidateSdpMlineIndexKey[]			= "sdpMLineIndex";
const char kCandidateSdpKey[]					= "candidate";

// Keys used for a SessionDescription JSON object.
const char kSessionDescriptionSdpKey[]			= "sdp";

// Keys used in offer related to token data channels
const char kDataChannelTokenKey[]		= "_token";
const char kDataChannelIdKey[]			= "_id";

const char kDataChannelChunkRequestModeKey[]				= "m";
const char kDataChannelChunkRequestModeRequestKey[]			= "r";
const char kDataChannelChunkRequestModeByeKey[]				= "bye";
const char kDataChannelChunkSequenceNumberKey[]				= "i";

// Error codes
const char kErrorRoomCodeDefaultRoomDisabled[]				= "default_room_disabled";
const char kErrorRoomCodeAuthorisationRequired[]			= "authorization_required";
const char kErrorRoomCodeAuthorisationNotRequired[]			= "authorization_not_required";
const char kErrorRoomCodeInvalidCredentials[]				= "invalid_credentials";
const char kErrorRoomCodeRoomJoinRequiresAccount[]			= "room_join_requires_account";

// Keys used in file transfer
const char kLCChunksKey[]				= "chunks";
