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

#import "PopUpListView.h"

#import "RoundedNumberView.h"


@interface PopUpListView () <UITableViewDataSource, UITableViewDelegate>
{
	UITableView *_tableView;
}

@end


@implementation PopUpListView


#pragma mark - SuperClass overrides

- (void)setupWithFrame:(CGRect)frame
{
	[super setupWithFrame:frame];
	
	_tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 1.0f, 1.0f) style:UITableViewStylePlain];
	_tableView.backgroundColor = [UIColor clearColor];
	_tableView.delegate = self;
	_tableView.dataSource = self;
	_tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	
	[self.contentView addSubview:_tableView];
}


- (void)setupContentView
{
	[super setupContentView];
	
	_tableView.frame = self.contentView.bounds;
}


- (void)reload
{
	[self setupContentView];
	[_tableView reloadData];
}


#pragma mark - UITableViewDatasource and Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.delegate listItemsCountInPopUpListView:self];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"PopUpListViewCellIdentifier";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	
	cell.textLabel.attributedText = [self.delegate optionNameInPopUpListView:self forIndex:indexPath.row];
	cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
	cell.textLabel.font = [UIFont systemFontOfSize:16.0f];
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.minimumScaleFactor = 0.5f;
	cell.backgroundColor = [UIColor clearColor];
	cell.contentView.backgroundColor = [UIColor clearColor];
	cell.textLabel.backgroundColor = [UIColor clearColor];
    
    [self setBadgeNumber:[self.delegate badgeNumberInPopUpListView:self forIndex:indexPath.row] forCell:cell];
    
    // Remove seperator inset
    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        [cell setSeparatorInset:UIEdgeInsetsZero];
    }
    
    // Prevent the cell from inheriting the Table View's margin settings
    if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)]) {
        [cell setPreservesSuperviewLayoutMargins:NO];
    }
    
    // Explictly set your cell's layout margins
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.delegate didSelectOptionInPopUpListView:self atIndex:indexPath.row];
}


#pragma mark -

+ (instancetype)popupViewInView:(UIView *)containerView withContentSize:(CGSize)contentSize toPoint:(CGPoint)point forceUp:(BOOL)forceUp withDelegate:(id<PopUpListViewDelegate>)delegate
{
	PopUpListView *popup = [super popupViewInView:containerView withContentSize:contentSize toPoint:point forceUp:forceUp];
	if (popup) {
		popup.delegate = delegate;
	}
	return popup;
}


#pragma mark - Cell setup

- (void)setBadgeNumber:(NSInteger)badgeNumber forCell:(UITableViewCell *)cell
{
    RoundedNumberView *unreadChatsView = [[RoundedNumberView alloc]init];
    
    unreadChatsView.number = badgeNumber;
    cell.accessoryView = unreadChatsView;
    
    if (badgeNumber > 0) {
        cell.accessoryView.hidden = NO;
    } else {
        cell.accessoryView = nil;
    }
}


@end
