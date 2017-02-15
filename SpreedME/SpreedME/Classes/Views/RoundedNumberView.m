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

#import "RoundedNumberView.h"

#define kRoundedNumberViewDefaultBackgroundColor    [UIColor lightGrayColor]
#define kRoundedNumberViewDefaultTextColor          [UIColor whiteColor]

@interface RoundedNumberView ()
@property (nonatomic, strong) UILabel *numberLabel;
@end

@implementation RoundedNumberView
{
    
    
}

- (id)initWithFrame:(CGRect)frame
{
    return [self initWithNumber:0];
}


- (id)init
{
    return [self initWithNumber:0];
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _number = 0;
        [self addNecessaryViews];
        [self setup];
    }
    return self;
}


- (id)initWithNumber:(NSInteger)number
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, 1.0f, 1.0f)];
    if (self) {
        _number = 0;
        [self addNecessaryViews];
        [self setup];
    }
    return self;
}


// This method should be called only once
- (void)addNecessaryViews
{
    self.backgroundColor = kRoundedNumberViewDefaultBackgroundColor;
    self.numberLabel = [[UILabel alloc] init];
    self.numberLabel.backgroundColor = [UIColor clearColor];
    _numberColor = kRoundedNumberViewDefaultTextColor;
    [self addSubview:self.numberLabel];
}


- (void)setup
{
    NSInteger counter = _number;
    self.numberLabel.textColor = _numberColor;
    self.numberLabel.text = [NSString stringWithFormat:@"%d", counter];
    [self.numberLabel sizeToFit];
    self.frame = CGRectMake(0, 0,
                            (self.numberLabel.frame.size.width + (self.frame.size.height / 2) < self.numberLabel.frame.size.height) ? self.numberLabel.frame.size.height : self.numberLabel.frame.size.width + (self.frame.size.height / 2),
                            self.numberLabel.frame.size.height);
    self.layer.cornerRadius = self.numberLabel.frame.size.height / 2;
    [self.numberLabel setCenter:CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2)];
}


- (void)setNumber:(NSInteger)number
{
	if (_number != number) {
		_number = number;
        [self setup];
	}
}


- (void)setNumberColor:(UIColor *)numberColor
{
    if (_numberColor != numberColor) {
        _numberColor = numberColor;
        self.numberLabel.textColor = _numberColor;
    }
}

@end
