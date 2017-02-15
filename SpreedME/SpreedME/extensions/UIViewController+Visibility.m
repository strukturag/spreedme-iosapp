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

#import "UIViewController+Visibility.h"

@implementation UIViewController (Visibility)

+ (UIViewController *)topViewController
{
	UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
	
	return [rootViewController topVisibleViewController];
}


- (UIViewController *)topVisibleViewController
{
	if ([self isKindOfClass:[UITabBarController class]])
	{
		UITabBarController *tabBarController = (UITabBarController *)self;
		return [tabBarController.selectedViewController topVisibleViewController];
	}
	else if ([self isKindOfClass:[UINavigationController class]])
	{
		UINavigationController *navigationController = (UINavigationController *)self;
		return [navigationController.visibleViewController topVisibleViewController];
	}
	else if (self.presentedViewController)
	{
		return [self.presentedViewController topVisibleViewController];
	}
	else if (self.childViewControllers.count > 0)
	{
		return [self.childViewControllers.lastObject topVisibleViewController];
	}
	
	return self;
}


@end
