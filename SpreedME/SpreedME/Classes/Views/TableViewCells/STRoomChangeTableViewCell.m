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

#import "STRoomChangeTableViewCell.h"

#import "SMLocalizedStrings.h"
#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"


const CGFloat kRoomTextFieldHeight = 40.0f;
const CGFloat kChangeRoomButtonHeight = kRoomTextFieldHeight;
const CGFloat kChangeRoomButtonWidth = kChangeRoomButtonHeight;

@implementation STRoomChangeTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.roomTextField = [[UITextField alloc] initWithFrame:self.contentView.bounds];
        self.roomTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        self.roomTextField.font = [UIFont systemFontOfSize:18];
        self.roomTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.roomTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.roomTextField.returnKeyType = UIReturnKeyGo;
        self.roomTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        [self.contentView addSubview:self.roomTextField];
        
        self.changeRoomButton = [RoundedRectButton buttonWithType:UIButtonTypeCustom];
        self.changeRoomButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        self.changeRoomButton.frame = self.contentView.bounds;
        
        NSString *icon = [NSString stringWithFormat:@"%@", [NSString fontAwesomeIconStringForEnum:FASignIn]];
        NSMutableAttributedString *buttonIcon = [[NSMutableAttributedString alloc] initWithString:icon];
        [buttonIcon addAttribute:NSFontAttributeName value:[UIFont fontWithName:kFontAwesomeFamilyName size:18] range:NSMakeRange(0, 1)];
        [buttonIcon addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0,1)];
        
        [self.changeRoomButton setAttributedTitle:buttonIcon forState:UIControlStateNormal];
        
        [self.changeRoomButton setBackgroundColor:kSMGreenButtonColor forState:UIControlStateNormal];
        [self.changeRoomButton setBackgroundColor:kSMGreenSelectedButtonColor forState:UIControlStateSelected];
        
        self.changeRoomButton.layer.cornerRadius = kViewCornerRadius;
        self.imageView.layer.masksToBounds = YES;
        
        [self.contentView addSubview:self.changeRoomButton];
        
        if ([self respondsToSelector:@selector(setSeparatorInset:)]) {
            self.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
        }
    }
    return self;
}


- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.roomTextField.delegate = nil;
    self.roomTextField.text = nil;
    self.roomTextField.backgroundColor = [UIColor clearColor];
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    
    self.roomTextField.frame = CGRectMake(kTVCellHorizontalEdge,
                                          kTVCellVerticalEdge,
                                          self.contentView.bounds.size.width - kChangeRoomButtonWidth - 2 * kTVCellHorizontalEdge - kTVCellHorizontalGap,
                                          kRoomTextFieldHeight);
    
    self.changeRoomButton.frame = CGRectMake(kTVCellHorizontalEdge + self.roomTextField.frame.size.width + kTVCellHorizontalGap,
                                             kTVCellVerticalEdge,
                                             kChangeRoomButtonWidth,
                                             kChangeRoomButtonHeight);
    
    self.roomTextField.backgroundColor = [UIColor clearColor];
}


#pragma mark - CustomTableViewCellProtocol

+ (NSString *)cellReuseIdentifier
{
    return @"STRoomChangeTableViewCellIdentifier";
}


+ (CGFloat)cellHeight
{
    return kTVCellVerticalEdge + kRoomTextFieldHeight + kTVCellVerticalEdge;
}


#pragma mark - Utils



@end
