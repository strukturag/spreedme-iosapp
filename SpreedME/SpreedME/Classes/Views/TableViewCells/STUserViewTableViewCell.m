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

#import "STUserViewTableViewCell.h"

#import "NSString+FontAwesome.h"
#import "TableViewCellsParameters.h"
#import "User.h"
#import "UIFont+FontAwesome.h"

const CGFloat kUVTVCellHorizontalEdge	= 15.0f;
const CGFloat kUVTVCellVerticalEdge		= 5.0f;

const CGFloat kUVTVCellHorizontalGap	= 15.0f;
const CGFloat kUVTVCellVerticalGap		= 1.0f;

const CGFloat kUserImageViewWidth       = 30.0f;
const CGFloat kUserImageViewHeight      = kUserImageViewWidth;

const CGFloat kUserTitleHeight          = 18.0f;
const CGFloat kUserSubtitleHeight       = kUserImageViewHeight - kUserTitleHeight - (2 * kUVTVCellVerticalGap);

@implementation STUserViewTableViewCell
{
}


- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.iconImageView = [[UIImageView alloc] initWithFrame:CGRectMake(kUVTVCellHorizontalGap, kUVTVCellVerticalEdge, kUserImageViewWidth, kUserImageViewHeight)];
        self.iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(kUVTVCellHorizontalGap, kUVTVCellVerticalEdge, kUserImageViewWidth, kUserImageViewHeight)];
        
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.iconImageView.frame.origin.x + self.iconImageView.frame.size.width + kUVTVCellHorizontalGap,
                                                                    self.iconImageView.frame.origin.y,
                                                                    self.contentView.bounds.size.width - 2 * kUVTVCellHorizontalGap - kUVTVCellHorizontalGap - self.iconImageView.frame.size.width,
                                                                    kUserTitleHeight)];
        self.titleLabel.font = [UIFont systemFontOfSize:16.0f];
        self.titleLabel.textColor = kSTUserViewTableViewCellTitleColor;
        
        self.subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.iconImageView.frame.origin.x + self.iconImageView.frame.size.width + kUVTVCellHorizontalGap,
                                                                       self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height + kUVTVCellVerticalGap,
                                                                       self.contentView.bounds.size.width - 2 * kUVTVCellHorizontalGap - kUVTVCellHorizontalGap - self.iconImageView.frame.size.width,
                                                                       kUserSubtitleHeight)];
        self.subTitleLabel.font = [UIFont systemFontOfSize:9.0f];
        self.subTitleLabel.textColor = kSTUserViewTableViewCellSubtitleColor;
        
        self.iconLabel.font = [UIFont fontAwesomeFontOfSize:28.0f];
        self.iconLabel.textColor = [UIColor darkGrayColor];
        self.iconLabel.textAlignment = NSTextAlignmentCenter;
        
        [self.contentView addSubview:self.iconImageView];
        [self.contentView addSubview:self.iconLabel];
        [self.contentView addSubview:self.titleLabel];
        [self.contentView addSubview:self.subTitleLabel];
        
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.subTitleLabel.backgroundColor = [UIColor clearColor];
        self.iconLabel.backgroundColor = [UIColor clearColor];
    }
    return self;
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    return;
    
    if (!selected) {
        self.contentView.backgroundColor = [UIColor whiteColor];
    }
    else {
        self.contentView.backgroundColor = kSTUserViewTableViewCellSelectedColor;
    }
}


- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.titleLabel.text = nil;
    self.subTitleLabel.text = nil;
    self.iconImageView.image = nil;
    self.iconLabel.text = nil;
    
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.subTitleLabel.backgroundColor = [UIColor clearColor];
    self.iconLabel.backgroundColor = [UIColor clearColor];
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if ([self.iconLabel.text length] > 0) {
        self.iconImageView.hidden = YES;
        self.iconLabel.hidden = NO;
        self.iconLabel.frame = CGRectMake(kUVTVCellHorizontalEdge, kUVTVCellVerticalEdge, kUserImageViewWidth, kUserImageViewHeight);
    } else {
        self.iconImageView.hidden = NO;
        self.iconLabel.hidden = YES;
        self.iconImageView.frame = CGRectMake(kUVTVCellHorizontalEdge, kUVTVCellVerticalEdge, kUserImageViewWidth, kUserImageViewHeight);
    }
    
    self.titleLabel.frame = CGRectMake(self.iconImageView.frame.origin.x + self.iconImageView.frame.size.width + kUVTVCellHorizontalGap,
                                       self.iconImageView.frame.origin.y,
                                       self.contentView.bounds.size.width - 2 * kUVTVCellHorizontalEdge - kUVTVCellHorizontalGap - self.iconImageView.frame.size.width,
                                       kUserTitleHeight);
    
    if ([self.subTitleLabel.text length] > 0) {
        self.subTitleLabel.hidden = NO;
        self.subTitleLabel.frame = CGRectMake(self.iconImageView.frame.origin.x + self.iconImageView.frame.size.width + kUVTVCellHorizontalGap,
                                              self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height + kUVTVCellVerticalGap,
                                              self.contentView.bounds.size.width - 2 * kUVTVCellHorizontalGap - kUVTVCellHorizontalGap - self.iconImageView.frame.size.width,
                                              kUserSubtitleHeight);
    } else {
        self.subTitleLabel.hidden = YES;        
        self.titleLabel.center = CGPointMake(self.titleLabel.center.x, self.contentView.center.y);
    }
}


+ (NSString *)cellReuseIdentifier
{
    return @"UserViewTableViewCellIdentifier";
}


+ (CGFloat)cellHeight
{
    return kUVTVCellVerticalEdge + kUserImageViewHeight + kUVTVCellVerticalEdge;
}


- (void)setupWithTitle:(NSString *)title
              subtitle:(NSString *)subtitle
             iconImage:(UIImage *)iconImage
{
    self.titleLabel.text = title;
    self.subTitleLabel.text = subtitle;
    self.iconImageView.image = iconImage;
    self.iconLabel.text = nil;
}


- (void)setupWithTitle:(NSString *)title
              subtitle:(NSString *)subtitle
              iconText:(NSString *)iconText
         iconTextColor:(UIColor *)iconTextColor
{
    self.titleLabel.text = title;
    self.subTitleLabel.text = subtitle;
    self.iconImageView.image = nil;
    self.iconLabel.text = iconText;
    self.iconLabel.textColor = iconTextColor;
}


- (void)setupWithUserView:(id<SMUserView>)userView
{
    [self setupWithTitle:[userView displayName]
                subtitle:[userView statusMessage]
               iconImage:[userView iconImage]];
}



@end
