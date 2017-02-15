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

#import "SMLoginViewController.h"

#import <SafariServices/SafariServices.h>

#import "ChildRotationNavigationController.h"
#import "ModalWaitingViewController.h"
#import "SpreedMeRoundedButton.h"
#import "SettingsController.h"
#import "SMConnectionController.h"
#import "SMLocalizedStrings.h"
#import "SMWebViewController.h"
#import "UserInterfaceManager.h"

#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"


typedef enum : NSUInteger {
    kSMLoginViewControllerLinkTypeCreateAccount,
    kSMLoginViewControllerLinkTypeResetPassword,
} SMLoginViewControllerLinkType;


@interface SMLoginViewController () <UITextFieldDelegate, UIActionSheetDelegate>
{
    ModalWaitingViewController *_waitingForLoginView;
	NSString *_username;
    
    UIActionSheet *_loginOptionsActionSheet;
    
    SMLoginViewControllerUIState _uiState;
}

@property (nonatomic, strong) IBOutlet UITextField *spreedNameTextField;
@property (nonatomic, strong) IBOutlet UITextField *passwordTextField;
@property (nonatomic, strong) IBOutlet SpreedMeRoundedButton *loginButton;
@property (nonatomic, strong) IBOutlet UILabel *resetPasswordLink;
@property (nonatomic, strong) IBOutlet UILabel *createAccountLink;
@property (nonatomic, strong) IBOutlet UIView *containerView;
@property (nonatomic, strong) IBOutlet UIImageView *loginImageView;
@property (nonatomic, strong) IBOutlet UIImageView *spreedBoxLoginImageView;


@property (nonatomic, strong) IBOutlet UIView *unsupportedAppContainerView;
@property (nonatomic, strong) IBOutlet RoundedRectButton *goToAppStoreButton;
@property (nonatomic, strong) IBOutlet UILabel *unsupportedAppExplanationLabel;

@property (nonatomic, strong) IBOutlet UIButton *loginOptionsButton;


- (IBAction)loginButtonPressed:(id)sender;

- (IBAction)goToAppStoreButtonPressed:(id)sender;

- (IBAction)loginOptionsButtonPressed:(id)sender;

@end


@implementation SMLoginViewController

#pragma mark - Object lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
		UIImageView *image=[[UIImageView alloc]initWithFrame:CGRectMake(0, 0, 107, 30)];
        [image setImage:[UIImage imageNamed:@"spreed_logo.png"]];
        [self.navigationController.navigationBar.topItem setTitleView:image];
        _waitingForLoginView = [[ModalWaitingViewController alloc] initWithCancelPossibility:NO modalTransitionStyle:UIModalTransitionStyleCrossDissolve];
                
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionBecomeActive:) name:ChannelingConnectionBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionBecomeInactive:) name:ChannelingConnectionBecomeInactiveNotification object:nil];
    }
    return self;
}


- (instancetype)initWithUIState:(SMLoginViewControllerUIState)uiState
{
    self = [self initWithNibName:nil bundle:nil];
    if (self) {
        _uiState = uiState;
    }
    
    return self;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
		self.edgesForExtendedLayout = UIRectEdgeNone;
	}
    
    self.containerView.backgroundColor = kGrayColor_f7f7f7;
    self.containerView.layer.shadowOffset = CGSizeMake(0, 2);
    self.containerView.layer.shadowOpacity = 0.3;
    
    self.unsupportedAppContainerView.backgroundColor = kGrayColor_f7f7f7;
    self.unsupportedAppContainerView.layer.shadowOffset = CGSizeMake(0, 2);
    self.unsupportedAppContainerView.layer.shadowOpacity = 0.3;
    
    _spreedNameTextField.delegate = self;
    _passwordTextField.delegate = self;
    
    [self.loginImageView setImage:[UIImage imageNamed: @"signIn_logo.png"]];
    [self.spreedBoxLoginImageView setImage:[UIImage imageNamed: @"spreedbox_logo.png"]];
    
    _loginOptionsButton.titleLabel.font = [UIFont fontWithName:kFontAwesomeFamilyName size:20];
    [_loginOptionsButton setTitle:[NSString fontAwesomeIconStringForEnum:FACaretSquareOUp] forState:UIControlStateNormal];
    [_loginOptionsButton setTitleColor:kSMLoginScreenLinkColor forState:UIControlStateNormal];

    [_spreedNameTextField setFont:[UIFont systemFontOfSize:16]];
    [_spreedNameTextField.layer setBorderColor:[[[UIColor grayColor] colorWithAlphaComponent:0.6] CGColor]];
    [_spreedNameTextField.layer setBorderWidth:1.0];
    _spreedNameTextField.backgroundColor = [UIColor whiteColor];
    _spreedNameTextField.layer.cornerRadius = kViewCornerRadius;
    
    [_passwordTextField setFont:[UIFont systemFontOfSize:16]];
    [_passwordTextField.layer setBorderColor:[[[UIColor grayColor] colorWithAlphaComponent:0.6] CGColor]];
    [_passwordTextField.layer setBorderWidth:1.0];
    _passwordTextField.backgroundColor = [UIColor whiteColor];
    _passwordTextField.layer.cornerRadius = kViewCornerRadius;
	_passwordTextField.placeholder = kSMLocalStringPasswordLabel;
	
	_createAccountLink.text = NSLocalizedStringWithDefaultValue(@"label_login-screen_create-account-prompt-text",
																nil, [NSBundle mainBundle],
																@"Don't have a Spreed Name and password yet?",
																@"Text on login screen, when user taps it he/she is taken to create account screen");
	_resetPasswordLink.text = NSLocalizedStringWithDefaultValue(@"label_login-screen_reset-password-prompt-text",
																nil, [NSBundle mainBundle],
																@"Problems signing in?",
																@"Text on login screen, when user taps it he/she is taken to reset password screen");
	
    _createAccountLink.textColor = kSMLoginScreenLinkColor;
    _resetPasswordLink.textColor = kSMLoginScreenLinkColor;
    
    _createAccountLink.userInteractionEnabled = YES;
    _resetPasswordLink.userInteractionEnabled = YES;
    
    UITapGestureRecognizer *tapGestureToCreate = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnCreateAccountLink:)];
    UITapGestureRecognizer *tapGestureToReset = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnResetPasswordLink:)];
    
    [_createAccountLink addGestureRecognizer:tapGestureToCreate];
    [_resetPasswordLink addGestureRecognizer:tapGestureToReset];
    
    [_loginButton configureButtonWithButtonType:kSpreedMeButtonTypeSignIn];
    _loginButton.enabled = NO;
	
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];
	[self.view addGestureRecognizer:tap];
	
	self.spreedNameTextField.text = _username;
    
    [self.goToAppStoreButton setCornerRadius:kViewCornerRadius];
    [self.goToAppStoreButton setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
    [self.goToAppStoreButton setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
    [self.goToAppStoreButton setTitle:kSMLocalStringGoToAppstoreButton forState:UIControlStateNormal];
    [self.goToAppStoreButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [self updateUI];
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


#pragma mark - UI Methods

- (void)updateUI
{
    if (_uiState == kSMLoginViewControllerUIStateNormal) {
        self.containerView.hidden = NO;
        self.unsupportedAppContainerView.hidden = YES;
        self.createAccountLink.hidden = NO;
        self.resetPasswordLink.hidden = NO;
        self.loginImageView.hidden = NO;
        self.spreedBoxLoginImageView.hidden = YES;
        _spreedNameTextField.placeholder = NSLocalizedStringWithDefaultValue(@"label_your-spreed-name",
                                                                             nil, [NSBundle mainBundle],
                                                                             @"Your Spreed Name",
                                                                             @"Your Spreed Name");
    } else if (_uiState == kSMLoginViewControllerUIStateAppVersionUnsupported) {
        self.unsupportedAppExplanationLabel.text = [SMConnectionController sharedInstance].versionCheckFailedString;
        self.containerView.hidden = YES;
        self.unsupportedAppContainerView.hidden = NO;
        self.loginImageView.hidden = NO;
        self.spreedBoxLoginImageView.hidden = YES;
    } else if (_uiState == kSMLoginViewControllerUIStateOwnCloud) {
        self.containerView.hidden = NO;
        self.unsupportedAppContainerView.hidden = YES;
        self.createAccountLink.hidden = YES;
        self.resetPasswordLink.hidden = YES;
        self.loginImageView.hidden = YES;
        self.spreedBoxLoginImageView.hidden = NO;
        _spreedNameTextField.placeholder = NSLocalizedStringWithDefaultValue(@"label_your-owncloud-username",
                                                                             nil, [NSBundle mainBundle],
                                                                             @"Username",
                                                                             @"Username");
    }
}


#pragma mark - Public methods

- (void)setUsername:(NSString *)username
{
	_username = [username copy];
	self.spreedNameTextField.text = _username;
}


- (void)clearFields
{
	_username = nil;
	self.spreedNameTextField.text = nil;
	self.passwordTextField.text = nil;
}


- (void)dismissWaiting
{
	if (![_waitingForLoginView isBeingDismissed])
    {
        [_waitingForLoginView dismissViewControllerAnimated:YES completion:nil];
    }
}


- (void)setUIState:(SMLoginViewControllerUIState)uiState
{
    if (_uiState != uiState) {
        _uiState = uiState;
        [self updateUI];
    }
}


#pragma mark - UI Actions

- (IBAction)loginButtonPressed:(id)sender
{
    [self login];
}


- (IBAction)loginOptionsButtonPressed:(id)sender
{
    [self presentLoginOptions];
}


- (void)tapOnCreateAccountLink:(UITapGestureRecognizer *)tapGesture
{
    if (tapGesture.state == UIGestureRecognizerStateEnded)
    {
        [self openWebViewForLink:kSMLoginViewControllerLinkTypeCreateAccount];
    }
}


- (void)tapOnResetPasswordLink:(UITapGestureRecognizer *)tapGesture
{
    if (tapGesture.state == UIGestureRecognizerStateEnded)
    {
        [self openWebViewForLink:kSMLoginViewControllerLinkTypeResetPassword];
    }
}


- (void)openWebViewForLink:(SMLoginViewControllerLinkType)linkType
{
    NSInteger timeStamp = [[NSDate date] timeIntervalSince1970];
    NSString *urlString = [NSString stringWithFormat: @"https://account.spreed.me/referral/request-invitation?app=2&t=%ld&fragment&no_redirect", (long)timeStamp];
    
    if (linkType == kSMLoginViewControllerLinkTypeResetPassword) {
        urlString = [NSString stringWithFormat: @"https://account.spreed.me/referral/reset-password?app=2&t=%ld&fragment&no_redirect", (long)timeStamp];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0")) {
        SFSafariViewController *safariVC = [[SFSafariViewController alloc] initWithURL:url];
        [self presentViewController:safariVC animated:YES completion:nil];
    } else {
        SMWebViewController *webViewController = [[SMWebViewController alloc] init];
        ChildRotationNavigationController *webViewNavController = [[ChildRotationNavigationController alloc] initWithRootViewController:webViewController];
        
        NSString *createAccountTitle = NSLocalizedStringWithDefaultValue(@"screen_title_create-account",
                                                                         nil, [NSBundle mainBundle],
                                                                         @"Registration",
                                                                         @"Registration");
        
        NSString *resetPasswordTitle = NSLocalizedStringWithDefaultValue(@"screen_title_reset-password",
                                                                         nil, [NSBundle mainBundle],
                                                                         @"Reset Password",
                                                                         @"Reset Password");
        
        webViewController.title = (linkType == kSMLoginViewControllerLinkTypeCreateAccount) ? createAccountTitle : resetPasswordTitle;
        
        [self presentViewController:webViewNavController animated:YES completion:^{
            [webViewController loadRequestFromURL:url];
        }];
    }
}


#pragma mark - Actions

- (void)dismissKeyboard
{
	[self.spreedNameTextField resignFirstResponder];
	[self.passwordTextField resignFirstResponder];
}


- (void)login
{
    if ([SMConnectionController sharedInstance].spreedMeMode) {
        [self presentViewController:_waitingForLoginView animated:YES completion:^{
            [[SMConnectionController sharedInstance] loginWithUsername:self.spreedNameTextField.text password:self.passwordTextField.text];
        }];
    } else if ([SMConnectionController sharedInstance].ownCloudMode) {
        if ([SMConnectionController sharedInstance].ownCloudAppNotEnabled) {
            [self presentViewController:_waitingForLoginView animated:YES completion:^{
                [[SMConnectionController sharedInstance] checkPermissionToUseSpreedMEAppWithUsername:self.spreedNameTextField.text password:self.passwordTextField.text serverEndpoint:[SMConnectionController sharedInstance].currentOwnCloudServer];
            }];
        } else {
            [self presentViewController:_waitingForLoginView animated:YES completion:^{
                [[SMConnectionController sharedInstance] loginOCWithUsername:self.spreedNameTextField.text password:self.passwordTextField.text serverEndpoint:[SMConnectionController sharedInstance].currentOwnCloudRESTAPIEndpoint];
            }];
        }
    }
}


- (void)presentLoginOptions
{
#ifdef SPREEDME
    NSString *useOwnSpreedButtonText = kSMLocalStringSpreedboxModeLabel;
#else
    NSString *useOwnSpreedButtonText = kSMLocalStringOwnSpreedModeLabel;
#endif
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        UIAlertController *loginOptionsSheetController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *useOwnSpreed = [UIAlertAction actionWithTitle:useOwnSpreedButtonText style:UIAlertActionStyleDefault handler:^(UIAlertAction * action)
                                       {
                                           [self useAppInOwnSpreedMode];
                                       }];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:kSMLocalStringCancelButton style:UIAlertActionStyleCancel handler:^(UIAlertAction *action)
                                 {
                                     [loginOptionsSheetController dismissViewControllerAnimated:YES completion:nil];
                                 }];
        
        [loginOptionsSheetController addAction:useOwnSpreed];
        [loginOptionsSheetController addAction:cancel];
        
        UIPopoverPresentationController *popover = loginOptionsSheetController.popoverPresentationController;
        if (popover)
        {
            popover.sourceView = self.loginOptionsButton;
            popover.sourceRect = self.loginOptionsButton.bounds;
            popover.permittedArrowDirections = UIPopoverArrowDirectionUp;
        }
        
        [self presentViewController:loginOptionsSheetController animated:YES completion:nil];
    } else {
        _loginOptionsActionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                               delegate:self
                                                      cancelButtonTitle:kSMLocalStringCancelButton
                                                 destructiveButtonTitle:nil
                                                      otherButtonTitles:useOwnSpreedButtonText, nil];
        
        if (self.tabBarController) {
            [_loginOptionsActionSheet showFromTabBar:self.tabBarController.tabBar];
        } else {
            [_loginOptionsActionSheet showInView:self.view];
        }
    }
}


- (void)useAppInOwnSpreedMode
{
    if ([SMConnectionController sharedInstance].spreedMeMode) {
        [SMConnectionController sharedInstance].spreedMeMode = NO;
    } else {
        [SMConnectionController sharedInstance].ownCloudMode = NO;
        [[SMConnectionController sharedInstance] resetConnectionController];
    }
    
    [[UserInterfaceManager sharedInstance] presentServerSettingsViewController];
}


#pragma mark - Notifications

- (void)connectionBecomeActive:(NSNotification *)notification
{
    [self dismissWaiting];
}


- (void)connectionBecomeInactive:(NSNotification *)notification
{
    NSNumber *inactivityReason = [notification.userInfo objectForKey:kChannelingConnectionBecomeInactiveReasonKey];
    
    if ( inactivityReason && [inactivityReason integerValue] == kSMDisconnectionReasonUserFailedToLogin)
    {
        SMLoginFailReason reason = [[notification.userInfo objectForKey:kChannelingConnectionBecomeInactiveLoginFailedReasonKey]integerValue];
        NSString *failureReason = kSMLocalStringSignInFailedMessageBodyReasonUnspec;
        
        switch (reason) {
            case kSMLoginFailReasonIncorrectUserNameOrPassword:
				failureReason = NSLocalizedStringWithDefaultValue(@"message_body_login-failed_incorrect-spreed-name-or-password",
																  nil, [NSBundle mainBundle],
																  @"Spreed Name or password is incorrect.",
																  @"Spreed Name or password is incorrect.");
                break;
                
            default:
                break;
        }
        
        if (![_waitingForLoginView isBeingDismissed])
        {
            [_waitingForLoginView dismissViewControllerAnimated:YES completion:nil];
        }
        
        if (reason > kSMLoginFailReasonNotFailed) { //Present alert only if it has been a login error
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:kSMLocalStringSignInFailedMessageTitle
															message:failureReason
														   delegate:nil
												  cancelButtonTitle:kSMLocalStringSadOKButton
												  otherButtonTitles:nil];
            [alert show];
        }
    }
}


#pragma mark - UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _spreedNameTextField) {
        [_passwordTextField becomeFirstResponder];
    } else if (textField == _passwordTextField && _loginButton.enabled) {
        [self login];
    }
    return YES;
}


- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self animateTextView: YES];
}


- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [self animateTextView:NO];
}


- (void)animateTextView:(BOOL)up
{
    const int movementDistance = 90; // This distance that makes the 2 textviews and login button visible
    const float movementDuration = 0.3f;
    int movement= movement = (up ? -movementDistance : movementDistance);
    
    [UIView beginAnimations: @"textfieldsAnimation" context: nil];
    [UIView setAnimationBeginsFromCurrentState: YES];
    [UIView setAnimationDuration: movementDuration];
    self.view.frame = CGRectOffset(self.view.frame, 0, movement);
    [UIView commitAnimations];
}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *alreadyModifiedText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    if (alreadyModifiedText.length > 0 && (textField == _spreedNameTextField)) {
        if (_passwordTextField.text && _passwordTextField.text.length > 0) {
            _loginButton.enabled = YES;
        }
    } else if (alreadyModifiedText.length > 0 && (textField == _passwordTextField)) {
        if (_spreedNameTextField.text && _spreedNameTextField.text.length > 0) {
            _loginButton.enabled = YES;
        }
    } else {
        _loginButton.enabled = NO;
    }
    
    return YES;
}


#pragma mark - UIActionSheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (actionSheet == _loginOptionsActionSheet) {
        if (buttonIndex == 0) {
            [self useAppInOwnSpreedMode];
        }
        
        _loginOptionsActionSheet = nil;
    }
}


@end
