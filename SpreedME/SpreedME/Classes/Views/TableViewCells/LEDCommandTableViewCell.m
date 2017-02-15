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

#import "LEDCommandTableViewCell.h"

const CGFloat kTitleHeight = 30.0f;
const CGFloat kImageWidth = 46.0f;
const CGFloat kImageHeight = kImageWidth;


@interface LEDCommandTableViewCell ()
@property (nonatomic, assign) CGFloat rightAlignmentMargin;
@end


@implementation LEDCommandTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.holdTimeLabel = [[UILabel alloc] init];
        self.holdTimeLabel.adjustsFontSizeToFitWidth = YES;
        self.holdTimeLabel.backgroundColor = [UIColor clearColor];
        self.holdTimeLabel.font = [UIFont systemFontOfSize:18];
        self.holdTimeLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:self.holdTimeLabel];
        
        self.fadeTimeLabel = [[UILabel alloc] init];
        self.fadeTimeLabel.adjustsFontSizeToFitWidth = YES;
        self.fadeTimeLabel.backgroundColor = [UIColor clearColor];
        self.fadeTimeLabel.font = [UIFont systemFontOfSize:18];
        self.fadeTimeLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:self.fadeTimeLabel];
        
        if ([self respondsToSelector:@selector(setSeparatorInset:)]) {
            self.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
        }
    }
    return self;
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat maxLabelWidth = (self.contentView.bounds.size.width - (3 * kTVCellHorizontalEdge) - kImageWidth - kTVCellHorizontalGap) / 2;
        
    self.imageView.frame = CGRectMake(kTVCellHorizontalEdge,
                                      kTVCellVerticalEdge,
                                      kImageWidth,
                                      kImageHeight);
    
    self.holdTimeLabel.frame = CGRectMake(kImageWidth + (2 * kTVCellHorizontalEdge),
                                          kTVCellVerticalEdge,
                                          maxLabelWidth,
                                          kTitleHeight);
    
    self.fadeTimeLabel.frame = CGRectMake(kImageWidth + (2 * kTVCellHorizontalEdge) + maxLabelWidth + kTVCellHorizontalGap,
                                          kTVCellVerticalEdge,
                                          maxLabelWidth,
                                          kTitleHeight);
    
    self.holdTimeLabel.center = CGPointMake(self.holdTimeLabel.center.x, self.imageView.center.y);
    self.fadeTimeLabel.center = CGPointMake(self.fadeTimeLabel.center.x, self.imageView.center.y);
}


#pragma mark - CustomTableViewCellProtocol

+ (NSString *)cellReuseIdentifier
{
    return @"LEDCommandTableViewCellIdentifier";
}


+ (CGFloat)cellHeight
{
    return kTVCellVerticalEdge + kImageHeight + kTVCellVerticalEdge;
}


@end
