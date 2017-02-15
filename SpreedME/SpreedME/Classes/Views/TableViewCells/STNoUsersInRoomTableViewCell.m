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

#import "STNoUsersInRoomTableViewCell.h"

#import "SMLocalizedStrings.h"
#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"


@interface STNoUsersInRoomTableViewCell ()
{
    CGFloat _labelMaxWidth;
}

@end


@implementation STNoUsersInRoomTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _labelMaxWidth = self.contentView.bounds.size.width - 2 * kTVCellHorizontalEdge;
        
        self.noUsersLabel = [[UILabel alloc] initWithFrame:self.contentView.bounds];
        self.noUsersLabel.numberOfLines = 0;
        self.noUsersLabel.font = [UIFont systemFontOfSize:kInformationTextFontSize];
        self.noUsersLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.noUsersLabel.textAlignment = NSTextAlignmentCenter;
        self.noUsersLabel.text = NSLocalizedStringWithDefaultValue(@"label_no-users-in-room",
                                                                   nil, [NSBundle mainBundle],
                                                                   @"No one else in this room",
                                                                   @"No one else in this room");
        self.noUsersLabel.textColor = [UIColor darkGrayColor];
        
        [self.contentView addSubview:self.noUsersLabel];
        
        self.moreInfoLabel = [[UILabel alloc] initWithFrame:self.contentView.bounds];
        self.moreInfoLabel.numberOfLines = 0;
        self.moreInfoLabel.font = [UIFont systemFontOfSize:18];
        self.moreInfoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.moreInfoLabel.textAlignment = NSTextAlignmentCenter;
        self.moreInfoLabel.text = NSLocalizedStringWithDefaultValue(@"label_no-users-more-info",
                                                                    nil, [NSBundle mainBundle],
                                                                    @"Share this room with your friends to meet them here",
                                                                    @"Share this room with your friends to meet them here");
        self.moreInfoLabel.textColor = kSMBuddyCellSubtitleColor;
        
        [self.contentView addSubview:self.moreInfoLabel];
        
        if ([self respondsToSelector:@selector(setSeparatorInset:)]) {
            self.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
        }
    }
    return self;
}


- (void)prepareForReuse
{
    [super prepareForReuse];
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize noUsersLabelSize = [self sizeForLabel:_noUsersLabel];
    CGSize moreInfoLabelSize = [self sizeForLabel:_moreInfoLabel];

    self.noUsersLabel.frame = CGRectMake(kTVCellHorizontalEdge,
                                          kTVCellVerticalEdge,
                                          self.contentView.bounds.size.width - 2 * kTVCellHorizontalEdge,
                                          noUsersLabelSize.height);
    
    self.moreInfoLabel.frame = CGRectMake(kTVCellHorizontalEdge,
                                          self.noUsersLabel.frame.origin.y + self.noUsersLabel.frame.size.height + kTVCellVerticalEdge,
                                          self.contentView.bounds.size.width - 2 * kTVCellHorizontalEdge,
                                          moreInfoLabelSize.height);
    
    self.noUsersLabel.backgroundColor = [UIColor clearColor];
    self.moreInfoLabel.backgroundColor = [UIColor clearColor];
}


- (CGFloat)cellHeight
{
    CGSize noUsersLabelSize = [self sizeForLabel:_noUsersLabel];
    CGSize moreInfoLabelSize = [self sizeForLabel:_moreInfoLabel];
    
    return kTVCellVerticalEdge + noUsersLabelSize.height + kTVCellVerticalEdge + moreInfoLabelSize.height + kTVCellVerticalEdge;
}


- (CGSize)sizeForLabel:(UILabel *)label
{
    return [label sizeThatFits:CGSizeMake(_labelMaxWidth, MAXFLOAT)];
}

@end
