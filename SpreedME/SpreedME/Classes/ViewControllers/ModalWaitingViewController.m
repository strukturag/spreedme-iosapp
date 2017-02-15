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

#import "ModalWaitingViewController.h"

#import "OutlinedLabel.h"
#import "SMLocalizedStrings.h"

@interface ModalWaitingViewController ()
{
	BOOL _isAbleToCancel;
}

@property (nonatomic, strong) IBOutlet OutlinedLabel *textLabel;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) IBOutlet UIButton *cancelButton;

- (IBAction)cancelButtonPressed:(id)sender;

@end


@implementation ModalWaitingViewController

#pragma mark - Object lifecycle

- (instancetype)initWithCancelPossibility:(BOOL)isAbleToCancel modalTransitionStyle:(UIModalTransitionStyle)modalTransitionStyle
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _isAbleToCancel = isAbleToCancel;
		self.modalPresentationStyle = UIModalPresentationFullScreen;
		self.modalTransitionStyle = modalTransitionStyle;
    }
    return self;
}


- (instancetype)initWithCancelPossibility:(BOOL)isAbleToCancel
{
	return [self initWithCancelPossibility:isAbleToCancel modalTransitionStyle:UIModalTransitionStyleCrossDissolve];
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	
    self.activityIndicator.color = kSMActivityIndicatorColor;
    self.view.backgroundColor = [[UIColor alloc] initWithPatternImage:[UIImage imageNamed:@"bg-tiles.png"]];
    self.textLabel.outlineColor = [UIColor darkGrayColor];
	self.textLabel.text = kSMLocalStringPleaseWaitLabel;
    
	[self.activityIndicator startAnimating];
	
	[self.cancelButton setTitle:kSMLocalStringCancelButton
					   forState:UIControlStateNormal];
	
	if (!_isAbleToCancel) {
		self.cancelButton.hidden = YES;
	}
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


#pragma mark - Actions

- (void)cancelWaiting
{
	if (_isAbleToCancel && [self.delegate respondsToSelector:@selector(modalWaitingViewControllerDidCancel:)]) {
		[self.delegate modalWaitingViewControllerDidCancel:self];
	}
}


#pragma mark - UI Actions

- (void)cancelButtonPressed:(id)sender
{
	[self cancelWaiting];
}


@end
