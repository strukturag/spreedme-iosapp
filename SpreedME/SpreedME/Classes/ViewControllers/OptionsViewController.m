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

#import "OptionsViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "BackgroundSettingsViewController.h"
#import "ChildRotationNavigationController.h"
#import "CommonDefinitions.h"
#import "FileBrowserControllerViewController.h"
#import "FileSharingManagerObjC.h"
#import "LicensesViewController2.h"
#import "LoginManager.h"
#import "NSString+FontAwesome.h"
#import "PeerConnectionController.h"
#import "PlainTextField.h"
#import "ServerSettingsViewController.h"
#import "SettingsController.h"
#import "SettingsViewController.h"
#import "SMConnectionController.h"
#import "SMLocalizedStrings.h"
#import "SSLCertificatesListViewController.h"
#import "SpreedMeRoundedButton.h"
#import "STSectionModel.h"
#import "STRowModel.h"
#import "TextFieldTableViewCell.h"
#import "TrustedSSLStore.h"
#import "UIFont+FontAwesome.h"
#import "UIImage+RoundedCorners.h"
#import "UserInterfaceManager.h"
#import "UserImageTableViewCell.h"
#import "UsersActivityController.h"
#import "UsersManager.h"
#import "VideoOptionsViewController.h"

#define kOFFSET_FOR_KEYBOARD 80.0


typedef enum : NSUInteger {
    kOptionsTableViewSectionProfile = 0,
    kOptionsTableViewSectionAdvancedSettings,
	kOptionsTableViewSectionAbout,
	kOptionsTableViewSectionCount
} OptionsTableViewSections;


typedef enum : NSUInteger {
	kProfileSectionUsername = 0,
	kProfileSectionPicture,
    kProfileSectionName,
	kProfileSectionStatus,
    kProfileSectionLogout,
} ProfileSectionRows;


typedef enum : NSInteger {
    kSMPSSRVideoSettings = 0,
    kSMPSSRBackgroundSettings,
    kSMPSSRAdvancedSettings,
} SMPreferencesSettingsSectionRows;


@interface OptionsViewController () <UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate,
									 UIGestureRecognizerDelegate, UITextFieldDelegate , UITableViewDataSource, UITableViewDelegate,
                                     VideoOptionsViewControllerDataSource, VideoOptionsViewControllerDelegate, BackgroundSettingsViewControllerDelegate>
{
    LicensesViewController2 *_licensesViewController;
    SettingsViewController *_settingsViewController;
	
	UIActionSheet *_pickerTypeActionSheet;
	UIActionSheet *_usePickedImageActionSheet;
	UIImage *_imageToPick;
	BOOL _isImagePickerInPopover;
    BOOL _isLoginScreenVisible;
    BOOL _isLoginUser;
    
    UIPopoverController *_videoOptionsPopover;
	
	NSMutableArray *_datasource;
	STSectionModel *_profileSection;
	STSectionModel *_appSettingsSection;
	STSectionModel *_aboutSection;
	
	//profile section
	STRowModel *_userImageRow;
	STRowModel *_userDisplayNameRow;
	STRowModel *_userStatusMessageRow;
	STRowModel *_userLogoutRow;
	STRowModel *_userUsernameRow;
	
	
}

@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSString *userStatusMessage;
@property (nonatomic, strong) UIImage *userImage;

@property (nonatomic, weak) ServerSettingsViewController *advancedSettingsVC;

@property (nonatomic, strong) UITextField *userNameTextField;
@property (nonatomic, strong) UITextField *userStatusMessageTextField;
@property (nonatomic, weak) UIImageView *userImageView;

@property (nonatomic, strong) IBOutlet UITableView *tableView;

@end

@implementation OptionsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
		NSString *localizedTabbarItemTitle = NSLocalizedStringWithDefaultValue(@"tabbar-item_title",
																			   nil, [NSBundle mainBundle],
																			   @"Preferences",
																			   @"Preferences. This should be small enough to fit into tab. ~11 Latin symbols fit.");
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:localizedTabbarItemTitle image:[UIImage imageNamed:@"profile_black"] tag:0];
		if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
			self.tabBarItem.selectedImage = [UIImage imageNamed:@"profile_white"];
		} else {
			self.tabBarItem.selectedImage = [UIImage imageNamed:@"profile_blue"];
		}
		self.navigationItem.title = localizedTabbarItemTitle;
		
		_datasource = [[NSMutableArray alloc] init];
		
		// Profile Section
		_profileSection = [STSectionModel new];
		_profileSection.type = kOptionsTableViewSectionProfile;
		_profileSection.title =  NSLocalizedStringWithDefaultValue(@"label_users-profile",
																   nil, [NSBundle mainBundle],
																   @"Profile",
																   @"User's profile");
		
		_userImageRow = [STRowModel new];
		_userImageRow.type = kProfileSectionPicture;
		_userImageRow.rowHeight = [UserImageTableViewCell cellHeight];
		_userDisplayNameRow = [STRowModel new];
		_userDisplayNameRow.type = kProfileSectionName;
		_userDisplayNameRow.rowHeight = [TextFieldTableViewCell cellHeight];
		_userStatusMessageRow = [STRowModel new];
		_userStatusMessageRow.type = kProfileSectionStatus;
		
		[_profileSection.items addObject:_userImageRow];
		[_profileSection.items addObject:_userDisplayNameRow];
		[_profileSection.items addObject:_userStatusMessageRow];
		
		_userLogoutRow = [STRowModel new];
		_userLogoutRow.type = kProfileSectionLogout;
		_userLogoutRow.title = kSMLocalStringSignOutButton;
		
		_userUsernameRow = [STRowModel new];
		_userUsernameRow.type = kProfileSectionUsername;
		_userUsernameRow.rowHeight = 30.0f;
		
		
		// Application settings Section
		_appSettingsSection = [STSectionModel new];
		_appSettingsSection.type = kOptionsTableViewSectionAdvancedSettings;
		_appSettingsSection.title = NSLocalizedStringWithDefaultValue(@"label_application-settings",
																	  nil, [NSBundle mainBundle],
																	  @"Application settings",
																	  @"Application settings");
		
        STRowModel *videoSettingsRow = [STRowModel new];
        videoSettingsRow.type = kSMPSSRVideoSettings;
        videoSettingsRow.title = kSMLocalStringVideoLabel;
        [_appSettingsSection.items addObject:videoSettingsRow];
        
        
		STRowModel *backgroundSettingsRow = [STRowModel new];
		backgroundSettingsRow.type = kSMPSSRBackgroundSettings;
		backgroundSettingsRow.title = kSMLocalStringBackgroundLabel;
		[_appSettingsSection.items addObject:backgroundSettingsRow];
        
        STRowModel *advancedSettingsRow = [STRowModel new];
        advancedSettingsRow.type = kSMPSSRAdvancedSettings;
        advancedSettingsRow.title = NSLocalizedStringWithDefaultValue(@"label_settings_advanced",
                                                                      nil, [NSBundle mainBundle],
                                                                      @"Advanced",
                                                                      @"Advanced application settings");
        [_appSettingsSection.items addObject:advancedSettingsRow];
        
        _settingsViewController = [[SettingsViewController alloc] initWithNibName:@"SettingsViewController" bundle:nil];
		
		// License Section
		_aboutSection = [STSectionModel new];
		_aboutSection.type = kOptionsTableViewSectionAbout;
		NSString *appDisplayNameString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
		NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		_aboutSection.title = [NSString stringWithFormat: @"%@ (%@)", appDisplayNameString, appVersionString];
		
		STRowModel *licenseRow = [STRowModel new];
		licenseRow.type = 0;
		licenseRow.title = kSMLocalStringLicensesLabel;
		
		[_aboutSection.items addObject:licenseRow];
		
		
		[_datasource addObject:_profileSection];
		[_datasource addObject:_appSettingsSection];
		[_datasource addObject:_aboutSection];
		
        [self setupOptionsViewFields];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionBecomeActive:) name:ChannelingConnectionBecomeActiveNotification object:nil];
	}
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
		self.edgesForExtendedLayout = UIRectEdgeNone;
	}
    
    _isLoginUser = [SMConnectionController sharedInstance].spreedMeMode && [SMConnectionController sharedInstance].connectionState == kSMConnectionStateConnected;
	if (_isLoginUser) {
		[_profileSection.items addObject:_userLogoutRow];
		[_profileSection.items insertObject:_userUsernameRow atIndex:0];
	}
	
    self.view.backgroundColor = kGrayColor_e5e5e5;
	
	if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.tableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.tableView.backgroundView = nil;
    }
	
    _licensesViewController = [[LicensesViewController2 alloc] initWithNibName:@"LicensesViewController2" bundle:nil];
    
    _isLoginScreenVisible = [SMConnectionController sharedInstance].appLoginState == kSMAppLoginStatePromptUserToLogin;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(userHasResetApp:)
												 name:ConnectionControllerHasProcessedChangeOfApplicationModeNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(userHasResetApp:)
												 name:ConnectionControllerHasProcessedResetOfApplicationNotification
											   object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(userLoginStatusHasChanged:)
												 name:SMAppLoginStateHasChangedNotification
											   object:nil];
}


- (void)viewDidAppear:(BOOL)animated
{
    [self setupOptionsViewFields];
    [self.tableView reloadData];
}


- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
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


#pragma mark - Utility methods

-(void)dismissKeyboard
{
	[self.userNameTextField resignFirstResponder];
	[self.userStatusMessageTextField resignFirstResponder];
}


- (void)closeItself
{
	if (self.presentingPopover) {
		[self.presentingPopover dismissPopoverAnimated:YES];
		self.presentingPopover = nil;
	} else if (self.navigationController) {
		[self.navigationController popViewControllerAnimated:YES];
	} else {
		[self dismissViewControllerAnimated:YES completion:NULL];
	}
}


+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize
{
    return [self imageWithImage:image scaledToSize:newSize withScale:0.0f];
}


+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize withScale:(CGFloat)scale
{
    UIGraphicsBeginImageContextWithOptions(newSize, NO, scale);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}


- (void)setupOptionsViewFields
{
    self.userName = [UsersManager defaultManager].currentUser.displayName;
	self.userStatusMessage = [UsersManager defaultManager].currentUser.statusMessage;
    
    UIImage *userImage = [UsersManager defaultManager].currentUser.iconImage;
    if (!userImage) {
		userImage = [UIImage imageNamed:@"buddy_icon.png"];
        userImage = [userImage roundCornersWithRadius:kViewCornerRadius];
        [UsersManager defaultManager].currentUser.iconImage = userImage;
	}
    
    self.userImage = userImage;
}


#pragma mark - Actions

- (void)changeUserImage:(UIImage *)image base64EncodedImage:(NSString *)base64EncodedImage
{
    [UsersManager defaultManager].currentUser.iconImage = image;
    [UsersManager defaultManager].currentUser.base64Image = base64EncodedImage;
    [[UsersManager defaultManager] saveCurrentUser];
}


- (void)changeUserStatusName:(NSString *)userName
{
	[UsersManager defaultManager].currentUser.displayName = userName;
    [[UsersManager defaultManager] saveCurrentUser];
}


- (void)changeUserStatusMessage:(NSString *)statusMessage
{
	[UsersManager defaultManager].currentUser.statusMessage = statusMessage;
    [[UsersManager defaultManager] saveCurrentUser];
}


- (void)changeUserImage
{
	// Preset an action sheet which enables the user to take a new picture or select and existing one.
	NSString *takePhotoButtonLocTitle = NSLocalizedStringWithDefaultValue(@"button_take-photo",
																		  nil, [NSBundle mainBundle],
																		  @"Take photo",
																		  @"Take a photo");
	NSString *chooseExistingButtonLocTitle = NSLocalizedStringWithDefaultValue(@"button_choose-existing-photo",
																			   nil, [NSBundle mainBundle],
																			   @"Choose existing",
																			   @"Choose existing (photo). 'Photo' is already mentioned in other UI element.");
	
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        UIAlertController *actionSheetController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *takePhotoAction = [UIAlertAction actionWithTitle:takePhotoButtonLocTitle
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) {
                                                                    [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera];
                                                                }];
        
        UIAlertAction *photoLibraryAction = [UIAlertAction actionWithTitle:chooseExistingButtonLocTitle
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * action) {
                                                                       [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
                                                                   }];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:kSMLocalStringCancelButton
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                           [actionSheetController dismissViewControllerAnimated:YES completion:nil];
                                                       }];
        
        [actionSheetController addAction:takePhotoAction];
        [actionSheetController addAction:photoLibraryAction];
        [actionSheetController addAction:cancel];
        
        UIPopoverPresentationController *popover = actionSheetController.popoverPresentationController;
        if (popover)
        {
            popover.sourceView = self.userImageView;
            popover.sourceRect = self.userImageView.bounds;
            popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        }
        
        [self presentViewController:actionSheetController animated:YES completion:nil];
    } else {
        // Preset an action sheet which enables the user to take a new picture or select and existing one.
        _pickerTypeActionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:kSMLocalStringCancelButton
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:takePhotoButtonLocTitle, chooseExistingButtonLocTitle, nil];
        
        // Show the action sheet
        if (self.tabBarController) {
            [_pickerTypeActionSheet showFromTabBar:self.tabBarController.tabBar];
        } else {
            [_pickerTypeActionSheet showInView:self.view];
        }
    }
}


- (void)logout
{
	[[SMConnectionController sharedInstance] logout];
}


#pragma mark - UIAlertView Delegate

- (void)showLogoutAlert
{
    UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:kSMLocalStringSignOutButton
														  message:NSLocalizedStringWithDefaultValue(@"message_body_confirm-logout",
																									nil, [NSBundle mainBundle],
																									@"Do you want to log out?",
																									@"Do you want to log out?")
														 delegate:self
												cancelButtonTitle:kSMLocalStringCancelButton
												otherButtonTitles:kSMLocalStringOKButton, nil];
    
    myAlertView.delegate = self;
    [myAlertView show];
}


- (void)alertView:(UIAlertView *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
    {
        [self logout];
    }
}


#pragma mark -

/*
	Presents image picker for given image picker source type. 
	@sourceType - (UIImagePickerControllerSourceType) source type for image picker.
	@showInPopover - (BOOL) tells this method to present picker in popover on iPad.
 */

- (void)showImagePickerWithSourceType:(UIImagePickerControllerSourceType)sourceType
{
	UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.navigationBar.tintColor = [UIColor grayColor];
    imagePicker.navigationBar.translucent = NO;
	
	if (imagePicker) {
		imagePicker.delegate = self;
        imagePicker.allowsEditing = YES;
		imagePicker.sourceType = sourceType;
		if (sourceType == UIImagePickerControllerSourceTypeCamera) {
			[self presentViewController:imagePicker animated:YES completion:nil];
			_isImagePickerInPopover = NO;
			
		} else if (sourceType == UIImagePickerControllerSourceTypePhotoLibrary) {
			
			if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && !self.presentingPopover) {
				_popover = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
				[_popover presentPopoverFromRect:self.userImageView ? [self.userImageView convertRect:self.userImageView.bounds toView:self.view] : self.tableView.frame
										  inView:self.view
						permittedArrowDirections:UIPopoverArrowDirectionAny
										animated:YES];
				_isImagePickerInPopover = YES;
			} else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && self.presentingPopover)  {
				[self.presentingPopover setContentViewController:imagePicker animated:YES];
				_isImagePickerInPopover = YES;
			} else {
				[self presentViewController:imagePicker animated:YES completion:nil];
				_isImagePickerInPopover = NO;
			}
		}
	} else {
		// Problem with camera, alert user
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:kSMLocalStringNoCameraMessageTitle
														message:kSMLocalStringNoCameraMessageBody
													   delegate:nil
											  cancelButtonTitle:kSMLocalStringSadOKButton
											  otherButtonTitles:nil];
		[alert show];
	}
}


- (void)hideImagePicker
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && !self.presentingPopover) {
		[_popover dismissPopoverAnimated:YES];
        [self dismissViewControllerAnimated:YES completion:NULL];
	} else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && self.presentingPopover)  {
		if (_isImagePickerInPopover) {
			[self.presentingPopover setContentViewController:self animated:YES];
		} else {
			[self dismissViewControllerAnimated:YES completion:NULL];
		}
	} else {
		[self dismissViewControllerAnimated:YES completion:NULL];
	}
}


- (void)userPickedUpNewImage:(UIImage *)imageToSave
{	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		CGSize newSize = CGSizeMake(120.0, 120.0); // this is size of icon we will send to server
		
		// resize original image and grab base64 encoded image with size of exactly 120x120 pixels
		NSString *imageToSend = [BuddyParser base64EncodedStringWithFormatPrefixFromImage:[OptionsViewController imageWithImage:imageToSave scaledToSize:newSize withScale:1.0f]];
		
		// create image for internal use, this uses 120x120 units (on retina displays 240x240 pixels)
		UIImage *localResizedImage = [OptionsViewController imageWithImage:imageToSave scaledToSize:newSize];
		localResizedImage = [localResizedImage roundCornersWithRadius:kViewCornerRadius];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			self.userImage = localResizedImage;
			[self changeUserImage:localResizedImage base64EncodedImage:imageToSend];
			[self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:[_profileSection.items indexOfObject:_userImageRow]
																		inSection:[_datasource indexOfObject:_profileSection]]]
								  withRowAnimation:UITableViewRowAnimationFade];
		});
	});
}


#pragma mark - Notifications

- (void)userHasResetApp:(NSNotification *)notification
{
    [self setupOptionsViewFields];
    _isLoginUser = [SMConnectionController sharedInstance].spreedMeMode && [SMConnectionController sharedInstance].connectionState == kSMConnectionStateConnected;
    [self.tableView reloadData];
}


- (void)userLoginStatusHasChanged:(NSNotification *)notification
{
    if ([notification.userInfo objectForKey:kSMNewAppLoginStateKey]) {
		SMAppLoginState appLoginState = [[notification.userInfo objectForKey:kSMNewAppLoginStateKey] integerValue];
		_isLoginScreenVisible = appLoginState == kSMAppLoginStatePromptUserToLogin;
		BOOL lastIsLoginUser = _isLoginUser;
        _isLoginUser = [SMConnectionController sharedInstance].spreedMeMode && [SMConnectionController sharedInstance].connectionState == kSMConnectionStateConnected;
		if (!lastIsLoginUser && _isLoginUser) {
			
			if (![_profileSection.items containsObject:_userLogoutRow]) {
				[_profileSection.items addObject:_userLogoutRow];
			}
			if (![_profileSection.items containsObject:_userUsernameRow]) {
				[_profileSection.items insertObject:_userUsernameRow atIndex:0];
			}
		} else if (lastIsLoginUser && !_isLoginUser) {
			[_profileSection.items removeObject:_userUsernameRow];
			[_profileSection.items removeObject:_userLogoutRow];
		}
        [self.tableView reloadData];
	}
}


- (void)connectionBecomeActive:(NSNotification *)notification
{
    [self setupOptionsViewFields];
    _isLoginUser = [SMConnectionController sharedInstance].spreedMeMode && [SMConnectionController sharedInstance].connectionState == kSMConnectionStateConnected;
}


#pragma mark - UITextField delegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{

}


- (void)textFieldDidEndEditing:(UITextField *)textField
{
	if (textField == self.userNameTextField)
    {
		if (![self.userName isEqualToString:textField.text]) {
			self.userName = self.userNameTextField.text;
			[self changeUserStatusName:self.userName];
		}
    } else if (textField == self.userStatusMessageTextField) {
		if (![self.userStatusMessage isEqualToString:textField.text]) {
			self.userStatusMessage = self.userStatusMessageTextField.text;
			[self changeUserStatusMessage:self.userStatusMessage];
		}
	}
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    if (textField == self.userNameTextField)
    {
        if (![self.userName isEqualToString:textField.text]) {
			self.userName = self.userNameTextField.text;
			[self changeUserStatusName:self.userName];
		}
    } else if (textField == self.userStatusMessageTextField) {
		if (![self.userStatusMessage isEqualToString:textField.text]) {
			self.userStatusMessage = self.userStatusMessageTextField.text;
			[self changeUserStatusMessage:self.userStatusMessage];
		}
	}
    
    return YES;
}


#pragma mark - UIActionSheetDelegate methods

// Override this method to know if user wants to take a new photo or select from the photo library
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (actionSheet == _pickerTypeActionSheet) {
		if (0 == buttonIndex) { // index == 0 for "Take Photo" button
			[self showImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera];
		} else if (1 == buttonIndex) { // index == 1 for "Choose Existing" button
			[self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
		} // else index == 2 for "Cancel" button
		
		_pickerTypeActionSheet = nil;
		
	} else if (actionSheet == _usePickedImageActionSheet) {
		if (buttonIndex == 0) { // index == 0 for "Set" button
			[self hideImagePicker];
			UIImage *imageToSave = _imageToPick;
			[self userPickedUpNewImage:imageToSave];
		} else { // index == 1 for "Cancel" button
			[self hideImagePicker];
		}
		_usePickedImageActionSheet = nil;
	}
}


#pragma mark - UIImagePickerViewControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
	[self hideImagePicker];
}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    //Did not create UIAlertController on iOS 8 because it is shown under UIImagePickerController
    _usePickedImageActionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:kSMLocalStringCancelButton
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:NSLocalizedStringWithDefaultValue(@"button_set",
                                                                                                        nil, [NSBundle mainBundle],
                                                                                                        @"Set",
                                                                                                        @"Set some value"), nil];
    _imageToPick = (UIImage *)[info objectForKey:UIImagePickerControllerEditedImage];
    [_usePickedImageActionSheet showInView:picker.view];
}


#pragma mark - UINavigationController Delegate for UIImagePickerController

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		if ([navigationController isKindOfClass:[UIImagePickerController class]]) {
			navigationController.navigationBar.topItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
																										 target:self
																										 action:@selector(imagePickerControllerDidCancel:)];
		}
	}
}


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	STSectionModel *sectionModel = _datasource[indexPath.section];
	STRowModel *rowModel = sectionModel.items[indexPath.row];
	
	switch (sectionModel.type) {
		case kOptionsTableViewSectionProfile:
			switch (rowModel.type) {
				case kProfileSectionPicture:
					[self changeUserImage];
				break;
                
                case kProfileSectionLogout:
                    [self showLogoutAlert];
                break;
					
				default:
				break;
			}
		break;
			
		case kOptionsTableViewSectionAdvancedSettings:
		{
            switch (rowModel.type) {
                case kSMPSSRVideoSettings:
                {
                    CGRect cellRect = CGRectMake(100.0f, 100.0f,
                                                 50.0f, 50.0f);
                    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                    if (cell) {
                        cellRect = [cell convertRect:cell.bounds toView:self.view];
                    }
   
                    [self presentVideoOptionsViewController:cellRect];
                }
                break;
                case kSMPSSRBackgroundSettings:
                    [self pushBackgroundSettingsViewController];
                break;
                case kSMPSSRAdvancedSettings:
                    [self pushSettingsViewControllerAnimated:YES];
                break;
                default:
                break;
            }
		}
		break;
			
		case kOptionsTableViewSectionAbout:
		{
			[self.navigationController pushViewController:_licensesViewController animated:YES];
		}
		break;
			
		default:
		break;
	}
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
	BOOL answer = YES;
	
	STSectionModel *sectionModel = _datasource[indexPath.section];
	STRowModel *rowModel = sectionModel.items[indexPath.row];
	
	if ((sectionModel.type == kOptionsTableViewSectionProfile && rowModel.type == kProfileSectionName) ||
		(sectionModel.type == kOptionsTableViewSectionProfile && rowModel.type == kProfileSectionUsername)) {
		answer = NO;
	}

	return answer;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	STSectionModel *sectionModel = _datasource[indexPath.section];
	STRowModel *rowModel = sectionModel.items[indexPath.row];
	
	return rowModel.rowHeight;
}


- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	[self dismissKeyboard];
}


#pragma mark - UITableView Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return _datasource.count;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSInteger numberOfRows = 0;
	
	STSectionModel *sectionModel = _datasource[section];
	
	numberOfRows = sectionModel.items.count;
	
	return numberOfRows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = nil;
	
	static NSString *UsernameCellIdentifier = @"UsernameCellIdentifier";
	static NSString *NameCellIdentifier = @"NameCellIdentifier";
	static NSString *StatusCellIdentifier = @"StatusCellIdentifier";
	static NSString *ImageCellIdentifier = @"ImageCellIdentifier";
    static NSString *LogoutCellIdentifier = @"LogoutCellIdentifier";
	static NSString *AdvancedOptionsCellIdentifier = @"AdvancedOptionsCellIdentifier";
	static NSString *AboutCellIdentifier = @"AboutCellIdentifier";
	
	
	STSectionModel *sectionModel = _datasource[indexPath.section];
	STRowModel *rowModel = sectionModel.items[indexPath.row];
	
	switch (sectionModel.type) {
		case kOptionsTableViewSectionProfile:
		{
			switch (rowModel.type) {
				case kProfileSectionPicture:
				{
					cell = [tableView dequeueReusableCellWithIdentifier:ImageCellIdentifier];
					if (!cell) {
						cell = [[UserImageTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ImageCellIdentifier];
					}
					
					cell.textLabel.text = NSLocalizedStringWithDefaultValue(@"label_your-picture",
																			nil, [NSBundle mainBundle],
																			@"Your picture",
																			@"Your picture. User's picture.");
					cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
					cell.imageView.image = (_isLoginScreenVisible) ? [UIImage imageNamed:@"buddy_icon.png"] : self.userImage;
                    
                    cell.userInteractionEnabled = (_isLoginScreenVisible) ? NO : YES;
                    cell.textLabel.enabled = (_isLoginScreenVisible) ? NO : YES;
                    cell.imageView.alpha = (_isLoginScreenVisible) ? 0.2 : 1.0;
                    
					self.userImageView = cell.imageView;
				}
				break;
				
				case kProfileSectionName:
				{
					TextFieldTableViewCell *textFieldCell = (TextFieldTableViewCell *)[tableView dequeueReusableCellWithIdentifier:NameCellIdentifier];
					if (!textFieldCell) {
						textFieldCell = [[TextFieldTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:NameCellIdentifier];
					}

					textFieldCell.textLabel.text = NSLocalizedStringWithDefaultValue(@"label_your-name",
																					 nil, [NSBundle mainBundle],
																					 @"Your name",
																					 @"Your name");
					textFieldCell.textField.placeholder = NSLocalizedStringWithDefaultValue(@"placeholder_name",
																							nil, [NSBundle mainBundle],
																							@"Name",
																							@"Place holder for name");
					textFieldCell.textField.text = (_isLoginScreenVisible) ? @"" : [_userName copy];;
					textFieldCell.textField.backgroundColor = [UIColor whiteColor];
					textFieldCell.textField.delegate = self;
					self.userNameTextField = textFieldCell.textField;
                    
                    textFieldCell.userInteractionEnabled = (_isLoginScreenVisible) ? NO : YES;
                    textFieldCell.textLabel.enabled = (_isLoginScreenVisible) ? NO : YES;
                    
                    textFieldCell.userInteractionEnabled = ([SettingsController sharedInstance].ownCloudMode) ? NO : YES;
					
					cell = textFieldCell;
					cell.selectionStyle = UITableViewCellSelectionStyleNone;
				}
				break;
				
				case kProfileSectionStatus:
				{
					TextFieldTableViewCell *textFieldCell = (TextFieldTableViewCell *)[tableView dequeueReusableCellWithIdentifier:StatusCellIdentifier];
					if (!textFieldCell) {
						textFieldCell = [[TextFieldTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:StatusCellIdentifier];
					}
					
					textFieldCell.textLabel.text = NSLocalizedStringWithDefaultValue(@"label_status",
																					 nil, [NSBundle mainBundle],
																					 @"Status",
																					 @"Status message users sometimes make as a subtitle to their name. Like current playing song or witty quote");
					textFieldCell.textField.placeholder = NSLocalizedStringWithDefaultValue(@"placeholder_status",
																							nil, [NSBundle mainBundle],
																							@"What's on your mind?",
																							@"This placeholder message encourages user to share his current status. Like current playing song or witty quote");
					textFieldCell.textField.text = (_isLoginScreenVisible) ? @"" : [_userStatusMessage copy];
					textFieldCell.textField.backgroundColor = [UIColor whiteColor];
					textFieldCell.textField.delegate = self;
					self.userStatusMessageTextField = textFieldCell.textField;
                    
                    textFieldCell.userInteractionEnabled = (_isLoginScreenVisible) ? NO : YES;
                    textFieldCell.textLabel.enabled = (_isLoginScreenVisible) ? NO : YES;
					
					cell = textFieldCell;
					cell.selectionStyle = UITableViewCellSelectionStyleNone;
				}
				break;
                
                case kProfileSectionLogout:
				{
                    TextFieldTableViewCell *textFieldCell = (TextFieldTableViewCell *)[tableView dequeueReusableCellWithIdentifier:LogoutCellIdentifier];
                    if (!textFieldCell) {
                        textFieldCell = [[TextFieldTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:LogoutCellIdentifier];
                    }
					
					textFieldCell.textLabel.text = rowModel.title;
                    textFieldCell.textField.userInteractionEnabled = NO;
                    textFieldCell.textField = nil;
                    textFieldCell.detailTextLabel.font = [UIFont fontWithName:kFontAwesomeFamilyName size:22];
                    textFieldCell.detailTextLabel.text = [NSString fontAwesomeIconStringForEnum:FASignOut];
                    
                    cell = textFieldCell;
				}
                    break;
					
				case kProfileSectionUsername:
				{
					cell = [tableView dequeueReusableCellWithIdentifier:UsernameCellIdentifier];
					if (!cell) {
						cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:UsernameCellIdentifier];
					}
					
					cell.textLabel.text = [UsersManager defaultManager].currentUser.username;
					cell.textLabel.textAlignment = NSTextAlignmentCenter;
					cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
					if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
						cell.separatorInset = UIEdgeInsetsZero;
					}
                    cell.backgroundColor = kSMProfileUserNameBackgroundColor;
				}
				break;
					
				default:
				break;
			}
			
			
		}
		break;
			
		case kOptionsTableViewSectionAdvancedSettings:
		{
            cell = [tableView dequeueReusableCellWithIdentifier:AboutCellIdentifier];
			if (!cell) {
				cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:AdvancedOptionsCellIdentifier];
			}
            
            switch (rowModel.type) {
                case kSMPSSRBackgroundSettings:
                case kSMPSSRVideoSettings:
                    cell.userInteractionEnabled = (_isLoginScreenVisible) ? NO : YES;
                    cell.textLabel.enabled = (_isLoginScreenVisible) ? NO : YES;
                    cell.imageView.alpha = (_isLoginScreenVisible) ? 0.2 : 1.0;
                break;
                    
                default:
                    break;
            }
			
			cell.textLabel.text = rowModel.title;
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		break;
			
		case kOptionsTableViewSectionAbout:
		{
			cell = [tableView dequeueReusableCellWithIdentifier:AboutCellIdentifier];
			if (!cell) {
				cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:AboutCellIdentifier];
			}
			
			cell.textLabel.text = rowModel.title;
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		break;
			
		default:
		break;
	}
    
    cell.textLabel.textColor = kSMBuddyCellTitleColor;
	
	return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	STSectionModel *sectionModel = _datasource[section];
	NSString *title = sectionModel.title;
	return title;
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return kTableViewHeaderHeight + kTableViewFooterHeight;
    }
    
    return kTableViewHeaderHeight;
}


- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return kTableViewFooterHeight;
}


#pragma mark - Present Video, Background settings controller

- (void)pushBackgroundSettingsViewController
{
    BackgroundSettingsViewController *backgroundSettingsVC = [[BackgroundSettingsViewController alloc] initWithNibName:@"BackgroundSettingsViewController" bundle:nil];
    backgroundSettingsVC.delegate = self;
    backgroundSettingsVC.backgroundDisconnectionValue = [UsersManager defaultManager].currentUser.settings.shouldDisconnectOnBackground;
    backgroundSettingsVC.backgroundCleanDataValue = [UsersManager defaultManager].currentUser.settings.shouldClearDataOnBackground;
    [self.navigationController pushViewController:backgroundSettingsVC animated:YES];
}


- (void)pushSettingsViewControllerAnimated:(BOOL)animated
{
    [self.navigationController pushViewController:_settingsViewController animated:animated];
}


- (void)presentServerSettingsViewController
{
    [self pushSettingsViewControllerAnimated:NO];
    [_settingsViewController presentServerSettingsViewController];
}

- (void)presentVideoOptionsViewController:(CGRect)cellRect
{
    SMVideoSettings *userVideoSettings = SMVideoSettingsFromLocalUserSettings([UsersManager defaultManager].currentUser.settings);
   
    VideoOptionsViewController *videoOptionsVC = [[VideoOptionsViewController alloc] initWithNibName:@"VideoOptionsViewController" bundle:nil];
    videoOptionsVC.delegate = self;
    videoOptionsVC.datasource = self;
    videoOptionsVC.userVideoSettings = userVideoSettings;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
            videoOptionsVC.preferredContentSize = CGSizeMake(320.0f, 568.0f);
        } else {
            videoOptionsVC.contentSizeForViewInPopover = CGSizeMake(320.0f, 568.0f);
        }
        _videoOptionsPopover = [[UIPopoverController alloc] initWithContentViewController:videoOptionsVC];
        [_videoOptionsPopover presentPopoverFromRect:cellRect
                                              inView:self.view
                            permittedArrowDirections:UIPopoverArrowDirectionAny
                                            animated:YES];
    } else {
        [self.navigationController pushViewController:videoOptionsVC animated:YES];
    }
}


#pragma mark - BackgroundSettingsViewController delegate

- (void)backgroundSettingsViewController:(BackgroundSettingsViewController *)backgroundSettingsVC
           hasSetBackgroundDisconnection:(BOOL)backgroundDisconnection
                            andCleanData:(BOOL)cleanData
{
    [UsersManager defaultManager].currentUser.settings.shouldClearDataOnBackground = cleanData;
    [UsersManager defaultManager].currentUser.settings.shouldDisconnectOnBackground = backgroundDisconnection;
    
    [[UsersManager defaultManager] saveCurrentUser];
}


#pragma mark - VideoOptionsViewController delegate

- (void)videoOptionsViewController:(VideoOptionsViewController *)videoOptionsVC hasSetVideoSettings:(SMVideoSettings *)videoSettings
{
    SMSetVideoSettingsToLocalUserSettings(videoSettings, [UsersManager defaultManager].currentUser.settings);
    
    [[PeerConnectionController sharedInstance] setVideoPreferencesWithCamera:videoSettings.deviceId
                                                             videoFrameWidth:videoSettings.frameWidth
                                                            videoFrameHeight:videoSettings.frameHeight
                                                                         FPS:videoSettings.fps];
    
    [[UsersManager defaultManager] saveCurrentUser];
}


#pragma mark - VideoOptionsViewController datasource

- (NSArray *)videoDevicesForVideoOptionsViewController:(VideoOptionsViewController *)videoOptionsVC
{
    return [[PeerConnectionController sharedInstance] videoDevices];
}


- (NSArray *)videoOptionsViewController:(VideoOptionsViewController *)videoOptionsVC videoDeviceCapabilitiesForDevice:(SMVideoDevice *)videoDevice
{
    return [[PeerConnectionController sharedInstance] videoDeviceCapabilitiesForDevice:videoDevice];
}


@end
