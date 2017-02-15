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

extern const CGFloat kViewCornerRadius;

extern const CGFloat kTableViewHeaderHeight;
extern const CGFloat kTableViewFooterHeight;

extern const CGFloat kInformationTextFontSize;

//// Application colors
#define kSMApplicationBackgroundColor           [UIColor whiteColor]
#define kGreenSpreedStyleColor                  [UIColor colorWithRed:132.0f/255.0f green:184.0f/255.0f blue:25.0f/255.0f alpha:1.0]
#define kSpreedMeBlueColor                      [UIColor colorWithRed:0.0f green:0.733f blue:0.843f alpha:1] /*#00bbd7*/
#define kSpreedMeBlueColorAlpha06               [UIColor colorWithRed:0 green:0.588 blue:0.675 alpha:0.6]; /*#0096ac*/

#define kGrayColor_f5f5f5                       [UIColor colorWithRed:0.961 green:0.961 blue:0.961 alpha:1] /*#f5f5f5*/
#define kGrayColor_f7f7f7                       [UIColor colorWithRed:0.969 green:0.969 blue:0.969 alpha:1] /*#f7f7f7*/
#define kGrayColor_e5e5e5                       [UIColor colorWithRed:0.898 green:0.898 blue:0.898 alpha:1] /*#e5e5e5*/

#define kSMBuddyCellTitleColor                  [UIColor colorWithRed:0.149 green:0.149 blue:0.149 alpha:1] /*#262626*/
#define kSMBuddyCellSubtitleColor               [UIColor grayColor]
#define kSMBuddyCellStatusColor                 [UIColor colorWithRed:0.149 green:0.149 blue:0.149 alpha:1] /*#262626*/

#define kSMGreenButtonColor                     [UIColor colorWithRed:0.361 green:0.722 blue:0.361 alpha:1] /*#5cb85c*/
#define kSMGreenSelectedButtonColor             [UIColor colorWithRed:0.461 green:0.922 blue:0.461 alpha:1]
#define kSMBlueButtonColor                      [UIColor colorWithRed:0.259 green:0.545 blue:0.792 alpha:1] /*#428bca*/
#define kSMBlueButtonColorAlpha08               [UIColor colorWithRed:0.259 green:0.545 blue:0.792 alpha:0.8]
#define kSMBlueSelectedButtonColor              [UIColor colorWithRed:0.137 green:0.29 blue:0.42 alpha:1] /*#234a6b*/
#define kSMRedButtonColor                       [UIColor colorWithRed:0.851 green:0.325 blue:0.31 alpha:1] /*#d9534f*/
#define kSMRedSelectedButtonColor               [UIColor colorWithRed:0.851 green:0.525 blue:0.51 alpha:1]
#define kSMGrayButtonColor                      [UIColor darkGrayColor]

#define kSMBarButtonColor                       [UIColor colorWithRed:0.502 green:0.502 blue:0.502 alpha:1] /*#808080*/
#define kSMBarButtonHighlightedColor            [UIColor colorWithRed:0.871 green:0.871 blue:0.871 alpha:1] /*#dedede*/

#define kSMChatMessageSentStatusColor           [UIColor colorWithRed:0.259 green:0.545 blue:0.792 alpha:1] /*#166ab8*/
#define kSMChatMessageDeliveredStatusColor      [UIColor colorWithRed:0.259 green:0.545 blue:0.792 alpha:1] /*#166ab8*/
#define kSMChatMessageSeenStatusColor           [UIColor colorWithRed:0.075 green:0.486 blue:0.075 alpha:1] /*#137c13*/
#define kSMChatMessageRemoteStatusColor         [UIColor darkGrayColor]
#define kSMChatMessageGroupStatusColor          [UIColor darkGrayColor]

#define kSpreedMeNavigationBarBackgroundColor   [UIColor colorWithRed:0.961 green:0.961 blue:0.961 alpha:1] /*#f5f5f5*/
#define kSpreedMeNavigationBarButtonsColor      [UIColor grayColor]
#define kSpreedMeNavigationBarTitleColor        [UIColor darkGrayColor]

#define kSMTableViewHeaderTextColor             [UIColor colorWithRed:0.427 green:0.427 blue:0.447 alpha:1] /*#6d6d72*/
#define kSMTableViewSeparatorsColor             [UIColor colorWithRed:0.784 green:0.78 blue:0.8 alpha:1] /*#c8c7cc*/

#define kSMActivityIndicatorColor               [UIColor colorWithRed:132.0f/255.0f green:184.0f/255.0f blue:25.0f/255.0f alpha:1.0]

#define kSMProfileUserNameBackgroundColor       [UIColor colorWithRed:0.930 green:0.930 blue:0.930 alpha:1]

#define kSMLoginScreenLinkColor                 [UIColor colorWithRed:0.259 green:0.545 blue:0.792 alpha:1] /*#428bca*/

#define kSMLocalChatMessageBackgroundColor      [UIColor colorWithRed:132.0f/255.0f green:184.0f/255.0f blue:25.0f/255.0f alpha:0.4]
#define kSMRemoteChatMessageBackgroundColor     [UIColor colorWithRed:0.898 green:0.898 blue:0.898 alpha:0.6]


