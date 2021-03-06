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

#import "OutlinedLabel.h"

@implementation OutlinedLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.outlineColor = self.textColor;
    }
    return self;
}


- (void)setOutlineColor:(UIColor *)outlineColor
{
	if (_outlineColor != outlineColor) {
		_outlineColor = outlineColor;
		[self setNeedsDisplay];
	}
}


- (void)drawTextInRect:(CGRect)rect
{	
	CGSize shadowOffset = self.shadowOffset;
	UIColor *textColor = self.textColor;
	
	CGContextRef c = UIGraphicsGetCurrentContext();
	CGContextSetLineWidth(c, 1);
	CGContextSetLineJoin(c, kCGLineJoinRound);
	
	CGContextSetTextDrawingMode(c, kCGTextStroke);
	self.textColor = self.outlineColor;
	[super drawTextInRect:rect];
	
	CGContextSetTextDrawingMode(c, kCGTextFill);
	self.textColor = textColor;
	self.shadowOffset = CGSizeMake(0, 0);
	[super drawTextInRect:rect];
	
	self.shadowOffset = shadowOffset;
}


@end
