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

#import "SMUserView.h"
#import "TableViewCellsParameters.h"


#define kSTUserViewTableViewCellTitleColor        kSMBuddyCellTitleColor
#define kSTUserViewTableViewCellSubtitleColor     kSMBuddyCellSubtitleColor
#define kSTUserViewTableViewCellSelectedColor     kGrayColor_f5f5f5

@interface STUserViewTableViewCell : UITableViewCell <CustomTableViewCellProtocol>

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subTitleLabel;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *iconLabel;

- (void)setupWithTitle:(NSString *)title
              subtitle:(NSString *)subtitle
             iconImage:(UIImage *)iconImage;

- (void)setupWithTitle:(NSString *)title
              subtitle:(NSString *)subtitle
              iconText:(NSString *)iconText
         iconTextColor:(UIColor *)iconTextColor;

- (void)setupWithUserView:(id<SMUserView>)userView;

@end