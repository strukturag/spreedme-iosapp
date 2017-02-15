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

#import "ConfirmSSLCertificateViewController.h"

@interface ConfirmSSLCertificateViewController ()

@property (nonatomic, strong) IBOutlet UIButton *dontTrustButton;
@property (nonatomic, strong) IBOutlet UIButton *trustButton;

- (IBAction)dontTrustButtonPressed:(id)sender;
- (IBAction)trustButtonPressed:(id)sender;

@end

@implementation ConfirmSSLCertificateViewController

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	
	
	[self.dontTrustButton setTitle:NSLocalizedStringWithDefaultValue(@"button_ssl_do-not-trust",
																	 nil, [NSBundle mainBundle],
																	 @"Do not trust",
																	 @"Do not trust. Please keep as short as possible")
						  forState:UIControlStateNormal];
	
	[self.trustButton setTitle:NSLocalizedStringWithDefaultValue(@"button_ssl_trust-certificate",
																 nil, [NSBundle mainBundle],
																 @"Trust this certificate",
																 @"Trust this certificate. Please keep as short as possible")
						  forState:UIControlStateNormal];
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


#pragma mark - UI Actions

- (IBAction)dontTrustButtonPressed:(id)sender
{
	[self dontTrustCertificate];
}


- (IBAction)trustButtonPressed:(id)sender
{
	[self trustCertificate];
}


#pragma mark - Actions

- (void)trustCertificate
{
	if ([self.delegate respondsToSelector:@selector(userDidAcceptCertificateInSSLCertificateViewController:)]) {
		[self.delegate userDidAcceptCertificateInSSLCertificateViewController:self];
	}
}


- (void)dontTrustCertificate
{
	if ([self.delegate respondsToSelector:@selector(userDidRejectCertificateInSSLCertificateViewController:)]) {
		[self.delegate userDidRejectCertificateInSSLCertificateViewController:self];
	}
}


@end
