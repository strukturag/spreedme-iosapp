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

#import "STChatViewController.h"


#define kSTChatGeneralTVCLeftTintColor      kGrayColor_e5e5e5
#define kSTChatGeneralTVCRightTintColor     kGreenSpreedStyleColor


extern const CGFloat kSTChatCellAvatarImageHeight;
extern const CGFloat kSTChatCellAvatarImageWidth;
extern const CGFloat kSTChatCellVerticalEdge;
extern const CGFloat kSTChatCellVerticalGap;
extern const CGFloat kSTChatCellHorisontalEdge;
extern const CGFloat kSTChatCellHorisontalGap;
extern const CGFloat kSTChatCellDeliveryStatusContainerViewHeight;
extern const CGFloat kSTChatCellDeliveryStatusContainerViewWidth;
extern const CGFloat kSTChatCellTimeStampLabelHeight;
extern const CGFloat kSTChatCellBottomEmptySpaceHeight;
extern const CGFloat kSTChatCellWholeHorizontalEdge;


@interface STChatGeneralTableViewCell : UITableViewCell
{
	id<STChatMessage> _message;
}


@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UIView *deliveryStatusContainerView;
@property (nonatomic, strong) UIImageView *deliveryStatusImageView;
@property (nonatomic, strong) UILabel *deliveryStatusLabel;
@property (nonatomic, strong) UILabel *timestampLabel;
@property (nonatomic, strong) UILabel *userNameLabel;

@property (nonatomic, assign) BOOL isLeftAligned;
@property (nonatomic, assign) BOOL top;
@property (nonatomic, assign) BOOL bottom;

@property (nonatomic, strong) UIColor *backgroundTintColor;


- (void)setupCellWithMessage:(id<STChatMessage>)textMessage;

@end
