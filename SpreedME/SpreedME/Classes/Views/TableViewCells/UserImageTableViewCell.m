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

#import "UserImageTableViewCell.h"

const CGFloat kTitleHeight = 30.0f;
const CGFloat kImageWidth = 46.0f;
const CGFloat kImageHeight = kImageWidth;


@interface UserImageTableViewCell ()
@property (nonatomic, assign) CGFloat rightAlignmentMargin;
@end


@implementation UserImageTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.rightAlignmentMargin = 0.4;
		self.textLabel.adjustsFontSizeToFitWidth = YES;
		
		if ([self respondsToSelector:@selector(setSeparatorInset:)]) {
			self.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
		}
    }
    return self;
}


- (void)layoutSubviews
{
	[super layoutSubviews];
	
	CGFloat textWidth = [self.textLabel sizeThatFits:CGSizeMake(self.contentView.bounds.size.width, kTitleHeight)].width;
	if (textWidth > (floorf(self.contentView.bounds.size.width * _rightAlignmentMargin) - kTVCellHorizontalGap - kTVCellHorizontalEdge)) {
		textWidth = floorf(self.contentView.bounds.size.width * _rightAlignmentMargin) - kTVCellHorizontalGap - kTVCellHorizontalEdge;
	}
	
	self.textLabel.frame = CGRectMake(kTVCellHorizontalEdge,
									  kTVCellVerticalEdge,
									  textWidth,
									  kTitleHeight);
	
	self.imageView.frame = CGRectMake(floorf(self.contentView.bounds.size.width * _rightAlignmentMargin),
									  kTVCellVerticalEdge,
									  kImageWidth,
									  kImageHeight);
	
	self.textLabel.center = CGPointMake(self.textLabel.center.x, self.imageView.center.y);
}


#pragma mark - CustomTableViewCellProtocol

+ (NSString *)cellReuseIdentifier
{
    return @"UserImageTableViewCellIdentifier";
}


+ (CGFloat)cellHeight
{
	return kTVCellVerticalEdge + kImageHeight + kTVCellVerticalEdge;
}


#pragma mark - AlignedFieldsTableViewCellProtocol

- (void)setRightAlignmentMargin:(CGFloat)rightMargin
{
	if (rightMargin != _rightAlignmentMargin) {
		if (rightMargin > 1.0f || rightMargin < 0.0f) {
			rightMargin = 0.0;
		}
		_rightAlignmentMargin = rightMargin;
		
		[self setNeedsLayout];
	}
}


@end
