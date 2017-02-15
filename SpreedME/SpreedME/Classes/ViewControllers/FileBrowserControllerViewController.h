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

#import "STFileBrowserViewController.h"

@interface FileBrowserControllerViewController : STFileBrowserViewController

/*
 if recursive==YES and file was not found in current directory
 FileBrowserControllerViewController calls this method in all
 its child FileBrowserControllerViewControllers.
 
 NOTE: at the moment 'recursive' is not implemented
 */
- (void)tryToOpenFileName:(NSString *)fileName recursive:(BOOL)recursive; 


@end
