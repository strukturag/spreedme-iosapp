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

#import "SSLCertificatesListViewController.h"

#import "SMLocalizedStrings.h"
#import "SSLCertificate.h"
#import "SSLCertificateViewController.h"

@interface SSLCertificatesListViewController ()
{
	NSMutableArray *_certificateList;
}

@property (nonatomic, strong) UIBarButtonItem *cancelBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *editBarButtonItem;

@end

@implementation SSLCertificatesListViewController

#pragma mark - Object lifecycle

- (instancetype)initWithCertificateList:(NSArray *)certificates
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _certificateList = [[NSMutableArray alloc] initWithArray:certificates];
		self.title = NSLocalizedStringWithDefaultValue(@"label_ssl_certificate-plural",
													   nil, [NSBundle mainBundle],
													   @"Certificates",
													   @"Certificates");
        self.tableView.rowHeight = 60.0f;
    }
    return self;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.cancelBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.editBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:kSMLocalStringEditButton
                                                              style:UIBarButtonItemStyleBordered
                                                             target:self
                                                             action:@selector(editTableButtonPressed)];
}


- (void)viewWillAppear:(BOOL)animated
{
    [self checkSetupUI];
}


#pragma mark - UI methods

- (void)checkSetupUI
{
    if ([_certificateList count] > 0) {
        if (!self.navigationItem.rightBarButtonItem) {
            self.navigationItem.rightBarButtonItem = _editBarButtonItem;
        }
    } else {
        if (self.editing) {
            [self editTableButtonPressed];
        }
        self.navigationItem.rightBarButtonItem = nil;
    }
}


#pragma mark - Actions

-(void)cancel
{
    if (self.editing) {
        [self editTableButtonPressed];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)editTableButtonPressed
{
    if(self.editing)
    {
        [super setEditing:NO animated:NO];
        [self.tableView setEditing:NO animated:NO];
        [self.tableView reloadData];
        self.navigationItem.rightBarButtonItem.title = kSMLocalStringEditButton;
        self.navigationItem.leftBarButtonItem = nil;
        
    } else {
        
        [super setEditing:YES animated:YES];
        [self.tableView setEditing:YES animated:YES];
        [self.tableView reloadData];
        self.navigationItem.rightBarButtonItem.title = kSMLocalStringDoneButton;
        self.navigationItem.leftBarButtonItem = self.cancelBarButtonItem;
    }
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	SSLCertificate *cert = [_certificateList objectAtIndex:indexPath.row];
	
	SSLCertificateViewController *certVC = [[SSLCertificateViewController alloc] initWithSSLCertificate:cert];
	[self.navigationController pushViewController:certVC animated:YES];
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (UITableViewCellEditingStyle)tableView:(UITableView *)aTableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.editing) {
        return UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleNone;
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.delegate respondsToSelector:@selector(SSLCertificatesListViewController:didRemoveCertificateAtIndex:)];
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if ([self.delegate respondsToSelector:@selector(SSLCertificatesListViewController:didRemoveCertificateAtIndex:)]) {
            [_certificateList removeObjectAtIndex:indexPath.row];
            [self.delegate SSLCertificatesListViewController:self didRemoveCertificateAtIndex:indexPath.row];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
            [self.tableView reloadData];
            [self checkSetupUI];
        }
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [_certificateList count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"reuseIdentifier"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"reuseIdentifier"];
	}
    
	SSLCertificate *cert = [_certificateList objectAtIndex:indexPath.row];
	
    cell.textLabel.text = [cert subjectCommonName];
	cell.detailTextLabel.text = [cert issuer];

    return cell;
}


@end
