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

#ifndef SpreedME_SMLocalizedStrings_m
#define SpreedME_SMLocalizedStrings_m


// Labels

#define kSMLocalStringMeLabel NSLocalizedStringWithDefaultValue(@"label_me", nil, [NSBundle mainBundle], @"Me", @"Me. Personal pronoun as object")

#define kSMLocalStringNoDataLabel NSLocalizedStringWithDefaultValue(@"label_no-data", nil, [NSBundle mainBundle], @"No data", @"No data")

#define kSMLocalStringFileLabel NSLocalizedStringWithDefaultValue(@"label_file-singular", nil, [NSBundle mainBundle], @"File", @"Computer file.")
#define kSMLocalStringFilesLabel NSLocalizedStringWithDefaultValue(@"label_file-plural", nil, [NSBundle mainBundle], @"Files", @"Computer files.")

#define kSMLocalStringUserLabel NSLocalizedStringWithDefaultValue(@"label_user-singular", nil, [NSBundle mainBundle], @"User", @"User")
#define kSMLocalStringUsersLabel NSLocalizedStringWithDefaultValue(@"label_user-plural", nil, [NSBundle mainBundle], @"Users", @"Users")

#define kSMLocalStringChatLabel NSLocalizedStringWithDefaultValue(@"label_chat-singular", nil, [NSBundle mainBundle], @"Chat", @"Chat(noun)")
#define kSMLocalStringChatsLabel NSLocalizedStringWithDefaultValue(@"label_chat-plural", nil, [NSBundle mainBundle], @"Chats", @"Chats(noun)")

#define kSMLocalStringScreenSharingLabel NSLocalizedStringWithDefaultValue(@"label_screen-sharing", nil, [NSBundle mainBundle], @"Screen sharing", @"Screen sharing")

#define kSMLocalStringGeolocationLabel NSLocalizedStringWithDefaultValue(@"label_geolocation", nil, [NSBundle mainBundle], @"Geolocation", @"Geolocation")

#define kSMLocalStringLicensesLabel NSLocalizedStringWithDefaultValue(@"label_licenses", nil, [NSBundle mainBundle], @"Licenses", @"License")

#define kSMLocalStringSettingsLabel NSLocalizedStringWithDefaultValue(@"label_settings", nil, [NSBundle mainBundle], @"Settings", @"Settings")
#define kSMLocalStringVideoLabel NSLocalizedStringWithDefaultValue(@"label_video", nil, [NSBundle mainBundle], @"Video", @"Video");
#define kSMLocalStringBackgroundLabel NSLocalizedStringWithDefaultValue(@"label_background", nil, [NSBundle mainBundle], @"Background", @"Used for settings and general naming");

#define kSMLocalStringDisconnectedLabel NSLocalizedStringWithDefaultValue(@"label_disconnected", nil, [NSBundle mainBundle], @"Disconnected", @"Disconnected")

#define kSMLocalStringConnectedLabel NSLocalizedStringWithDefaultValue(@"label_connected", nil, [NSBundle mainBundle], @"Connected", @"Connected")

#define kSMLocalStringDataUsageLabel NSLocalizedStringWithDefaultValue(@"screen_title_data-usage", nil, [NSBundle mainBundle], @"Data usage", @"Data usage")

#define kSMLocalStringLedControlLabel NSLocalizedStringWithDefaultValue(@"screen_title_led-control", nil, [NSBundle mainBundle], @"LED Control", @"LED Control")

#define kSMLocalStringOwnSpreedModeLabel NSLocalizedStringWithDefaultValue(@"label_own-spreed-mode", nil, [NSBundle mainBundle], @"ownSpreed mode", @"Own spreed mode name. Probably shouldn't be translated. Depends on marketing")

#define kSMLocalStringSpreedboxModeLabel NSLocalizedStringWithDefaultValue(@"label_spreedbox-mode", nil, [NSBundle mainBundle], @"Spreedbox mode", @"Spreedbox mode name. Probably shouldn't be translated. Depends on marketing")

#define kSMLocalStringPhotoLibraryLabel NSLocalizedStringWithDefaultValue(@"label_photo-library", nil, [NSBundle mainBundle], @"Photo library", @"User device photo library")

#define kSMLocalStringInAppDocumentDirectory NSLocalizedStringWithDefaultValue(@"label_in-app-documents-directory", nil, [NSBundle mainBundle], @"Documents folder", @"In-app documents directory")

#define kSMLocalStringPasswordLabel NSLocalizedStringWithDefaultValue(@"label_password", nil, [NSBundle mainBundle], @"Password", @"Password")
#define kSMLocalStringUsernameLabel NSLocalizedStringWithDefaultValue(@"label_username", nil, [NSBundle mainBundle], @"Username", @"Username label. For login.")

#define kSMLocalStringPleaseWaitLabel NSLocalizedStringWithDefaultValue(@"label_please-wait", nil, [NSBundle mainBundle], @"Please wait", @"Generic 'please wait'")
#define kSMLocalStringPleaseWaitEllipsisLabel NSLocalizedStringWithDefaultValue(@"label_please-wait-ellipsis", nil, [NSBundle mainBundle], @"Please wait…", @"Generic 'please wait…'")

#define kSMLocalStringConnectingLabel NSLocalizedStringWithDefaultValue(@"label_connecting", nil, [NSBundle mainBundle], @"Connecting", @"Connecting");
#define kSMLocalStringConnectingEllipsisLabel NSLocalizedStringWithDefaultValue(@"label_connecting-ellipsis", nil, [NSBundle mainBundle], @"Connecting…", @"Connecting…");

#define kSMLocalStringColorLabel NSLocalizedStringWithDefaultValue(@"label_color", nil, [NSBundle mainBundle], @"Color", @"Color");
#define kSMLocalStringLedPreviewLabel NSLocalizedStringWithDefaultValue(@"label_led-preview", nil, [NSBundle mainBundle], @"Preview", @"Preview");
#define kSMLocalStringPatternLabel NSLocalizedStringWithDefaultValue(@"label_pattern", nil, [NSBundle mainBundle], @"Pattern", @"Pattern");
#define kSMLocalStringActionsLabel NSLocalizedStringWithDefaultValue(@"label_actions", nil, [NSBundle mainBundle], @"Actions", @"Actions");
#define kSMLocalStringImportPatternLabel NSLocalizedStringWithDefaultValue(@"label_import-pattern", nil, [NSBundle mainBundle], @"Import pattern", @"Import(verb) pattern");


// Buttons

#define kSMLocalStringCallButton NSLocalizedStringWithDefaultValue(@"button_call", nil, [NSBundle mainBundle], @"Call", @"Call as a verb. Keep as short as possible")
#define kSMLocalStringVideoCallButton NSLocalizedStringWithDefaultValue(@"button_video-call", nil, [NSBundle mainBundle], @"Video call", @"Call as a noun.")
#define kSMLocalStringVoiceCallButton NSLocalizedStringWithDefaultValue(@"button_voice-call", nil, [NSBundle mainBundle], @"Voice call", @"Call as a noun.")
#define kSMLocalStringSendMessageButton NSLocalizedStringWithDefaultValue(@"button_send-message", nil, [NSBundle mainBundle], @"Send a message", @"Message is a chat message.")
#define kSMLocalStringSendButton NSLocalizedStringWithDefaultValue(@"button_send", nil, [NSBundle mainBundle], @"Send", @"Please keep as short as possible.")
#define kSMLocalStringAddToCallButton NSLocalizedStringWithDefaultValue(@"button_add-to-call", nil, [NSBundle mainBundle], @"Add to call", @"Call as a noun.")
#define kSMLocalStringChatButton NSLocalizedStringWithDefaultValue(@"button_chat", nil, [NSBundle mainBundle], @"Chat", @"Chat as a verb. Keep as short as possible")
#define kSMLocalStringMoreOptionsButton NSLocalizedStringWithDefaultValue(@"button_more-option", nil, [NSBundle mainBundle], @"More options", @"Basically show more options. Keep as short as possible")
#define kSMLocalStringFullInfoButton NSLocalizedStringWithDefaultValue(@"button_full-info", nil, [NSBundle mainBundle], @"Full info", @"Basically show full info. Keep as short as possible")
#define kSMLocalStringHangUpButton NSLocalizedStringWithDefaultValue(@"button_hang-up", nil, [NSBundle mainBundle], @"Hang up", @"Hang up/finish call. Keep as short as possible")
#define kSMLocalStringAboutButton NSLocalizedStringWithDefaultValue(@"button_about", nil, [NSBundle mainBundle], @"About", @"Show something about something. Keep as short as possible")
#define kSMLocalStringChangeServerButton NSLocalizedStringWithDefaultValue(@"button_change-server", nil, [NSBundle mainBundle], @"Change server", @"Change(verb) server. Keep as short as possible")
#define kSMLocalStringSignOutButton NSLocalizedStringWithDefaultValue(@"button_sign-out", nil, [NSBundle mainBundle], @"Sign out", @"Sign out. Keep as short as possible")
#define kSMLocalStringSignInButton NSLocalizedStringWithDefaultValue(@"button_sign-in", nil, [NSBundle mainBundle], @"Sign in", @"Sign in. Keep as short as possible")
#define kSMLocalStringRegisterButton NSLocalizedStringWithDefaultValue(@"button_register", nil, [NSBundle mainBundle], @"Register", @"Register(verb)")
#define kSMLocalStringChangeOptionsButton NSLocalizedStringWithDefaultValue(@"button_change-option", nil, [NSBundle mainBundle], @"Change options", @"Change options. Keep as short as possible")
#define kSMLocalStringConnectButton NSLocalizedStringWithDefaultValue(@"button_connect", nil, [NSBundle mainBundle], @"Connect", @"Connect. Keep as short as possible")
#define kSMLocalStringDisconnectButton NSLocalizedStringWithDefaultValue(@"button_disconnect", nil, [NSBundle mainBundle], @"Disconnect", @"Disconnect. Keep as short as possible")
#define kSMLocalStringAnswerButton NSLocalizedStringWithDefaultValue(@"button_answer", nil, [NSBundle mainBundle], @"Answer", @"Answer(verb). Keep as short as possible")
#define kSMLocalStringVideoAnswerButton NSLocalizedStringWithDefaultValue(@"button_video-answer", nil, [NSBundle mainBundle], @"Video answer", @"Video answer(verb). Keep as short as possible")
#define kSMLocalStringCreateButton NSLocalizedStringWithDefaultValue(@"button_create", nil, [NSBundle mainBundle], @"Create", @"Create. Keep as short as possible")
#define kSMLocalStringRejectCallButton NSLocalizedStringWithDefaultValue(@"button_reject-call", nil, [NSBundle mainBundle], @"Reject call", @"Reject(verb) call(noun). Keep as short as possible")
#define kSMLocalStringStopCallingButton NSLocalizedStringWithDefaultValue(@"button_stop-calling", nil, [NSBundle mainBundle], @"Stop calling", @"Stop(verb) calling. Keep as short as possible")

#define kSMLocalStringRoomChatButton NSLocalizedStringWithDefaultValue(@"button_room-chat", nil, [NSBundle mainBundle], @"Room chat", @"Room chat. Keep as short as possible")
#define kSMLocalStringShareRoomButton NSLocalizedStringWithDefaultValue(@"button_share-room", nil, [NSBundle mainBundle], @"Share room", @"Share(verb) room. Keep as short as possible")
#define kSMLocalStringExitRoomButton NSLocalizedStringWithDefaultValue(@"button_exit-room", nil, [NSBundle mainBundle], @"Exit room", @"Exit(verb) room. Keep as short as possible")

#define kSMLocalStringAcceptButton NSLocalizedStringWithDefaultValue(@"button_accept", nil, [NSBundle mainBundle], @"Accept", @"Accept(verb). Keep as short as possible")
#define kSMLocalStringRejectButton NSLocalizedStringWithDefaultValue(@"button_reject", nil, [NSBundle mainBundle], @"Reject", @"Reject(verb). Keep as short as possible")
#define kSMLocalStringIgnoreButton NSLocalizedStringWithDefaultValue(@"button_ignore", nil, [NSBundle mainBundle], @"Ignore", @"Ignore(verb). Keep as short as possible")


#define kSMLocalStringEditButton NSLocalizedStringWithDefaultValue(@"button_edit", nil, [NSBundle mainBundle], @"Edit", @"Edit(verb). Keep as short as possible")
#define kSMLocalStringDoneButton NSLocalizedStringWithDefaultValue(@"button_done", nil, [NSBundle mainBundle], @"Done", @"The translation should be as short as possible.");

#define kSMLocalStringReadMessageButton NSLocalizedStringWithDefaultValue(@"button_read-message", nil, [NSBundle mainBundle], @"Read message", @"Read(verb) message. Keep as short as possible")

#define kSMLocalStringSignMeInButton NSLocalizedStringWithDefaultValue(@"button_sign-me-in", nil, [NSBundle mainBundle], @"Sign me in", @"Sign(verb) me in. Keep as short as possible")

#define kSMLocalStringCancelButton NSLocalizedStringWithDefaultValue(@"button_cancel", nil, [NSBundle mainBundle], @"Cancel", @"General cancel action")

#define kSMLocalStringDeleteButton NSLocalizedStringWithDefaultValue(@"button_delete", nil, [NSBundle mainBundle], @"Delete", @"General delete action")

#define kSMLocalStringOKButton NSLocalizedStringWithDefaultValue(@"button_ok", nil, [NSBundle mainBundle], @"OK", @"General OK button label")

#define kSMLocalStringYESButton NSLocalizedStringWithDefaultValue(@"button_yes", nil, [NSBundle mainBundle], @"YES", @"General YES button label")

#define kSMLocalStringConfirmButton NSLocalizedStringWithDefaultValue(@"button_confirm", nil, [NSBundle mainBundle], @"Confirm", @"General Confirm button label")

#define kSMLocalStringSadOKButton NSLocalizedStringWithDefaultValue(@"button_sad-ok", nil, [NSBundle mainBundle], @"OK", @"Used when some error happened and user is presented with message about error but can only close message, since no other action possible")

#define kSMLocalStringViewInTheAppButton NSLocalizedStringWithDefaultValue(@"button_view-in-the-app", nil, [NSBundle mainBundle], @"View in the app", @"In this context this is shown outside the app and this action should bring user back to app")

#define kSMLocalStringGoToAppButton NSLocalizedStringWithDefaultValue(@"button_go-to-app", nil, [NSBundle mainBundle], @"Go to app", @"In this context this is shown outside the app and this action should bring user back to app")

#define kSMLocalStringResetAppButton NSLocalizedStringWithDefaultValue(@"button_reset-app", nil, [NSBundle mainBundle], @"Reset application", @"Reset as verb here")

#define kSMLocalStringShareFileButton NSLocalizedStringWithDefaultValue(@"button_share-file", nil, [NSBundle mainBundle], @"Share a file", @"Share a file")

#define kSMLocalStringShareLocationButton NSLocalizedStringWithDefaultValue(@"button_share-location", nil, [NSBundle mainBundle], @"Share my location", @"Share my location")

#define kSMLocalStringGoToAppstoreButton NSLocalizedStringWithDefaultValue(@"button_go-to-appstore", nil, [NSBundle mainBundle], @"Go to App Store", @"Keep as short as possible")

#define kSMLocalStringDoNotAskAgainButton NSLocalizedStringWithDefaultValue(@"button_do-not-ask-again", nil, [NSBundle mainBundle], @"Do not ask again", @"Keep as short as possible")
#define kSMLocalStringDoNotShowThisAgainButton NSLocalizedStringWithDefaultValue(@"button_do-not-show-this-again", nil, [NSBundle mainBundle], @"Do not show this again", @"Keep as short as possible")

// With arguments

#define kSMLocalStringMissedCallFromLabelArg1 NSLocalizedStringWithDefaultValue(@"label-arg1_missed-call-from", nil, [NSBundle mainBundle], @"Missed call from %@", @"You can change place of '%@' to better match the language of translation, but you should not remove it from string")

#define kSMLocalStringIsCallingYouArg1 NSLocalizedStringWithDefaultValue(@"label-arg1_is-calling-you", nil, [NSBundle mainBundle], @"%@ is calling you", @"You can change place of '%@' to better match the language of translation, but you should not remove it from string")


// Messages

#define kSMLocalStringNoCameraMessageTitle NSLocalizedStringWithDefaultValue(@"message_title_no-camera", nil, [NSBundle mainBundle], @"No Camera", @"There is no camera on device")
#define kSMLocalStringNoCameraMessageBody NSLocalizedStringWithDefaultValue(@"message_body_no-camera", nil, [NSBundle mainBundle], @"Please use a camera enabled device", @"Shown when user's device doesn't have camera or cannot work with it")

#define kSMLocalStringSignInFailedMessageTitle NSLocalizedStringWithDefaultValue(@"message_title_sign-in-failed", nil, [NSBundle mainBundle], @"Sign in failed", @"Sign in failed")
#define kSMLocalStringSignInFailedMessageBodyReasonUnspec NSLocalizedStringWithDefaultValue(@"message_body_sign-in-failed_reason-unspecified", nil, [NSBundle mainBundle], @"Sign in process has failed", @"General message without specifying reason")

#define kSMLocalStringShareFileMessageTitle NSLocalizedStringWithDefaultValue(@"message_title_share-file", nil, [NSBundle mainBundle], @"Share a file", @"Share a file. Shown as a title to some action element like action sheet or alert which then gives user a choice from where to share a file.")

#define kSMLocalStringUserInCallMessageTitle NSLocalizedStringWithDefaultValue(@"message_title_user-in-call", nil, [NSBundle mainBundle], @"User is already in the call", @"User is already in the call")

// iOS Settings

#define kSMLocalStringiOSSettingsSettingsLabel NSLocalizedStringWithDefaultValue(@"label_settings_ios_settings", nil, [NSBundle mainBundle], @"Settings", @"This should be a name as it is shown in system Settings app on iOS")
#define kSMLocalStringiOSSettingsPrivacyLabel NSLocalizedStringWithDefaultValue(@"label_settings_ios_privacy", nil, [NSBundle mainBundle], @"Privacy", @"This should be a name as it is shown in system Settings app on iOS")
#define kSMLocalStringiOSSettingsLocationServicesLabel NSLocalizedStringWithDefaultValue(@"label_settings_ios_location-services", nil, [NSBundle mainBundle], @"Location Services", @"This should be a name as it is shown in system Settings app on iOS")
#define kSMLocalStringiOSSettingsCameraLabel NSLocalizedStringWithDefaultValue(@"label_settings_ios_camera", nil, [NSBundle mainBundle], @"Camera", @"This should be a name as it is shown in system Settings app on iOS")
#define kSMLocalStringiOSSettingsMicrophoneLabel NSLocalizedStringWithDefaultValue(@"label_settings_ios_microphone", nil, [NSBundle mainBundle], @"Microphone", @"This should be a name as it is shown in system Settings app on iOS")

#endif
