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

#import "TextFieldTableViewCell.h"

#import <QuartzCore/QuartzCore.h>


const CGFloat kTitleHeight = 30.0f;


@interface TextFieldTableViewCell ()
@property (nonatomic, assign) CGFloat rightAlignmentMargin;
@end

@implementation TextFieldTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        
		self.rightAlignmentMargin = 0.4;
		
		self.textLabel.adjustsFontSizeToFitWidth = YES;
		self.textLabel.backgroundColor = [UIColor clearColor];
		self.textField = [[UITextField alloc] initWithFrame:self.contentView.bounds];
		self.textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		self.textField.backgroundColor = [UIColor clearColor];
		[self.contentView addSubview:self.textField];
		
		if ([self respondsToSelector:@selector(setSeparatorInset:)]) {
			self.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
		}
    }
    return self;
}


- (void)prepareForReuse
{
	[super prepareForReuse];
	
	self.textLabel.backgroundColor = [UIColor clearColor];
	
	self.textField.delegate = nil;
    self.textField.text = nil;
	self.textField.backgroundColor = [UIColor clearColor];
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
	
	self.textField.frame = CGRectMake(floorf(self.contentView.bounds.size.width * _rightAlignmentMargin),
									  self.textLabel.frame.origin.y,
									  self.contentView.bounds.size.width - floorf(self.contentView.bounds.size.width * _rightAlignmentMargin) - kTVCellHorizontalEdge,
									  kTitleHeight);
	
	self.textField.backgroundColor = [UIColor clearColor]; // Without this line background of textfield in iOS6 is white
}


#pragma mark - CustomTableViewCellProtocol

+ (NSString *)cellReuseIdentifier
{
    return @"TextFieldTableViewCellIdentifier";
}


+ (CGFloat)cellHeight
{
	return kTVCellVerticalEdge + kTitleHeight + kTVCellVerticalEdge;
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
