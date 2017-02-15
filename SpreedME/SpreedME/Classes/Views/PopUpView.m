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

#import "PopUpView.h"

const CGFloat kArrowDefaultWidth			= 15.0f;
const CGFloat kArrowDefaultHeight			= 12.0f;
CGFloat kPopupRoundedCornerRadius			= 5.0; // !!! this should be the same as kViewCornerRadius;


@interface PopUpView ()

@property (nonatomic, assign) PopupArrowPosition arrowPosition;

@property (nonatomic, assign) CGFloat bubbleWidth;
@property (nonatomic, assign) CGFloat bubbleHeight;
@property (nonatomic, assign) CGFloat bubbleX;
@property (nonatomic, assign) CGFloat bubbleY;

@property (nonatomic, assign) CGFloat arrowWidth;
@property (nonatomic, assign) CGFloat arrowHeight;
@property (nonatomic, assign) CGFloat arrowX;
@property (nonatomic, assign) CGFloat arrowY;

@property (nonatomic, assign) CGSize contentSize;

@end


@implementation PopUpView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupWithFrame:frame];
    }
    return self;
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupWithFrame:CGRectMake(0, 0, 0, 0)];
    }
    return self;
}


- (id)init
{
    self = [self initWithFrame:CGRectMake(0, 0, 0, 0)];
    return self;
}


- (void)setupContentView
{
	_contentView.frame = CGRectMake(kPopupRoundedCornerRadius,
									(_arrowPosition == kTopArrowPopup) ? kPopupRoundedCornerRadius + kArrowDefaultHeight : kPopupRoundedCornerRadius,
									_contentSize.width,
									_contentSize.height);
}


- (void)drawRect:(CGRect)rect
{
    CGContextRef aRef = UIGraphicsGetCurrentContext();
    CGContextSaveGState(aRef);

    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    switch (_arrowPosition) {
        case kTopArrowPopup:
            [bezierPath moveToPoint:CGPointMake(_arrowX, _arrowY)];
            [bezierPath addLineToPoint:CGPointMake(_arrowX - (_arrowWidth/2), _arrowY + kArrowDefaultHeight)];
            [bezierPath addLineToPoint:CGPointMake(_arrowX + (_arrowWidth/2), _arrowY + kArrowDefaultHeight)];
            [bezierPath addLineToPoint:CGPointMake(_arrowX, _arrowY)];
            break;
        case kBottomArrowPopup:
            [bezierPath moveToPoint:CGPointMake(_arrowX, _arrowY)];
            [bezierPath addLineToPoint:CGPointMake(_arrowX - (_arrowWidth/2), _arrowY - kArrowDefaultHeight)];
            [bezierPath addLineToPoint:CGPointMake(_arrowX + (_arrowWidth/2), _arrowY - kArrowDefaultHeight)];
            [bezierPath addLineToPoint:CGPointMake(_arrowX, _arrowY)];
            break;
        case kLeftArrowPopup:
            [bezierPath moveToPoint:CGPointMake(_arrowX, _arrowY)];
            [bezierPath addLineToPoint:CGPointMake(_arrowX + kArrowDefaultHeight, _arrowY - (_arrowWidth/2))];
            [bezierPath addLineToPoint:CGPointMake(_arrowX + kArrowDefaultHeight, _arrowY + (_arrowWidth/2))];
            [bezierPath addLineToPoint:CGPointMake(_arrowX, _arrowY)];
            break;
        case kRightArrowPopup:
            [bezierPath moveToPoint:CGPointMake(_arrowX, _arrowY)];
            [bezierPath addLineToPoint:CGPointMake(_arrowX - kArrowDefaultHeight, _arrowY - (_arrowWidth/2))];
            [bezierPath addLineToPoint:CGPointMake(_arrowX - kArrowDefaultHeight, _arrowY + (_arrowWidth/2))];
            [bezierPath addLineToPoint:CGPointMake(_arrowX, _arrowY)];
            break;
        default:
            break;
    }
    [bezierPath closePath];
    UIColor *fillColor = _bubbleColor; //[UIColor colorWithRed:0.529 green:0.808 blue:0.922 alpha:1]; // color equivalent is #87ceeb
    [fillColor setFill];
    [bezierPath fill];
//    [[UIColor blackColor] setStroke];
//    bezierPath.lineWidth = 1;
//    [bezierPath stroke];
    
    UIBezierPath *roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(_bubbleX, _bubbleY, _bubbleWidth, _bubbleHeight - kArrowDefaultHeight) cornerRadius:kPopupRoundedCornerRadius];
    [roundedRectanglePath fill];
    
    CGContextRestoreGState(aRef);
}


- (void)setupWithFrame:(CGRect)frame
{
	_contentView = [[UIView alloc] init];
	_contentView.backgroundColor = [UIColor clearColor];
	[self addSubview:_contentView];
	
//    _arrowWidth = kArrowDefaultWidth;
//    _arrowHeight = kArrowDefaultHeight;
//    _arrowX = (frame.size.width/2)-(_arrowWidth/2);
//    _arrowY = frame.size.height - _arrowHeight;
//    
//    _bubbleWidth = frame.size.width;
//    _bubbleHeight = frame.size.height - _arrowHeight;
}


#pragma mark - Class creation methods

+ (instancetype)popupViewInView:(UIView *)containerView withContentSize:(CGSize)contentSize toPoint:(CGPoint)point forceUp:(BOOL)forceUp
{
	PopUpView *popupView = [[[self class] alloc] init];
	popupView.contentSize = contentSize;
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
	
	CGFloat maxViewHeight = contentSize.height + kArrowDefaultHeight + (2.0f * kPopupRoundedCornerRadius);
    CGSize containerViewSize = containerView.frame.size; // TODO: Check if container size is not bigger than screensize. I am not sure if really need this though.
    CGRect bubbleViewFrame = CGRectMake(0, 0, contentSize.width + (2 * kPopupRoundedCornerRadius), maxViewHeight);
    CGFloat upperSide = point.y;
    CGFloat leftSide = point.x;
    CGFloat lowerSide = containerViewSize.height - upperSide;
    CGFloat rightSide = containerViewSize.width - leftSide;
    CGFloat minOffset = kPopupRoundedCornerRadius + kArrowDefaultWidth;
    CGFloat bubbleOffset;
    
    if (!SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0") && UIInterfaceOrientationIsLandscape(interfaceOrientation)){
        lowerSide = containerViewSize.width - upperSide;
        rightSide = containerViewSize.height - leftSide;
    }
    
    popupView.arrowWidth = kArrowDefaultWidth;
    popupView.arrowHeight = kArrowDefaultHeight;
    popupView.bubbleWidth = bubbleViewFrame.size.width;
    popupView.bubbleHeight = bubbleViewFrame.size.height;
    
    if (bubbleViewFrame.size.width < containerViewSize.width && bubbleViewFrame.size.height < containerViewSize.height) {
        if (leftSide <= rightSide) {
            
            bubbleOffset = leftSide - ((containerViewSize.width - bubbleViewFrame.size.width) / 2);
            
            if (bubbleViewFrame.size.width <= rightSide) {
                bubbleOffset = bubbleViewFrame.size.width * (leftSide / containerViewSize.width);
            }
            
            if (bubbleOffset < minOffset) {
                bubbleOffset = (leftSide <= minOffset) ? leftSide : bubbleOffset + minOffset;
            }
            
            if (lowerSide <= upperSide || forceUp) {
                if (maxViewHeight <= upperSide) {
                    popupView.arrowPosition = kBottomArrowPopup;
                    bubbleViewFrame = CGRectMake(point.x - bubbleOffset, point.y - maxViewHeight, bubbleViewFrame.size.width, maxViewHeight);
                    popupView.arrowX = bubbleOffset;
                    popupView.arrowY = bubbleViewFrame.size.height;
                    popupView.bubbleX = 0;
                    popupView.bubbleY = 0;
                }
            } else if (upperSide < lowerSide && !forceUp) {
                if (maxViewHeight <= lowerSide) {
                    popupView.arrowPosition = kTopArrowPopup;
                    bubbleViewFrame = CGRectMake(point.x - bubbleOffset, point.y, bubbleViewFrame.size.width, maxViewHeight);
                    popupView.arrowX = bubbleOffset;
                    popupView.arrowY = 0;
                    popupView.bubbleX = 0;
                    popupView.bubbleY = kArrowDefaultHeight;
                }
            } else {
                // Does not fit in the upperSide neither down
//                NSLog(@"Popup does not fit in the upperSide neither down");
            }
			
        } else {
            
			bubbleOffset = rightSide - ((containerViewSize.width - bubbleViewFrame.size.width) / 2);
            
            if (bubbleViewFrame.size.width <= leftSide) {
                bubbleOffset = bubbleViewFrame.size.width * (rightSide / containerViewSize.width);
            }
            
            if (bubbleOffset < minOffset) {
                bubbleOffset = (rightSide <= minOffset) ? rightSide : bubbleOffset + minOffset;
            }
            
            if (lowerSide <= upperSide || forceUp) {
                if (maxViewHeight <= upperSide) {
                    popupView.arrowPosition = kBottomArrowPopup;
                    bubbleViewFrame = CGRectMake(point.x - (bubbleViewFrame.size.width - bubbleOffset), point.y - maxViewHeight, bubbleViewFrame.size.width, maxViewHeight);
                    popupView.arrowX = bubbleViewFrame.size.width - bubbleOffset;
                    popupView.arrowY = bubbleViewFrame.size.height;
                    popupView.bubbleX = 0;
                    popupView.bubbleY = 0;
                }
            } else if (upperSide < lowerSide && !forceUp) {
                if (maxViewHeight <= lowerSide) {
                    popupView.arrowPosition = kTopArrowPopup;
                    bubbleViewFrame = CGRectMake(point.x - (bubbleViewFrame.size.width - bubbleOffset), point.y, bubbleViewFrame.size.width, maxViewHeight);
                    popupView.arrowX = bubbleViewFrame.size.width - bubbleOffset;
                    popupView.arrowY = 0;
                    popupView.bubbleX = 0;
                    popupView.bubbleY = kArrowDefaultHeight;
                }
            } else {
                // Does not fit in the upperSide neither down
//                NSLog(@"Popup does not fit in the upperSide neither down");
            }
        }
    } else {
//        NSLog(@"Cannot create a popup view with the given size in the given position");
        return nil;
    }
    popupView.frame = bubbleViewFrame;
	[popupView setupContentView];
	
    popupView.backgroundColor = [UIColor clearColor];
    return popupView;
}


+ (instancetype)popupViewInView:(UIView *)containerView withContentSize:(CGSize)contentSize fromRect:(CGRect)rect
{
	CGPoint upperPoint = CGPointMake(rect.origin.x + (rect.size.width / 2), rect.origin.y);
    CGPoint lowerPoint = CGPointMake(rect.origin.x + (rect.size.width / 2), rect.origin.y + rect.size.height);
    
    PopUpView *popUpView = [PopUpView popupViewInView:containerView withContentSize:contentSize toPoint:upperPoint forceUp:YES];
    
    if (!popUpView) {
		popUpView = [PopUpView popupViewInView:containerView withContentSize:contentSize toPoint:lowerPoint forceUp:NO];
	}
		
	return popUpView;
}


@end
