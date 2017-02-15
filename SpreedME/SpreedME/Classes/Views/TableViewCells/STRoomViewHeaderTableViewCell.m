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

#import "STRoomViewHeaderTableViewCell.h"

#import "NSString+FontAwesome.h"
#import "UIImage+RoundedCorners.h"
#import "TableViewCellsParameters.h"
#import "User.h"
#import "UIFont+FontAwesome.h"

const CGFloat kRVTVCellHorizontalEdge	= 15.0f;
const CGFloat kRVTVCellVerticalEdge		= 10.0f;

const CGFloat kRVTVCellHorizontalGap	= 15.0f;
const CGFloat kRVTVCellVerticalGap		= 1.0f;

const CGFloat kRoomImageViewWidth       = 80.0f;
const CGFloat kRoomImageViewHeight      = kRoomImageViewWidth;

const CGFloat kRoomTitleHeight          = 18.0f;


@implementation STRoomViewHeaderTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.iconImageView = [[UIImageView alloc] initWithFrame:CGRectMake(kRVTVCellHorizontalGap, kRVTVCellVerticalEdge, kRoomImageViewWidth, kRoomImageViewHeight)];
        
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.iconImageView.frame.origin.x + self.iconImageView.frame.size.width + kRVTVCellHorizontalGap,
                                                                    self.iconImageView.frame.origin.y + (self.iconImageView.frame.size.height - kRoomTitleHeight) / 2,
                                                                    self.contentView.bounds.size.width - 2 * kRVTVCellHorizontalGap - kRVTVCellHorizontalGap - self.iconImageView.frame.size.width,
                                                                    kRoomTitleHeight)];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:20.0f];
        self.titleLabel.textColor = kSTUserViewHeaderTableViewCellTitleColor;
        
        [self.contentView addSubview:self.iconImageView];
        [self.contentView addSubview:self.titleLabel];
        
        self.titleLabel.backgroundColor = [UIColor clearColor];
    }
    return self;
}


- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.titleLabel.text = nil;
    self.iconImageView.image = nil;
    
    self.titleLabel.backgroundColor = [UIColor clearColor];
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.iconImageView.frame = CGRectMake(kRVTVCellHorizontalGap, kRVTVCellVerticalEdge, kRoomImageViewWidth, kRoomImageViewHeight);
    
    self.titleLabel.frame = CGRectMake(self.iconImageView.frame.origin.x + self.iconImageView.frame.size.width + kRVTVCellHorizontalGap,
                                       self.iconImageView.frame.origin.y + (self.iconImageView.frame.size.height - kRoomTitleHeight) / 2,
                                       self.contentView.bounds.size.width - 2 * kRVTVCellHorizontalEdge - kRVTVCellHorizontalGap - self.iconImageView.frame.size.width,
                                       kRoomTitleHeight);
}


+ (NSString *)cellReuseIdentifier
{
    return @"UserViewTableViewCellIdentifier";
}


+ (CGFloat)cellHeight
{
    return kRoomImageViewHeight + 2 * kRVTVCellVerticalEdge;
}


- (void)setupWithRoom:(SMRoom *)room
{
    self.titleLabel.text = [room displayName];
    UIImage *groupImage = [UIImage imageNamed:@"group_icon"];
    UIImage *roundedImage = [groupImage roundCornersWithRadius:kViewCornerRadius];
    self.iconImageView.image = roundedImage;
}


@end
