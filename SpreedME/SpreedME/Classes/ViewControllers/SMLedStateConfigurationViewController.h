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

#import "SMLEDState.h"

@class SMLedStateConfigurationViewController;
@protocol SMLedStateConfigurationViewControllerDelegate <NSObject>

- (void)ledStateConfigurationViewController:(SMLedStateConfigurationViewController *)ledStateConfigurationVC wantToSaveLEDState:(SMLEDState*)ledState;
- (void)ledStateConfigurationViewController:(SMLedStateConfigurationViewController *)ledStateConfigurationVC wantToPreviewLEDState:(SMLEDState*)ledState;
- (void)ledStateConfigurationViewController:(SMLedStateConfigurationViewController *)ledStateConfigurationVC wantToResetToDefaultLEDState:(SMLEDState*)ledState;

@end



@interface SMLedStateConfigurationViewController : UIViewController

@property (nonatomic, weak) id<SMLedStateConfigurationViewControllerDelegate> delegate;

- (id)initWithLEDState:(SMLEDState *)ledState withImportableLEDStates:(NSArray *)importableLEDStates andDefaultLEDStates:(NSDictionary *)defaultLEDStates;

@end
