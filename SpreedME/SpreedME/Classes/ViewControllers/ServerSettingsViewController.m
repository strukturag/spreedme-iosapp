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

#import "ServerSettingsViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "SpreedMeRoundedButton.h"
#import "SettingsController.h"
#import "SMLocalizedStrings.h"
#import "STSectionModel.h"
#import "STRowModel.h"
#import "STServerSetupTableViewCell.h"
#import "UsersManager.h"


typedef enum : NSUInteger {
    kServerSettingsSectionConfiguration = 0,
    kServerSettingsSectionHistory,
    kOptionsTableViewSectionCount
} ServerSettingsSections;


typedef enum : NSInteger {
    kSCSRServerURL = 0,
    kSCSRConnectButton,
} ServerConfigurationSectionRows;


@interface ServerSettingsViewController () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate, UserUpdatesProtocol>
{
    NSMutableArray *_datasource;
    STSectionModel *_serverConfigurationSection;
    STSectionModel *_serverHistorySection;
    
    //Server configuration section
    STRowModel *_serverURLRow;
    STRowModel *_connectButtonRow;
    
    
}

@property (nonatomic, strong) NSString *serverString;
@property (nonatomic, strong) UITextField *serverTextField;

@property (nonatomic, strong) IBOutlet UITableView *serverSettingsTableView;


@end

@implementation ServerSettingsViewController

#pragma mark - Object lifecycle

- (instancetype)initWithServer:(NSString *)server
{
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		_serverString = [server copy];
        
        _datasource = [[NSMutableArray alloc] init];
        
        // Profile Section
        _serverConfigurationSection = [STSectionModel new];
        _serverConfigurationSection.type = kServerSettingsSectionConfiguration;
#ifdef SPREEDME
        _serverConfigurationSection.title =  NSLocalizedStringWithDefaultValue(@"label_spreedbox-address",
                                                                               nil, [NSBundle mainBundle],
                                                                               @"Spreedbox address",
                                                                               @"Spreedbox address");
#else
        _serverConfigurationSection.title =  NSLocalizedStringWithDefaultValue(@"label_server-url",
                                                                               nil, [NSBundle mainBundle],
                                                                               @"Server URL",
                                                                               @"Server URL");
#endif
        _serverURLRow = [STRowModel new];
        _serverURLRow.type = kSCSRServerURL;
        _serverURLRow.rowHeight = [STServerSetupTableViewCell cellHeight];
        _connectButtonRow = [STRowModel new];
        _connectButtonRow.type = kSCSRConnectButton;
        _connectButtonRow.rowHeight = 44.0f;
        
        [_serverConfigurationSection.items addObject:_serverURLRow];
        [_serverConfigurationSection.items addObject:_connectButtonRow];
        
        [_datasource addObject:_serverConfigurationSection];
        
        self.serverSettingsTableView.scrollEnabled = NO;
    }
	
	return self;
}


- (void)dealloc
{
    _serverSettingsTableView.dataSource = nil;
    _serverSettingsTableView.delegate = nil;
    
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = kGrayColor_e5e5e5;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.serverSettingsTableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.serverSettingsTableView.backgroundView = nil;
    }
	
	if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
	
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
	tap.cancelsTouchesInView = NO;
	[self.view addGestureRecognizer:tap];
}


- (void)viewDidAppear:(BOOL)animated
{
    [self.serverTextField becomeFirstResponder];
}


- (void)viewDidLayoutSubviews
{
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


#pragma mark - Setters/Getters

- (void)setServerSetupStatus:(ServerSetupStatus)serverSetupStatus
{
	if (_serverSetupStatus != serverSetupStatus) {
		_serverSetupStatus = serverSetupStatus;
	}
    
    [self.serverSettingsTableView reloadData];
}


#pragma mark - UI Actions

- (IBAction)connectDisconnectButtonPressed:(id)sender
{
    switch (_serverSetupStatus) {
        case kServerSetupStatusDisconnected:
            [self changeServer:self.serverTextField.text];
            [self dismissKeyboard];
            break;
            
        case kServerSetupStatusConnecting:
            [self disconnect];
            break;
            
        case kServerSetupStatusConnected:
            [self disconnect];
            break;
            
        default:
            break;
    }
}


#pragma mark - Actions


- (void)changeServer:(NSString *)newServer
{
    self.serverString = newServer;
    [self.delegate serverSettingsViewController:self didChangeServerTo:newServer];
}


- (void)disconnect
{
    [SettingsController sharedInstance].ownCloudMode = NO;
    [SettingsController sharedInstance].lastConnectedUserId = nil;
    [SettingsController sharedInstance].lastConnectedOCUserPass = nil;
    [SettingsController sharedInstance].lastConnectedOCServer = nil;
    [SettingsController sharedInstance].lastConnectedOCSMServer = nil;
    
	[self.delegate userHasPressedDisconnectInServerSettingsViewController:self];
}


- (void)connect
{
	[self.delegate userHasPressedConnectInServerSettingsViewController:self];
}


- (void)dismissKeyboard
{
	[self.serverTextField resignFirstResponder];
}


#pragma mark - UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if (textField == self.serverTextField) {
		[textField resignFirstResponder];
		return YES;
	}
	
	return YES;
}


- (void)textFieldDidEndEditing:(UITextField *)textField
{
	[textField resignFirstResponder];
}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (_serverSetupStatus == kServerSetupStatusDisconnected) {
        return YES;
    }
    return NO;
}


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    switch (sectionModel.type) {
        case kServerSettingsSectionConfiguration:
        {
            switch (rowModel.type) {
                case kSCSRServerURL:
                    break;
                    
                case kSCSRConnectButton:
                {
                    [self connectDisconnectButtonPressed:nil];
                }
                    break;
            }
        }
            break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL answer = YES;
    
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    if ((sectionModel.type == kServerSettingsSectionConfiguration && rowModel.type == kSCSRServerURL)) {
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
    
    static NSString *ServerURLCellIdentifier = @"ServerURLCellIdentifier";
    static NSString *ConnectionStatusCellIdentifier = @"ConnectionStatusCellIdentifier";
    
    
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    switch (sectionModel.type) {
        case kServerSettingsSectionConfiguration:
        {
            switch (rowModel.type) {
                case kSCSRServerURL:
                {
                    STServerSetupTableViewCell *serverSetupCell = (STServerSetupTableViewCell *)[tableView dequeueReusableCellWithIdentifier:ServerURLCellIdentifier];
                    if (!serverSetupCell) {
                        serverSetupCell = [[STServerSetupTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ServerURLCellIdentifier];
                    }
                    
                    serverSetupCell.serverURLTextField.text = [_serverString copy];
#ifdef SPREEDME
                    serverSetupCell.serverURLTextField.placeholder = NSLocalizedStringWithDefaultValue(@"label_enter-spreedbox-address",
                                                                                                       nil, [NSBundle mainBundle],
                                                                                                       @"Enter the address of the Spreedbox",
                                                                                                       @"Placeholder of textfield for Spreedbox address");
#else
                    serverSetupCell.serverURLTextField.placeholder = NSLocalizedStringWithDefaultValue(@"label_enter-server-url",
                                                                                                       nil, [NSBundle mainBundle],
                                                                                                       @"Enter server URL",
                                                                                                       @"Placeholder of textfield for entering server url");
#endif
                    serverSetupCell.serverURLTextField.delegate = self;
                    self.serverTextField = serverSetupCell.serverURLTextField;
                    
                    
                    switch (_serverSetupStatus) {
                        case kServerSetupStatusDisconnected:
                            serverSetupCell.connectionStatus = kServerConnectionStatusDisconnected;
                            break;
                            
                        case kServerSetupStatusConnecting:
                            serverSetupCell.connectionStatus = kServerConnectionStatusConnecting;
                            break;
                        
                        case kServerSetupStatusConnected:
                            serverSetupCell.connectionStatus = kServerConnectionStatusConnected;
                            break;
                            
                        default:
                            break;
                    }
                    
                    cell = serverSetupCell;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                }
                    break;
                    
                case kSCSRConnectButton:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:ConnectionStatusCellIdentifier];
                    if (!cell) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ConnectionStatusCellIdentifier];
                    }
                    
                    switch (_serverSetupStatus) {
                        case kServerSetupStatusDisconnected:
                            cell.textLabel.text = kSMLocalStringConnectButton;
                            break;
                            
                        case kServerSetupStatusConnecting:
                            cell.textLabel.text = kSMLocalStringDisconnectButton;
                            break;
                            
                        case kServerSetupStatusConnected:
                            cell.textLabel.text = kSMLocalStringDisconnectButton;
                            break;
                            
                        default:
                            break;
                    }
                    
                    cell.textLabel.textColor = kSMBuddyCellTitleColor;
                    cell.textLabel.textAlignment = NSTextAlignmentCenter;
                    
                }
                    break;
            }
        }
            break;
    }
    
    cell.textLabel.textColor = kSMBuddyCellTitleColor;
    
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


@end
