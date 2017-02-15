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

#import "STUserViewHeaderTableViewCell.h"

#import "NSString+FontAwesome.h"
#import "TableViewCellsParameters.h"
#import "User.h"
#import "UIFont+FontAwesome.h"

const CGFloat kUVTVCellHorizontalEdge	= 15.0f;
const CGFloat kUVTVCellVerticalEdge		= 10.0f;

const CGFloat kUVTVCellHorizontalGap	= 15.0f;
const CGFloat kUVTVCellVerticalGap		= 1.0f;

const CGFloat kUserImageViewWidth       = 80.0f;
const CGFloat kUserImageViewHeight      = kUserImageViewWidth;

const CGFloat kUserTitleHeight          = 18.0f;
const CGFloat kUserSubtitleHeight       = kUserImageViewHeight - kUserTitleHeight - (2 * kUVTVCellVerticalGap);

const CGFloat kDisclosureLabelHeight    = 14.0f;

@implementation STUserViewHeaderTableViewCell
{
}


- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.iconImageView = [[UIImageView alloc] initWithFrame:CGRectMake(kUVTVCellHorizontalGap, kUVTVCellVerticalEdge, kUserImageViewWidth, kUserImageViewHeight)];
        
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.iconImageView.frame.origin.x + self.iconImageView.frame.size.width + kUVTVCellHorizontalGap,
                                                                    self.iconImageView.frame.origin.y,
                                                                    self.contentView.bounds.size.width - 2 * kUVTVCellHorizontalGap - kUVTVCellHorizontalGap - self.iconImageView.frame.size.width,
                                                                    kUserTitleHeight)];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:20.0f];
        self.titleLabel.textColor = kSTUserViewHeaderTableViewCellTitleColor;
        
        self.subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.iconImageView.frame.origin.x + self.iconImageView.frame.size.width + kUVTVCellHorizontalGap,
                                                                       self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height + kUVTVCellVerticalGap,
                                                                       self.contentView.bounds.size.width - 2 * kUVTVCellHorizontalGap - kUVTVCellHorizontalGap - self.iconImageView.frame.size.width,
                                                                       kUserSubtitleHeight)];
        
        self.discloseIconLabel = [[UILabel alloc] initWithFrame:CGRectMake(kUVTVCellHorizontalGap,
                                                                           self.iconImageView.frame.origin.y + self.iconImageView.frame.size.height + kUVTVCellVerticalEdge,
                                                                           self.contentView.bounds.size.width - 2 * kUVTVCellHorizontalGap - kUVTVCellHorizontalGap,
                                                                           kUserTitleHeight)];
        
        self.subTitleLabel.font = [UIFont systemFontOfSize:14.0f];
        self.subTitleLabel.textColor = kSTUserViewHeaderTableViewCellSubtitleColor ;
        
        self.discloseIconLabel.font = [UIFont fontAwesomeFontOfSize:16.0f];
        self.discloseIconLabel.textColor = kSTUserViewHeaderTableViewCellSubtitleColor;
        self.discloseIconLabel.textAlignment = NSTextAlignmentCenter;
        
        [self.contentView addSubview:self.iconImageView];
        [self.contentView addSubview:self.discloseIconLabel];
        [self.contentView addSubview:self.titleLabel];
        [self.contentView addSubview:self.subTitleLabel];
        
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.subTitleLabel.backgroundColor = [UIColor clearColor];
        self.discloseIconLabel.backgroundColor = [UIColor clearColor];
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
        self.contentView.backgroundColor = [UIColor colorWithRed:0.961 green:0.961 blue:0.961 alpha:1]; /*#f5f5f5*/
    }
}


- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.titleLabel.text = nil;
    self.subTitleLabel.text = nil;
    self.iconImageView.image = nil;
    self.discloseIconLabel.text = nil;
    
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.subTitleLabel.backgroundColor = [UIColor clearColor];
    self.discloseIconLabel.backgroundColor = [UIColor clearColor];
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.iconImageView.frame = CGRectMake(kUVTVCellHorizontalGap, kUVTVCellVerticalEdge, kUserImageViewWidth, kUserImageViewHeight);
    
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
    
    if ([self.discloseIconLabel.text length] > 0) {
        CGFloat discloseLabelOriginY = self.iconImageView.frame.origin.y + (self.iconImageView.frame.size.height - (kDisclosureLabelHeight - kUVTVCellVerticalEdge)) - 2 * kUVTVCellVerticalGap;
        self.discloseIconLabel.hidden = NO;
        self.discloseIconLabel.frame = CGRectMake(kUVTVCellHorizontalGap,
                                                  discloseLabelOriginY,
                                                  self.contentView.bounds.size.width - kUVTVCellHorizontalGap,
                                                  kDisclosureLabelHeight);
    } else {
        self.discloseIconLabel.hidden = YES;
    }
    
    [self updateUserUI];
}


- (void)updateUserUI
{
    CGFloat kUserNameMaxHeight	= kUserImageViewHeight - 3 * kUVTVCellVerticalGap;
    
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.numberOfLines = 0;
    
    self.subTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.subTitleLabel.numberOfLines = 0;
    
    if (self.discloseIconLabel) {
        kUserNameMaxHeight = kUserNameMaxHeight - kDisclosureLabelHeight;
    }
    
    CGFloat maxLabelWidth = self.contentView.bounds.size.width - self.iconImageView.frame.size.width - 3 * kUVTVCellHorizontalGap;
    
    CGSize userNameLabelSize = CGSizeMake(maxLabelWidth,
                                          kUserNameMaxHeight);
    
    CGSize labelSize = [self.titleLabel.text sizeWithFont:self.titleLabel.font
                                                  constrainedToSize:userNameLabelSize
                                                      lineBreakMode:self.titleLabel.lineBreakMode];
    
    self.titleLabel.frame = CGRectMake(self.titleLabel.frame.origin.x,
                                       self.titleLabel.frame.origin.y,
                                       labelSize.width, labelSize.height);
    
    
    CGSize userStatusLabelSize = CGSizeMake(maxLabelWidth,
                                            self.iconImageView.frame.size.height - self.titleLabel.frame.size.height - kUVTVCellVerticalGap);
    
    labelSize = [self.subTitleLabel.text sizeWithFont:self.subTitleLabel.font
                                             constrainedToSize:userStatusLabelSize
                                                 lineBreakMode:self.subTitleLabel.lineBreakMode];
    
    self.subTitleLabel.frame = CGRectMake(self.subTitleLabel.frame.origin.x,
                                          self.subTitleLabel.frame.origin.y ,
                                          labelSize.width,
                                          labelSize.height);
    
    if ([self.subTitleLabel.text length] > 0) {
        // user status message is not empty so align both display name and status message to be centered along image
        
        CGFloat heightOfBothLabels = self.titleLabel.frame.size.height + kUVTVCellVerticalGap + self.subTitleLabel.frame.size.height;
        
        self.titleLabel.frame = CGRectMake(self.titleLabel.frame.origin.x,
                                           self.iconImageView.frame.origin.y + (self.iconImageView.frame.size.height - heightOfBothLabels) / 2.0f,
                                           self.titleLabel.frame.size.width,
                                           self.titleLabel.frame.size.height);
        
        self.subTitleLabel.frame = CGRectMake(self.subTitleLabel.frame.origin.x,
                                              self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height + kUVTVCellVerticalGap,
                                              self.subTitleLabel.frame.size.width,
                                              self.subTitleLabel.frame.size.height);
    } else {
        // user status message is empty so align display name to center of image
        // Set only origin.x first
        self.titleLabel.frame = CGRectMake(self.titleLabel.frame.origin.x,
                                           self.titleLabel.frame.origin.y,
                                           self.titleLabel.frame.size.width,
                                           self.titleLabel.frame.size.height);
        // align y centers coordinte
        self.titleLabel.center = CGPointMake(self.titleLabel.center.x, self.iconImageView.center.y);
    }
    
    [self.titleLabel setNeedsDisplay];
    [self.subTitleLabel setNeedsDisplay];
}


+ (NSString *)cellReuseIdentifier
{
    return @"UserViewTableViewCellIdentifier";
}


+ (CGFloat)cellHeight
{
    return kUserImageViewHeight + 2 * kUVTVCellVerticalEdge;
}


- (void)setupWithTitle:(NSString *)title
              subtitle:(NSString *)subtitle
             iconImage:(UIImage *)iconImage
          userSessions:(NSArray *)userSessions
              userType:(SMUserViewType)userType
             disclosed:(BOOL)yesNo
{
    self.titleLabel.text = title;
    self.subTitleLabel.text = subtitle;
    self.iconImageView.image = iconImage;
    
    self.discloseIconLabel.text = nil;
    self.detailTextLabel.text = nil;
    
    if (userSessions.count > 1) {
        self.discloseIconLabel.text = (yesNo) ? [NSString fontAwesomeIconStringForEnum:FAChevronUp] : [NSString fontAwesomeIconStringForEnum:FAChevronDown];
    }
}


- (void)setupWithUserView:(id<SMUserView>)userView disclosed:(BOOL)yesNo
{
    [self setupWithTitle:[userView displayName]
                subtitle:[userView statusMessage]
               iconImage:[userView iconImage]
            userSessions:[userView userSessions]
                userType:[userView userViewType]
               disclosed:yesNo];
}



@end
