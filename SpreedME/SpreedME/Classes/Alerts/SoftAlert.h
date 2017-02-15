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

#import "FlyOverAlert.h"


#define kSoftAlertCornerRadius          kViewCornerRadius
#define kSoftAlertBackgroundColor       kGrayColor_f5f5f5


@interface SoftAlert : FlyOverAlert

// All methods with target and selector assume that selector returns void. If selector returns something that can cause a leak.
- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image
					   target:(id)target selector:(SEL)selector;

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image
					   target:(id)target selector:(SEL)selector selectorArgument:(id)selectorArgument;

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image
					   target:(id)target selector:(SEL)selector selectorArgument:(id)selectorArgument1 selectorArgument:(id)selectorArgument2;

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image actionBlock:(void (^)(void))actionBlock;

@end
