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


@class PopUpListView;

@protocol PopUpListViewDelegate <NSObject>
@required
- (NSInteger)listItemsCountInPopUpListView:(PopUpListView *)listView;
- (NSAttributedString *)optionNameInPopUpListView:(PopUpListView *)listView forIndex:(NSInteger)index;
- (NSInteger)badgeNumberInPopUpListView:(PopUpListView *)listView forIndex:(NSInteger)index;

- (void)didSelectOptionInPopUpListView:(PopUpListView *)listView atIndex:(NSInteger)index;

@end


@interface PopUpListView : PopUpView

@property (nonatomic, weak) id<PopUpListViewDelegate> delegate;

- (void)reload;

+ (instancetype)popupViewInView:(UIView *)containerView withContentSize:(CGSize)contentSize toPoint:(CGPoint)point forceUp:(BOOL)forceUp withDelegate:(id<PopUpListViewDelegate>)delegate;

@end
