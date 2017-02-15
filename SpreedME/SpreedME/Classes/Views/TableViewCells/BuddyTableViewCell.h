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

#import "SMDisplayUser.h"
#import "TableViewCellsParameters.h"

@class User, SMDisplayUser;

@interface BuddyTableViewCell : UITableViewCell <CustomTableViewCellProtocol>

@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *subTitleLabel;
@property (nonatomic, strong) IBOutlet UIImageView *userImageView;
@property (nonatomic, strong) IBOutlet UIView *userStatusContainerView;
@property (nonatomic, strong) IBOutlet UILabel *userStatusLabel;

@property (nonatomic, assign) BOOL shouldShowStatus;

- (void)setupWithTitle:(NSString *)title
			  subtitle:(NSString *)subtitle
				 image:(UIImage *)image
       displayUserType:(SMDisplayUserType)displayUserType
      shouldShowStatus:(BOOL)shouldShowStatus
		  groupedUsers:(NSUInteger)groupedUsers;

- (void)setupWithBuddy:(User *)buddy;
- (void)setupWithDisplayUser:(SMDisplayUser *)displayUser;

@end
