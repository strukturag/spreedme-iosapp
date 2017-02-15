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

#import "ChildRotationTabBarController.h"

@interface ChildRotationTabBarController ()

@end

@implementation ChildRotationTabBarController


- (BOOL)shouldAutorotate
{
	BOOL shouldAutorotate = [super shouldAutorotate];
	
	if (self.selectedViewController) {
		shouldAutorotate = [self.selectedViewController shouldAutorotate];
	}
	
    return shouldAutorotate;
}


- (NSUInteger)supportedInterfaceOrientations
{
	NSUInteger supportedInterfaceOrientations = [super supportedInterfaceOrientations];
	
	if (self.selectedViewController) {
		supportedInterfaceOrientations = [self.selectedViewController supportedInterfaceOrientations];
	}
	
    return supportedInterfaceOrientations;
}


@end
