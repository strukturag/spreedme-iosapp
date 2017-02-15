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

#import "SMInitialNotificationViewController.h"

#import "RoundedRectButton.h"
#import "SMConnectionController.h"
#import "SMLocalizedStrings.h"
#import "UserInterfaceManager.h"

@interface SMInitialNotificationViewController ()

@property (nonatomic, strong) IBOutlet RoundedRectButton *acceptNotificationButton;
@property (nonatomic, strong) IBOutlet RoundedRectButton *rejectNotificationButton;
@property (nonatomic, strong) IBOutlet UILabel *notificationInfoLinkLabel;

- (IBAction)acceptNotificationButtonPressed:(id)sender;
- (IBAction)rejectNotificationButtonPressed:(id)sender;

@end

@implementation SMInitialNotificationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _notificationInfoLinkLabel.text = NSLocalizedStringWithDefaultValue(@"label_intial-notification-screen_spreedbox-link",
                                                                        nil, [NSBundle mainBundle],
                                                                        @"I want to know more about the Spreedbox",
                                                                        @"Link for information about the Spreedbox.");
    
    NSString *acceptNotificationButtonText = NSLocalizedStringWithDefaultValue(@"button_intial-notification-screen_use-spreedbox",
                                                                               nil, [NSBundle mainBundle],
                                                                               @"Use Spreedbox",
                                                                               @"Button to accept the use of a spreedbox.");
    
    NSString *rejectNotificationButtonText = NSLocalizedStringWithDefaultValue(@"button_intial-notification-screen_use-spreedme",
                                                                               nil, [NSBundle mainBundle],
                                                                               @"Use Spreed.ME service",
                                                                               @"Button to accept the use of the Spreed.ME service.");
    
    _notificationInfoLinkLabel.textColor = kSMLoginScreenLinkColor;
    _notificationInfoLinkLabel.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGestureToReset = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnNotificationInfoLink:)];
    [_notificationInfoLinkLabel addGestureRecognizer:tapGestureToReset];
    
    [_acceptNotificationButton setCornerRadius:kViewCornerRadius];
    [_acceptNotificationButton setBackgroundColor:kSMGreenButtonColor forState:UIControlStateNormal];
    [_acceptNotificationButton setBackgroundColor:kSMGreenSelectedButtonColor forState:UIControlStateSelected];
    [_acceptNotificationButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_acceptNotificationButton setTitle:acceptNotificationButtonText forState:UIControlStateNormal];
    
    [_rejectNotificationButton setCornerRadius:kViewCornerRadius];
    [_rejectNotificationButton setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
    [_rejectNotificationButton setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
    [_rejectNotificationButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_rejectNotificationButton setTitle:rejectNotificationButtonText forState:UIControlStateNormal];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
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

- (IBAction)acceptNotificationButtonPressed:(id)sender
{
    [SMConnectionController sharedInstance].spreedMeMode = NO;
    [[UserInterfaceManager sharedInstance] dismissSpreedboxNotificationWithAcceptance:YES];
}


- (IBAction)rejectNotificationButtonPressed:(id)sender
{
    [SMConnectionController sharedInstance].spreedMeMode = YES;
    [[UserInterfaceManager sharedInstance] dismissSpreedboxNotificationWithAcceptance:NO];
}

- (void)tapOnNotificationInfoLink:(UITapGestureRecognizer *)tapGesture
{
    if (tapGesture.state == UIGestureRecognizerStateEnded)
    {
        NSString *url = [NSString stringWithFormat: @"https://www.spreed.me/spreedbox/"];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    }
}

@end
