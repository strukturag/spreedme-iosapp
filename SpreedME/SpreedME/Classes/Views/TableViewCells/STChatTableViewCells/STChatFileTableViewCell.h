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

#import "STChatGeneralTableViewCell.h"
#import "STChatViewController.h"
#import "STFontAwesomeRoundedButton.h"


#define kSTChatFileTVCRedButtonColor                kSMRedButtonColor
#define kSTChatFileTVCRedButtonSelectedColor        kSMRedSelectedButtonColor
#define kSTChatFileTVCBlueButtonColor               kSMBlueButtonColor
#define kSTChatFileTVCBlueButtonSelectedColor       kSMBlueSelectedButtonColor


@class STChatFileTableViewCell;

typedef enum STChatFileTableViewCellActionType
{
	kSTChatFileTableViewCellActionTypeStartDownload = 1,
	kSTChatFileTableViewCellActionTypePauseDownload,
	kSTChatFileTableViewCellActionTypeCancelTransfer,
	kSTChatFileTableViewCellActionTypeOpenDownloadedFile,
}
STChatFileTableViewCellActionType;


@protocol STChatFileTableViewCellDelegate <NSObject>
@required
- (void)fileTableViewCell:(STChatFileTableViewCell *)cell actionButtonWasPressedWithAction:(STChatFileTableViewCellActionType)actionType atIndex:(NSInteger)index;
@end



@interface STChatFileTableViewCell : STChatGeneralTableViewCell

//@property (nonatomic, strong, readonly) UIImageView *fileIconImageView;
@property (nonatomic, strong, readonly) UITextView *sharingExplanationTextView;
@property (nonatomic, strong, readonly) UILabel *fileNameLabel;
@property (nonatomic, strong, readonly) UIProgressView *progressView;
@property (nonatomic, strong, readonly) UILabel *fileSizeLabel;
@property (nonatomic, strong, readonly) UIActivityIndicatorView *spinner;
@property (nonatomic, strong, readonly) UIView *wellView;

@property (nonatomic, strong, readonly) STFontAwesomeRoundedButton *fileTransferControlButton;

- (void)setDelegate:(id<STChatFileTableViewCellDelegate>)delegate withCellIndex:(NSInteger)cellIndex;
- (void)clearDelegate;

+ (CGFloat)neededHeightForCellWithFileChatMessage:(id<STFileTransferChatMesage>)message
									   topMessage:(BOOL)isTopMessage
									bottomMessage:(BOOL)isBottomMessage
								restrictedToWidth:(CGFloat)restrictedToWidth;

@end
