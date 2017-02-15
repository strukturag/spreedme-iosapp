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

#import "PlainTextField.h"

@implementation PlainTextField
{
}

#pragma mark - Overrides

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self setup];
	}
	return self;
}


- (void)setup
{
	super.borderStyle = UITextBorderStyleNone;
	self.layer.cornerRadius = 15.0f;
	self.layer.borderWidth = 1.0f;
	self.layer.borderColor = [UIColor lightGrayColor].CGColor;
	self.layer.shouldRasterize = YES;
	self.layer.rasterizationScale = [UIScreen mainScreen].scale;
	self.layer.masksToBounds = YES;
}


- (void)setBorderStyle:(UITextBorderStyle)borderStyle
{
	return;
}


- (CGRect)editingRectForBounds:(CGRect)bounds
{
	CGRect suRect = [super editingRectForBounds:bounds];
	return [self offsetTextRectForBounds:suRect];
}


- (CGRect)textRectForBounds:(CGRect)bounds
{
	CGRect suRect = [super textRectForBounds:bounds];
	return [self offsetTextRectForBounds:suRect];
}


#pragma mark - Utility methods

- (CGRect)offsetTextRectForBounds:(CGRect)bounds
{
	CGRect rect = bounds;
	
	CGFloat edgeOffset = self.layer.borderWidth + 4.0f;
	
	rect.size.width = bounds.size.width - 2 * edgeOffset;
	rect.origin.x = edgeOffset;
	
	return rect;
}


@end
