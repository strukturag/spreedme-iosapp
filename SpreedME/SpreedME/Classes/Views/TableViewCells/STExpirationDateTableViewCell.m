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

#import "STExpirationDateTableViewCell.h"

#import "SMLocalizedStrings.h"
#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"


const CGFloat kDateLabeldHeight = 40.0f;
const CGFloat kChangeDateButtonHeight = kDateLabeldHeight;
const CGFloat kChangeDateButtonWidth = kChangeDateButtonHeight;

@implementation STExpirationDateTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.dateLabel = [[UILabel alloc] initWithFrame:self.contentView.bounds];
        self.dateLabel.font = [UIFont systemFontOfSize:18];
        self.dateLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        [self.contentView addSubview:self.dateLabel];
        
        self.changeDateButton = [RoundedRectButton buttonWithType:UIButtonTypeCustom];
        self.changeDateButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        self.changeDateButton.frame = self.contentView.bounds;
        
        NSString *icon = [NSString stringWithFormat:@"%@", [NSString fontAwesomeIconStringForEnum:FACalendar]];
        NSMutableAttributedString *buttonIcon = [[NSMutableAttributedString alloc] initWithString:icon];
        [buttonIcon addAttribute:NSFontAttributeName value:[UIFont fontWithName:kFontAwesomeFamilyName size:18] range:NSMakeRange(0, 1)];
        [buttonIcon addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0,1)];
        
        [self.changeDateButton setAttributedTitle:buttonIcon forState:UIControlStateNormal];
        
        [self.changeDateButton setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
        [self.changeDateButton setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
        
        self.changeDateButton.layer.cornerRadius = kViewCornerRadius;
        self.imageView.layer.masksToBounds = YES;
        
        [self.contentView addSubview:self.changeDateButton];
        
        if ([self respondsToSelector:@selector(setSeparatorInset:)]) {
            self.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
        }
    }
    return self;
}


- (void)prepareForReuse
{
    [super prepareForReuse];
    self.dateLabel.backgroundColor = [UIColor clearColor];
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    
    self.dateLabel.frame = CGRectMake(kTVCellHorizontalEdge,
                                      kTVCellVerticalEdge,
                                      self.contentView.bounds.size.width - kChangeDateButtonWidth - 2 * kTVCellHorizontalEdge - kTVCellHorizontalGap,
                                      kChangeDateButtonHeight);
    
    self.changeDateButton.frame = CGRectMake(kTVCellHorizontalEdge + self.dateLabel.frame.size.width + kTVCellHorizontalGap,
                                             kTVCellVerticalEdge,
                                             kChangeDateButtonWidth,
                                             kChangeDateButtonHeight);
    
    self.dateLabel.backgroundColor = [UIColor clearColor];
}


#pragma mark - CustomTableViewCellProtocol

+ (NSString *)cellReuseIdentifier
{
    return @"STExpirationDateTableViewCellIdentifier";
}


+ (CGFloat)cellHeight
{
    return kTVCellVerticalEdge + kDateLabeldHeight + kTVCellVerticalEdge;
}


#pragma mark - Utils



@end
