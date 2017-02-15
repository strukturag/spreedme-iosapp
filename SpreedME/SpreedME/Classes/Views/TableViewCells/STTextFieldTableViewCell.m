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

#import "STTextFieldTableViewCell.h"


const CGFloat kTextFieldHeight = 40.0f;


@implementation STTextFieldTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.cellTextField = [[UITextField alloc] initWithFrame:self.contentView.bounds];
        self.cellTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        self.cellTextField.font = [UIFont systemFontOfSize:18];
        self.cellTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.cellTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.cellTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        [self.contentView addSubview:self.cellTextField];
        
        if ([self respondsToSelector:@selector(setSeparatorInset:)]) {
            self.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
        }
    }
    return self;
}


- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.cellTextField.delegate = nil;
    self.cellTextField.text = nil;
    self.cellTextField.backgroundColor = [UIColor clearColor];
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    
    self.cellTextField.frame = CGRectMake(kTVCellHorizontalEdge,
                                          kTVCellVerticalEdge,
                                          self.contentView.bounds.size.width - 2 * kTVCellHorizontalEdge,
                                          kTextFieldHeight);
    
    self.cellTextField.backgroundColor = [UIColor clearColor];
}


#pragma mark - CustomTableViewCellProtocol

+ (NSString *)cellReuseIdentifier
{
    return @"STTextFieldTableViewCellIdentifier";
}


+ (CGFloat)cellHeight
{
    return kTVCellVerticalEdge + kTextFieldHeight + kTVCellVerticalEdge;
}


#pragma mark - Utils



@end
