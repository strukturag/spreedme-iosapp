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

#import "FrameView.h"

@interface FrameView ()
{
	CGFloat _frameWidth;
	UIColor *_backColor;
}
@end


@implementation FrameView

- (instancetype)initWithFrame:(CGRect)frame
{
	return [self initWithFrame:frame andFrameWidth:0.0f];
}


- (instancetype)initWithFrame:(CGRect)frame andFrameWidth:(CGFloat)frameWidth
{
    self = [super initWithFrame:frame];
    if (self) {
		self.contentMode = UIViewContentModeRedraw;
		self.opaque = NO;
		self.clearsContextBeforeDrawing = YES;
		self.layer.opaque = NO;
		self.layer.backgroundColor = [UIColor clearColor].CGColor;
        _frameWidth = frameWidth;
	}
    return self;
}


// SetBackgroundColor has to be overridden, otherwise inner rect will be drawn black,
// This has something to do with layer drawing and UIVIew's setBackgroundColor implementation.
// https://stackoverflow.com/questions/1551277/uiview-subclass-draws-background-despite-completely-empty-drawrect-why
- (void)setBackgroundColor:(UIColor *)backgroundColor
{
	_backColor = backgroundColor;
}


- (void)setInnerRadius:(CGFloat)innerRadius
{
	if (_innerRadius != innerRadius) {
		_innerRadius = innerRadius;
		
		[self setNeedsDisplay];
	}
}


- (void)drawRect:(CGRect)rect
{	
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	CGContextSaveGState(context);
	
	CGContextSetBlendMode(context, kCGBlendModeCopy);
	
    CGContextSetFillColorWithColor(context, _backColor.CGColor);
    CGContextFillRect(context, rect);
	
	CGRect holeRect = CGRectMake(_frameWidth, _frameWidth, self.frame.size.width - _frameWidth * 2.0f, self.frame.size.height - _frameWidth * 2.0f);
	
	UIColor *clearColor = [[UIColor whiteColor] colorWithAlphaComponent:0.0f];
	CGContextSetFillColorWithColor(context, clearColor.CGColor);
	
	if (_innerRadius < 0.3) {
		CGContextFillRect(context, holeRect);
	} else {
		UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:holeRect cornerRadius:_innerRadius];
		CGContextAddPath(context, roundedRect.CGPath);
		CGContextFillPath(context);
	}
	
	
	
	CGContextRestoreGState(context);
}


@end
