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

#import "BuddyTableViewCell.h"

#import "NSString+FontAwesome.h"
#import "TableViewCellsParameters.h"
#import "User.h"
#import "UIFont+FontAwesome.h"

const CGFloat kUserImageViewWidth = 46.0f;
const CGFloat kUserImageViewHeight = kUserImageViewWidth;

const CGFloat kUserTitleHeight = 21.0f;
const CGFloat kUserSubtitleHeight = kUserTitleHeight;

const CGFloat kUserStatusContainerWidth = kUserTitleHeight;
const CGFloat kUserStatusContainerHeight = kUserStatusContainerWidth;

@implementation BuddyTableViewCell
{
}


- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (self) {
		self.userImageView = [[UIImageView alloc] initWithFrame:CGRectMake(kTVCellHorizontalEdge, kTVCellVerticalEdge, kUserImageViewWidth, kUserImageViewHeight)];
		
		self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.userImageView.frame.origin.x + self.userImageView.frame.size.width + kTVCellHorizontalGap,
																	self.userImageView.frame.origin.y,
																	self.contentView.bounds.size.width - 2 * kTVCellHorizontalEdge - kTVCellHorizontalGap - self.userImageView.frame.size.width,
																	kUserTitleHeight)];
		self.titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        self.titleLabel.textColor = kSMBuddyCellTitleColor;
		
		self.subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.userImageView.frame.origin.x + self.userImageView.frame.size.width + kTVCellHorizontalGap,
																	   self.shouldShowStatus ? self.userStatusContainerView.frame.origin.y + self.userStatusContainerView.frame.size.height + kTVCellVerticalGap :
																	   self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height + kTVCellVerticalGap,
																	   self.contentView.bounds.size.width - 2 * kTVCellHorizontalEdge - kTVCellHorizontalGap - self.userImageView.frame.size.width,
																	   kUserSubtitleHeight)];
		self.subTitleLabel.font = [UIFont systemFontOfSize:13.0f];
		self.subTitleLabel.textColor = kSMBuddyCellSubtitleColor;
		
		self.userStatusContainerView = [[UIView alloc] initWithFrame:CGRectMake(self.userImageView.frame.origin.x + self.userImageView.frame.size.width + kTVCellHorizontalGap,
																				self.userImageView.frame.origin.y,
																				kUserStatusContainerWidth,
																				kUserStatusContainerHeight)];
		
		self.userStatusLabel = [[UILabel alloc] initWithFrame:self.userStatusContainerView.bounds];
		self.userStatusLabel.font = [UIFont fontAwesomeFontOfSize:20.0f];
		self.userStatusLabel.textColor = kSMBuddyCellStatusColor;
		self.userStatusLabel.text = [NSString fontAwesomeIconStringForEnum:FAStarO];
		[self.userStatusContainerView addSubview:self.userStatusLabel];
		
		[self.contentView addSubview:self.userImageView];
		[self.contentView addSubview:self.titleLabel];
		[self.contentView addSubview:self.subTitleLabel];
		[self.contentView addSubview:self.userStatusContainerView];
        
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.subTitleLabel.backgroundColor = [UIColor clearColor];
        self.userStatusLabel.backgroundColor = [UIColor clearColor];
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
        self.contentView.backgroundColor = kGrayColor_f5f5f5;
    }
}


- (void)prepareForReuse
{
	[super prepareForReuse];
	
    self.titleLabel.text = nil;
    self.subTitleLabel.text = nil;
    self.userImageView.image = nil;
    self.userStatusLabel.text = nil;
	
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.subTitleLabel.backgroundColor = [UIColor clearColor];
    self.userStatusLabel.backgroundColor = [UIColor clearColor];
}


- (void)layoutSubviews
{
	[super layoutSubviews];
	
	self.userImageView.frame = CGRectMake(kTVCellHorizontalEdge, kTVCellVerticalEdge, kUserImageViewWidth, kUserImageViewHeight);
	
	if (self.shouldShowStatus) {
		self.userStatusContainerView.hidden = NO;
		
		self.userStatusContainerView.frame = CGRectMake(self.userImageView.frame.origin.x + self.userImageView.frame.size.width + kTVCellHorizontalGap,
														self.userImageView.frame.origin.y,
														kUserStatusContainerWidth,
														kUserStatusContainerHeight);
		
		self.titleLabel.frame = CGRectMake(self.userStatusContainerView.frame.origin.x + self.userStatusContainerView.frame.size.width + kTVCellHorizontalGap,
										   self.userImageView.frame.origin.y,
										   self.contentView.bounds.size.width - 2 * kTVCellHorizontalEdge - 2 * kTVCellHorizontalGap - self.userImageView.frame.size.width - self.userStatusContainerView.frame.size.width,
										   kUserTitleHeight);
	} else {
		self.userStatusContainerView.hidden = YES;
		self.titleLabel.frame = CGRectMake(self.userImageView.frame.origin.x + self.userImageView.frame.size.width + kTVCellHorizontalGap,
										   self.userImageView.frame.origin.y,
										   self.contentView.bounds.size.width - 2 * kTVCellHorizontalEdge - kTVCellHorizontalGap - self.userImageView.frame.size.width,
										   kUserTitleHeight);
	}
	
	if ([self.subTitleLabel.text length] > 0) {
		self.subTitleLabel.hidden = NO;
		self.subTitleLabel.frame = CGRectMake(self.userImageView.frame.origin.x + self.userImageView.frame.size.width + kTVCellHorizontalGap,
											  self.shouldShowStatus ? self.userStatusContainerView.frame.origin.y + self.userStatusContainerView.frame.size.height + kTVCellVerticalGap :
																	  self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height + kTVCellVerticalGap,
											  self.contentView.bounds.size.width - 2 * kTVCellHorizontalEdge - kTVCellHorizontalGap - self.userImageView.frame.size.width,
											  kUserSubtitleHeight);
	} else {
		self.subTitleLabel.hidden = YES;
		self.userStatusContainerView.center = CGPointMake(self.userStatusContainerView.center.x, self.contentView.center.y);
		
		self.titleLabel.center = CGPointMake(self.titleLabel.center.x, self.contentView.center.y);
	}
}


+ (NSString *)cellReuseIdentifier
{
    return @"BuddyTableViewCellIdentifier";
}


+ (CGFloat)cellHeight
{
	return kTVCellVerticalEdge + kUserImageViewHeight + kTVCellVerticalEdge;
}


- (void)setupWithTitle:(NSString *)title
			  subtitle:(NSString *)subtitle
				 image:(UIImage *)image
       displayUserType:(SMDisplayUserType)displayUserType
      shouldShowStatus:(BOOL)shouldShowStatus
		  groupedUsers:(NSUInteger)groupedUsers
{
	self.titleLabel.text = title;
	self.subTitleLabel.text = subtitle;
	self.userImageView.image = image;
    
    self.shouldShowStatus = shouldShowStatus;
    
    switch (displayUserType) {
        case kSMDisplayUserTypeRegistered:
            self.userStatusLabel.text = [NSString fontAwesomeIconStringForEnum:FAStarO];
            break;
            
        case kSMDisplayUserTypeAnotherOwnSession:
            self.userStatusLabel.text = [NSString fontAwesomeIconStringForEnum:FADotCircleO];
            break;
        
        case kSMDisplayUserTypeAnonymous:
            self.userStatusLabel.text = nil;
            self.shouldShowStatus = NO;
            break;
            
        default:
            break;
    }
	
	if ([self respondsToSelector:@selector(setSeparatorInset:)]) {
		self.separatorInset = UIEdgeInsetsMake(0.0f, self.userImageView.frame.origin.x + self.userImageView.frame.size.width + kTVCellHorizontalGap, 0.0f, 0.0f);
	}
    
    if (groupedUsers > 1) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.detailTextLabel.text = [NSString stringWithFormat:@"(%lu)", (unsigned long)groupedUsers];
    } else {
        self.accessoryType = UITableViewCellAccessoryNone;
        self.detailTextLabel.text = nil;
    }
}


- (void)setupWithBuddy:(User *)buddy
{
	[self setupWithTitle:buddy.displayName
				subtitle:buddy.statusMessage
				   image:buddy.iconImage
         displayUserType:(([buddy.userId length] > 0) ? kSMDisplayUserTypeRegistered : kSMDisplayUserTypeAnonymous)
        shouldShowStatus:NO
			groupedUsers:1];
}


- (void)setupWithDisplayUser:(SMDisplayUser *)displayUser
{
	[self setupWithTitle:displayUser.displayName
				subtitle:displayUser.statusMessage
				   image:displayUser.iconImage
         displayUserType:displayUser.type
        shouldShowStatus:NO
			groupedUsers:displayUser.userSessions.count];
}



@end
