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

#import "BuddyListViewController.h"

#import "User.h"
#import "UsersManager.h"
#import "BuddyTableViewCell.h"

#import "NSString+FontAwesome.h"
#import "UIFont+FontAwesome.h"

@interface BuddyListViewController () <UITableViewDataSource, UITableViewDelegate, UserUpdatesProtocol>

@property (nonatomic, strong) IBOutlet UITableView *tableView;

@end


@implementation BuddyListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
		[[UsersManager defaultManager] subscribeForUpdates:self];
    }
    return self;
}


- (void)dealloc
{
	[[UsersManager defaultManager] unsubscribeForUpdates:self];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0 && !self.navigationController) {
        // Make an inset for iOS7 status bar
        self.tableView.contentInset = UIEdgeInsetsMake(20.0f, 0.0f, 0.0f, 0.0f);
    }
    
    if (self.navigationLeftBarButtonItem) {
        self.navigationItem.leftBarButtonItem = self.navigationLeftBarButtonItem;
    }
}


#pragma mark - Getters/setters

- (void)setBuddies:(NSArray *)buddies
{
	if (buddies != _buddies) {
		_buddies = buddies;
		[self.tableView reloadData];
	}
}


#pragma mark - Actions

- (void)cancel
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)reloadData
{
	[self.tableView reloadData];
}


#pragma mark - UIViewController Rotation

- (NSUInteger)supportedInterfaceOrientations
{
	NSUInteger supportedInterfaceOrientations = UIInterfaceOrientationMaskAll;
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
		supportedInterfaceOrientations = UIInterfaceOrientationMaskPortrait;
	}
	
	return supportedInterfaceOrientations;
}


#pragma mark - UITableView Datasource and Delegate

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *buddyCellIdentifier;
	if (!buddyCellIdentifier) {
		buddyCellIdentifier = [BuddyTableViewCell cellReuseIdentifier];
	}
    
	BuddyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:buddyCellIdentifier];
	if (!cell) {
		cell = [[BuddyTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:buddyCellIdentifier];
	}
	
	User *buddy = [self.buddies objectAtIndex:indexPath.row];
	
	cell.titleLabel.textColor = [UIColor darkTextColor];
	cell.accessoryType = UITableViewCellAccessoryNone;
	[cell setupWithBuddy:buddy];
	
	if ([self.selectedUserSessionIds containsObject:buddy.sessionId]) {
		cell.titleLabel.textColor = [UIColor redColor];
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
    
	return cell;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.buddies count];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ([self.delegate respondsToSelector:@selector(buddyListViewController:didSelectBuddy:)]) {
		
		User *buddy = [self.buddies objectAtIndex:indexPath.row];
		if (![self.selectedUserSessionIds containsObject:buddy.sessionId]) {
			[self.delegate buddyListViewController:self didSelectBuddy:buddy];
		} else {
			[self.delegate buddyListViewController:self didSelectBuddy:nil];
		}
	}
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 66.0;
}


#pragma mark - UserUpdates Protocol

- (void)userHasBeenUpdated:(User *)user
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		NSArray *visibleCells = [self.tableView indexPathsForVisibleRows];
		for (NSIndexPath *indexPath in visibleCells) {
			
			BuddyTableViewCell *cell = (BuddyTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
			
			User *userForCell = [self.buddies objectAtIndex:indexPath.row];
		
			// We assume here that we don't make copies of users but pass them by reference,
			// so user and userForCell is the same object
			if ([user.sessionId isEqualToString:userForCell.sessionId]) {
				[cell setupWithBuddy:userForCell];
			}
		}
	});
}


@end
