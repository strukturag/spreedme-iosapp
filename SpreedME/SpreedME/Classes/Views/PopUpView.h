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

#import <UIKit/UIKit.h>

typedef enum PopupArrowPosition
{
	kTopArrowPopup = 0,
	kBottomArrowPopup,
    kLeftArrowPopup,
    kRightArrowPopup,
}
PopupArrowPosition;

@interface PopUpView : UIView

@property (nonatomic, assign, readonly) PopupArrowPosition arrowPosition;
@property (nonatomic, strong) UIColor *bubbleColor;
@property (nonatomic, strong, readonly) UIView *contentView;

- (void)setupWithFrame:(CGRect)frame; //method to override in subclasses. Always call super
- (void)setupContentView; //method to override in subclasses. Always call super

+ (instancetype)popupViewInView:(UIView *)containerView
				withContentSize:(CGSize)contentSize
						toPoint:(CGPoint)point // point should be given in coordinate system of containerView
						forceUp:(BOOL)forceUp;

+ (instancetype)popupViewInView:(UIView *)containerView
				withContentSize:(CGSize)contentSize
					   fromRect:(CGRect)rect; // rect should be given in coordinate system of containerView

@end
