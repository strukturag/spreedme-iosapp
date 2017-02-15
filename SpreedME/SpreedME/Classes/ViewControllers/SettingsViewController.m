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

#import "SettingsViewController.h"

#import "DataUsageViewController.h"
#import "ChildRotationNavigationController.h"
#import "CommonDefinitions.h"
#import "NSString+FontAwesome.h"
#import "PeerConnectionController.h"
#import "ServerSettingsViewController.h"
#import "SettingsController.h"
#import "SMLedControlViewController.h"
#import "SMConnectionController.h"
#import "SMLocalizedStrings.h"
#import "SSLCertificatesListViewController.h"
#import "STRowModel.h"
#import "STSectionModel.h"
#import "TrustedSSLStore.h"
#import "UIFont+FontAwesome.h"
#import "UsersManager.h"

#define kOFFSET_FOR_KEYBOARD 80.0

#define kSettingsViewControllerResetAlertViewTag			1
#define kSettingsViewControllerSpreedMeModeAlertViewTag		2


typedef enum : NSInteger {
    kSMServerSectionServer = 0,
    kSMServerSectionLED,
} SMServerSectionRows;

typedef enum : NSInteger {
    kSMAdvancedSectionSpreedMeMode = 0,
    kSMAdvancedSectionDataUsage,
    kSMAdvancedSectionReset,
    kSMAdvancedSectionTrustedSSLStore,
    kSMAdvancedSectionNotifyAboutUpdates,
} SMAdvancedSectionRows;


typedef enum : NSInteger {
    kSMSVCSAdvancedSettings = 0,
    kSMSVCSServerSettings,
} SMSettingsViewControllerSections;


@interface SettingsViewController () <UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate,
                                      UIGestureRecognizerDelegate, UITextFieldDelegate , UITableViewDataSource, UITableViewDelegate,
                                      ServerSettingsViewControllerDelegate, SSLCertificatesListViewControllerDelegate>
{
	UISwitch *_ownSpreedModeSwitch;
    UISwitch *_notifyAboutUpdatesSwitch;
    
	BOOL _pendingOwnSpreedMode;
    
    // TableView
    NSMutableArray *_datasource;
    STSectionModel *_advancedSettingsSection;
    STSectionModel *_serverSettingsSection;
    //_advancedSettingsSection
    STRowModel *_spreedMeModeRow;
    STRowModel *_dataUsageRow;
    STRowModel *_resetRow;
    STRowModel *_trustedSSLStoreRow;
    STRowModel *_notifyAboutUpdatesRow;
    STRowModel *_ledRow;
}

@property (nonatomic, assign) BOOL spreedMeMode;
@property (nonatomic, copy) NSString *serverURL;
@property (nonatomic, weak) ServerSettingsViewController *serverSettingsVC;
@property (nonatomic, strong) IBOutlet UITableView *tableView;


@end

@implementation SettingsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
		
		NSString *settingsLocString = NSLocalizedStringWithDefaultValue(@"tabbar-item_title_settings",
																		nil, [NSBundle mainBundle],
																		@"Settings",
																		@"This should be small enough to fit into tab. ~11 Latin symbols fit.");
		
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:settingsLocString image:[UIImage imageNamed:@"profile_black"] tag:0];
        self.tabBarItem.selectedImage = [UIImage imageNamed:@"profile_white"];
		self.navigationItem.title = settingsLocString;
        
        // Sections
        // _advancedSettingsSection
        _advancedSettingsSection = [[STSectionModel alloc] init];
        _advancedSettingsSection.type = kSMSVCSAdvancedSettings;
        _advancedSettingsSection.title = NSLocalizedStringWithDefaultValue(@"label_advanced-settings",
                                                                           nil, [NSBundle mainBundle],
                                                                           @"Advanced settings",
                                                                           @"Advanced settings");
        _spreedMeModeRow = [STRowModel new];
        _spreedMeModeRow.type = kSMAdvancedSectionSpreedMeMode;
#ifdef SPREEDME
        _spreedMeModeRow.title = kSMLocalStringSpreedboxModeLabel;
#else
        _spreedMeModeRow.title = kSMLocalStringOwnSpreedModeLabel;
#endif
        [_advancedSettingsSection.items addObject:_spreedMeModeRow];
        
        _dataUsageRow = [STRowModel new];
        _dataUsageRow.type = kSMAdvancedSectionDataUsage;
        _dataUsageRow.title = kSMLocalStringDataUsageLabel;
        [_advancedSettingsSection.items addObject:_dataUsageRow];
        
        _resetRow = [STRowModel new];
        _resetRow.type = kSMAdvancedSectionReset;
        _resetRow.title = kSMLocalStringResetAppButton;
        [_advancedSettingsSection.items addObject:_resetRow];
        
        _trustedSSLStoreRow = [STRowModel new];
        _trustedSSLStoreRow.type = kSMAdvancedSectionTrustedSSLStore;
        _trustedSSLStoreRow.title = NSLocalizedStringWithDefaultValue(@"label_trusted-ssl-store",
                                                                     nil, [NSBundle mainBundle],
                                                                     @"Trusted SSL store",
                                                                     @"Trusted SSL store. A place where trusted SSL/TLS certificates are stored.");
        [_advancedSettingsSection.items addObject:_trustedSSLStoreRow];
        
        _notifyAboutUpdatesRow = [STRowModel new];
        _notifyAboutUpdatesRow.type = kSMAdvancedSectionNotifyAboutUpdates;
        _notifyAboutUpdatesRow.title = NSLocalizedStringWithDefaultValue(@"label_notify-about-updates",
                                                                         nil, [NSBundle mainBundle],
                                                                         @"Notify about updates",
                                                                         @"Notify about updates. Should user be notified that there is a new application version");
        [_advancedSettingsSection.items addObject:_notifyAboutUpdatesRow];
        
        
        //_serverSettingsSection
        _serverSettingsSection = [STSectionModel new];
        _serverSettingsSection.type = kSMSVCSServerSettings;
#ifdef SPREEDME
        _serverSettingsSection.title = NSLocalizedStringWithDefaultValue(@"label_spreedbox-settings",
                                                                         nil, [NSBundle mainBundle],
                                                                         @"Spreedbox settings",
                                                                         @"Spreedbox settings");
#else
        _serverSettingsSection.title = NSLocalizedStringWithDefaultValue(@"label_server-settings",
                                                                         nil, [NSBundle mainBundle],
                                                                         @"Server settings",
                                                                         @"Server settings");
#endif
        STRowModel *serverRow = [STRowModel new];
        serverRow.type = kSMServerSectionServer;
#ifdef SPREEDME
        serverRow.title = NSLocalizedStringWithDefaultValue(@"label_spreedbox-server",
                                                            nil, [NSBundle mainBundle],
                                                            @"Setup Spreedbox",
                                                            @"Setup(verb) Spreedbox");
#else
        serverRow.title = NSLocalizedStringWithDefaultValue(@"label_setup-server",
                                                            nil, [NSBundle mainBundle],
                                                            @"Setup server",
                                                            @"Setup(verb) server");
#endif
        
        [_serverSettingsSection.items addObject:serverRow];
        
        _ledRow = [STRowModel new];
        _ledRow.type = kSMServerSectionLED;
        _ledRow.title = kSMLocalStringLedControlLabel;

        _datasource = [[NSMutableArray alloc] init];
        [_datasource addObject:_serverSettingsSection];
        [_datasource addObject:_advancedSettingsSection];
	}
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionHasChangedState:) name:ConnectionHasChangedStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasChangedSpreedMeModeNotif:) name:UserHasChangedApplicationModeNotification object:nil];
    
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
	
    self.view.backgroundColor = kGrayColor_e5e5e5;
	
	if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.tableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.tableView.backgroundView = nil;
    }
    
    self.serverURL = [UsersManager defaultManager].currentUser.settings.serverString;
    
    self.spreedMeMode = [SettingsController sharedInstance].spreedMeMode;
    _ownSpreedModeSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    _ownSpreedModeSwitch.on = !self.spreedMeMode;
    [_ownSpreedModeSwitch addTarget:self action:@selector(ownSpreedValueChanged:) forControlEvents:UIControlEventValueChanged];
    
    _notifyAboutUpdatesSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    _notifyAboutUpdatesSwitch.on = ![SettingsController sharedInstance].shouldNotNotifyAboutNewApplicationVersion;
    [_notifyAboutUpdatesSwitch addTarget:self
                                  action:@selector(notifyAboutUpdatesValueChanged:)
                        forControlEvents:UIControlEventValueChanged];
    
    [self updateTableViewDataSource];
    [self.tableView reloadData];
}


- (void)viewWillAppear:(BOOL)animated
{
    if ([UsersManager defaultManager].currentUser.isAdmin) {
        if (![_serverSettingsSection.items containsObject:_ledRow]) {
            [_serverSettingsSection.items addObject:_ledRow];
            [self.tableView reloadData];
        }
    } else {
        if ([_serverSettingsSection.items containsObject:_ledRow]) {
            [_serverSettingsSection.items removeObject:_ledRow];
            [self.tableView reloadData];
        }
    }
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


#pragma mark - Notifications

- (void)connectionHasChangedState:(NSNotification *)notification
{
    SMConnectionState connectionState = [[notification.userInfo objectForKey:kConnectionHasChangedStateNotificationNewStateKey] intValue];
    [self setServerSettingsStatus:connectionState];
}


- (void)userHasChangedSpreedMeModeNotif:(NSNotification *)notification
{
    BOOL spreedMeMode = [[notification.userInfo objectForKey:kApplicationModeKey] boolValue];
    [self updateUIWithOwnSpreedMode:!spreedMeMode];
}


#pragma mark - Utility methods

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


- (void)updateTableViewDataSource
{
    [_advancedSettingsSection.items removeAllObjects];
    if (self.spreedMeMode) {
        [_advancedSettingsSection.items addObject:_spreedMeModeRow];
        [_advancedSettingsSection.items addObject:_dataUsageRow];
        [_advancedSettingsSection.items addObject:_notifyAboutUpdatesRow];
        [_advancedSettingsSection.items addObject:_resetRow];
    } else {
        [_advancedSettingsSection.items addObject:_spreedMeModeRow];
        [_advancedSettingsSection.items addObject:_dataUsageRow];
        [_advancedSettingsSection.items addObject:_trustedSSLStoreRow];
        [_advancedSettingsSection.items addObject:_resetRow];
    }
    
    [_datasource removeAllObjects];
    if (self.spreedMeMode) {
        [_datasource addObject:_advancedSettingsSection];
    } else {
        [_datasource addObject:_serverSettingsSection];
        [_datasource addObject:_advancedSettingsSection];
    }
}


- (void)updateUIWithOwnSpreedMode:(BOOL)newMode
{
    self.spreedMeMode = !newMode;
    _ownSpreedModeSwitch.on = newMode;
    [self updateTableViewDataSource];
    
    [UIView transitionWithView:self.tableView
                      duration:0.35f
                       options:_ownSpreedModeSwitch.on ? UIViewAnimationOptionTransitionFlipFromTop : UIViewAnimationOptionTransitionFlipFromBottom
                    animations:^(void) { [self.tableView reloadData]; }
                    completion:NULL];
}


#pragma mark - Actions

- (void)changeServer:(NSString *)server
{
	self.serverURL = server;
	[[SMConnectionController sharedInstance] connectToNewServer:server];
}


- (void)disconnect
{
	[[SMConnectionController sharedInstance] disconnect];
}


- (void)connect
{
	[[SMConnectionController sharedInstance] reconnectToCurrentServer];
}


- (void)showAlertToResetSettings
{
    UIAlertView *resetAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"message_title_reset-app-warning",
																									   nil, [NSBundle mainBundle],
																									   @"WARNING!",
																									   @"Warning before reseting the app")
															 message:NSLocalizedStringWithDefaultValue(@"message_body_reset-app-warning",
																									   nil, [NSBundle mainBundle],
																									   @"Are you sure that you want to clean all data stored in your app?",
																									   @"Are you sure that you want to clean all data stored in your app?")
															delegate:self
												   cancelButtonTitle:kSMLocalStringCancelButton
												   otherButtonTitles:kSMLocalStringYESButton, nil];
    resetAlertView.tag = kSettingsViewControllerResetAlertViewTag;
    [resetAlertView show];
}


- (void)resetApplication
{
	// This will also restore default settings
	[self changeOwnSpreedModeTo:NO];
	
    // Since we will be switched to login view controller anyway there is no reason to pop animated.
    // Also this causes bug FS#2190. Probably because we do animated transition in one tab and simultaneously changing tab.
	[self.navigationController popToRootViewControllerAnimated:NO];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:UserHasResetApplicationNotification object:self];
}


- (void)restoreDefaultSettings
{
	[[SettingsController sharedInstance] resetSettings];
    [[TrustedSSLStore sharedTrustedStore] resetStore];
	
	// We assume that user can't restore settings during the call
//	[[PeerConnectionController sharedInstance]
//	 setVideoPreferencesWithCamera:[SettingsController sharedInstance].userSettings.video.deviceId
//				  videoFrameWidth:[SettingsController sharedInstance].userSettings.video.frameWidth
//				 videoFrameHeight:[SettingsController sharedInstance].userSettings.video.frameHeight
//							  FPS:[SettingsController sharedInstance].userSettings.video.fps];
}


- (void)askUserToChangeOwnSpreedModeWithNewMode:(BOOL)newMode
{
	NSString *alertTitle = NSLocalizedStringWithDefaultValue(@"message_title_change-app-mode-warning",
															 nil, [NSBundle mainBundle],
															 @"You are about to change application mode",
															 @"Warning before changing app mode");
	NSString *alertMessage = NSLocalizedStringWithDefaultValue(@"message_body_change-app-mode-warning",
															   nil, [NSBundle mainBundle],
															   @"All your chat and calls history will be wiped. Application settings will be reset to defaults. Confirm mode change:",
															   @"Explanation what happens during mode change.");
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:alertTitle
														message:alertMessage
													   delegate:self
											  cancelButtonTitle:kSMLocalStringCancelButton
											  otherButtonTitles:kSMLocalStringConfirmButton, nil];
	alertView.tag = kSettingsViewControllerSpreedMeModeAlertViewTag;
	
	_pendingOwnSpreedMode = newMode;
	
	[alertView show];

}


- (void)changeOwnSpreedModeTo:(BOOL)newMode
{
#warning: why do we even reset settings on mode change?
	// This should go first since it wipes defaults which are set later
	//[self restoreDefaultSettings];
	
	[SMConnectionController sharedInstance].spreedMeMode = !newMode;
}


- (void)userHasCanceledOwnSpreedModeChange
{
	_ownSpreedModeSwitch.on = !_pendingOwnSpreedMode;
}


#pragma mark - UI Actions

- (void)ownSpreedValueChanged:(id)sender
{
	[self askUserToChangeOwnSpreedModeWithNewMode:_ownSpreedModeSwitch.on];
}


- (void)notifyAboutUpdatesValueChanged:(UISwitch *)sender
{
    [SettingsController sharedInstance].shouldNotNotifyAboutNewApplicationVersion = !sender.on;
}


#pragma mark - ServerSettingsViewController delegate

- (void)serverSettingsViewController:(ServerSettingsViewController *)serverSettingsVC didChangeServerTo:(NSString *)newServer
{
	[self changeServer:newServer];
    NSUInteger serverSectionIndex = [_datasource indexOfObject:_serverSettingsSection];
    if (serverSectionIndex != NSNotFound) {
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:serverSectionIndex]] withRowAnimation:UITableViewRowAnimationFade];
    }
}


- (void)userHasPressedDisconnectInServerSettingsViewController:(ServerSettingsViewController *)serverSettingsVC
{
	[self disconnect];
}


- (void)userHasPressedConnectInServerSettingsViewController:(ServerSettingsViewController *)serverSettingsVC
{
	if ([SMConnectionController sharedInstance].connectionState == kSMConnectionStateDisconnected) {
		[self connect];
	}
}


#pragma mark - SSLCertificatesListViewController delegate

- (void)SSLCertificatesListViewController:(SSLCertificatesListViewController *)controller didRemoveCertificateAtIndex:(NSInteger)index
{
	if (index < [[TrustedSSLStore sharedTrustedStore].trustedCertificates count]) {
		[[TrustedSSLStore sharedTrustedStore] removeTrustedCertificate:[[TrustedSSLStore sharedTrustedStore].trustedCertificates objectAtIndex:index]];
	}
}


#pragma mark - Pushing ServerSettings and DataUsage Controllers

- (void)pushServerSettingsViewControllerAnimated:(BOOL)animated
{
    ServerSettingsViewController *serverSettingsVC = [[ServerSettingsViewController alloc] initWithServer:self.serverURL];
    
    if ([SMConnectionController sharedInstance].ownCloudMode) {
        serverSettingsVC = [[ServerSettingsViewController alloc] initWithServer:[SMConnectionController sharedInstance].currentOwnCloudServer];
    }
    
    self.serverSettingsVC = serverSettingsVC;
    self.serverSettingsVC.delegate = self;
    [self setServerSettingsStatus:[SMConnectionController sharedInstance].connectionState];
    [self.navigationController pushViewController:serverSettingsVC animated:animated];
}


- (void)pushLedControlViewControllerAnimated:(BOOL)animated
{
    SMLedControlViewController *ledControlVC = [[SMLedControlViewController alloc] initWithNibName:@"SMLedControlViewController" bundle:nil];
    [self.navigationController pushViewController:ledControlVC animated:animated];
}


- (void)presentServerSettingsViewController
{
    [self pushServerSettingsViewControllerAnimated:NO];
}


- (void)setServerSettingsStatus:(SMConnectionState)connectionState
{
    if (self.serverSettingsVC) {
        switch (connectionState) {
            case kSMConnectionStateDisconnected:
                self.serverSettingsVC.serverSetupStatus = kServerSetupStatusDisconnected;
                break;
                
            case kSMConnectionStateConnecting:
                self.serverSettingsVC.serverSetupStatus = kServerSetupStatusConnecting;
                break;
                
            case kSMConnectionStateConnected:
                self.serverSettingsVC.serverSetupStatus = kServerSetupStatusConnected;
                break;
                
            default:
                break;
        }
    }
}


- (void)pushDataUsageViewController
{
    DataUsageViewController *dataUsageVC = [[DataUsageViewController alloc] initWithNibName:@"DataUsageViewController" bundle:nil];
    [self.navigationController pushViewController:dataUsageVC animated:YES];
}


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *row = [sectionModel.items objectAtIndex:indexPath.row];
    
    switch (sectionModel.type) {
        case kSMSVCSAdvancedSettings:
            switch (row.type) {
                case kSMAdvancedSectionSpreedMeMode:
                    // Didselect should not do anything here
                    break;
                    
                case kSMAdvancedSectionDataUsage:
                    [self pushDataUsageViewController];
                    break;
                    
                case kSMAdvancedSectionReset:
                    [self showAlertToResetSettings];
                    break;
                case kSMAdvancedSectionTrustedSSLStore:
                {
                    SSLCertificatesListViewController *certListVC = [[SSLCertificatesListViewController alloc] initWithCertificateList:[TrustedSSLStore sharedTrustedStore].trustedCertificates];
                    certListVC.delegate = self;
                    
                    [self.navigationController pushViewController:certListVC animated:YES];
                }
                    break;
                    
                default:
                    break;
            }
        break;
        
        case kSMSVCSServerSettings:
            switch (row.type) {
                case kSMServerSectionServer:
                    [self pushServerSettingsViewControllerAnimated:YES];
                break;
                    
                case kSMServerSectionLED:
                    [self pushLedControlViewControllerAnimated:YES];
                    break;
                default:
                break;
            }
        break;
            
        default:
            break;
    }
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
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
	
	static NSString *settingsCellIdentifier = @"settingsCellIdentifier";
   
    
    cell = [tableView dequeueReusableCellWithIdentifier:settingsCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:settingsCellIdentifier];
    }
    
    
    // Since we use only one cell type/identifier we should reset them (we are to lazy to implement custom cell class with prepareForReuse:)
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    
    
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *row = [sectionModel.items objectAtIndex:indexPath.row];
    
    
    switch (sectionModel.type) {
        case kSMSVCSServerSettings:
        {
            cell.textLabel.text = row.title;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        break;
        case kSMSVCSAdvancedSettings:
        {
            cell.textLabel.text = row.title;
            switch (row.type) {
                case kSMAdvancedSectionSpreedMeMode:
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.accessoryView = _ownSpreedModeSwitch;
                break;
                case kSMAdvancedSectionNotifyAboutUpdates:
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.accessoryView = _notifyAboutUpdatesSwitch;
                break;
                case kSMAdvancedSectionReset:
                    cell.accessoryType = UITableViewCellAccessoryNone;
                break;
                    
                default:
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            }
        }
        break;
        
        default:
        break;
    }
    
    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        cell.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
    }

    cell.textLabel.textColor = kSMBuddyCellTitleColor;
	
	return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	STSectionModel *sectionModel = _datasource[section];
	return sectionModel.title;
}


#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(alertView.tag == kSettingsViewControllerResetAlertViewTag) {
        if (buttonIndex == 1)
        {
            [self resetApplication];
        }
    } else if(alertView.tag == kSettingsViewControllerSpreedMeModeAlertViewTag) {
        if (buttonIndex == 1)
        {
            [self changeOwnSpreedModeTo:_pendingOwnSpreedMode];
			
        } else if (buttonIndex == alertView.cancelButtonIndex) {
			[self userHasCanceledOwnSpreedModeChange];
		}
    }
}


@end
