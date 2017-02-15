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

#import "VideoOptionsViewController.h"

#import "SMLocalizedStrings.h"
#import "STSectionModel.h"
#import "STRowModel.h"


typedef enum : NSUInteger {
    kVideoOptionsTableViewSectionCamera = 0,
    kVideoOptionsTableViewSectionQuality,
    kVideoOptionsTableViewSectionFPS
} VideoOptionsTableViewSections;


@interface VideoOptionsViewController ()
{
    STSectionModel *_cameraSection;
    STSectionModel *_qualitySection;
    STSectionModel *_fpsSection;
    NSMutableArray *_dataSource;
}

@property (nonatomic, strong) NSArray *videoDevices;
@property (nonatomic, strong) NSArray *videoQualities;
@property (nonatomic, strong) NSArray *videoFPS;
@property (nonatomic, strong) NSMutableArray *videoConfigurationArray;

@property (nonatomic, strong) IBOutlet UITableView *videoSettingsTableView;

@end

@implementation VideoOptionsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = kSMLocalStringVideoLabel;
        
        _cameraSection = [STSectionModel new];
        _cameraSection.type = kVideoOptionsTableViewSectionCamera;
        _cameraSection.title = NSLocalizedStringWithDefaultValue(@"label_camera",
                                                                 nil, [NSBundle mainBundle],
                                                                 @"Camera",
                                                                 @"Camera (recording device)");
        
        _qualitySection = [STSectionModel new];
        _qualitySection.type = kVideoOptionsTableViewSectionQuality;
        _qualitySection.title = NSLocalizedStringWithDefaultValue(@"label_video-quality",
                                                                  nil, [NSBundle mainBundle],
                                                                  @"Video quality",
                                                                  @"Video quality");
        _fpsSection = [STSectionModel new];
        _fpsSection.type = kVideoOptionsTableViewSectionFPS;
        _fpsSection.title = NSLocalizedStringWithDefaultValue(@"label_fps",
                                                              nil, [NSBundle mainBundle],
                                                              @"FPS",
                                                              @"FPS=Frames per second.");
        
        _dataSource = [NSMutableArray new];
        [_dataSource addObject:_cameraSection];
        [_dataSource addObject:_qualitySection];
        [_dataSource addObject:_fpsSection];
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	
	if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    [self.view setBackgroundColor:kGrayColor_e5e5e5];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.videoSettingsTableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.videoSettingsTableView.backgroundView = nil;
    }
    
    [self setFirstVideoConfiguration];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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


#pragma mark -

- (void)setFirstVideoConfiguration
{
    self.videoConfigurationArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < [_dataSource count]; i++) {
        [self.videoConfigurationArray addObject:@(0)];
    }
    [self setCameraSection];
    [self setFPSSection];
}

- (void)setCameraSection
{
    if (self.datasource && [self.datasource respondsToSelector:@selector(videoDevicesForVideoOptionsViewController:)]) {
        self.videoDevices = [self.datasource videoDevicesForVideoOptionsViewController:self];
    }
    
    SMVideoDevice *videoDevice = nil;
    NSInteger userPreferedDeviceRowIndex = [_videoDevices count] - 1;
    
    for (NSUInteger devNum = 0; devNum < [self.videoDevices count]; devNum++) {
        videoDevice = [self.videoDevices objectAtIndex:devNum];
        if ([self.userVideoSettings.deviceId isEqualToString:videoDevice.deviceId]) {
            userPreferedDeviceRowIndex = devNum;
        }
        STRowModel *row = [STRowModel new];
        row.title = videoDevice.deviceLocalizedName;
        [_cameraSection.items addObject:row];
    }
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:userPreferedDeviceRowIndex inSection:kVideoOptionsTableViewSectionCamera];
    [self.videoConfigurationArray replaceObjectAtIndex:indexPath.section withObject:@(indexPath.row)];
    
    [self.videoSettingsTableView reloadSections:[NSIndexSet indexSetWithIndex:[_dataSource indexOfObject:_cameraSection]]
                               withRowAnimation:UITableViewRowAnimationAutomatic];
    
    [self setVideoQualitySection:[_videoDevices objectAtIndex:userPreferedDeviceRowIndex]];
}


- (void)setFPSSection
{
    self.videoFPS = [[NSArray alloc]initWithObjects:@"10",@"20",@"30", NSLocalizedStringWithDefaultValue(@"label_video-settings_auto",
                                                                                                         nil, [NSBundle mainBundle],
                                                                                                         @"auto",
                                                                                                         @"I believe it should be kept lowercase."), nil];
    for (NSUInteger fpsNum = 0; fpsNum < [self.videoFPS count]; fpsNum++) {
        STRowModel *row = [STRowModel new];
        row.title = [self.videoFPS objectAtIndex:fpsNum];
        [_fpsSection.items addObject:row];
    }
    
    NSInteger userPreferedFPSRowIndex = [_videoFPS count] - 1;
    switch (self.userVideoSettings.fps) {
        case 10:
            userPreferedFPSRowIndex = 0;
            break;
        case 20:
            userPreferedFPSRowIndex = 1;
            break;
        case 30:
            userPreferedFPSRowIndex = 2;
            break;
        default:
            userPreferedFPSRowIndex = 3;
            break;
    }
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:userPreferedFPSRowIndex inSection:kVideoOptionsTableViewSectionFPS];
    [self.videoConfigurationArray replaceObjectAtIndex:indexPath.section withObject:@(indexPath.row)];
    
    [self.videoSettingsTableView reloadSections:[NSIndexSet indexSetWithIndex:[_dataSource indexOfObject:_fpsSection]]
                               withRowAnimation:UITableViewRowAnimationAutomatic];
}


- (void)setVideoQualitySection:(SMVideoDevice *)videoDevice
{
    if (self.datasource && [self.datasource respondsToSelector:@selector(videoOptionsViewController:videoDeviceCapabilitiesForDevice:)]) {
		self.videoQualities = [self.datasource videoOptionsViewController:self videoDeviceCapabilitiesForDevice:videoDevice];
	}
    
    NSInteger userPreferedVQRowIndex = [_videoQualities count] - 1;
    SMVideoDeviceCapability *videoDeviceCapability;
    NSString *videQualityName;
    
    [_qualitySection.items removeAllObjects];
    
    for (NSInteger devNum = 0; devNum < [self.videoQualities count]; devNum++) {
        videoDeviceCapability = [self.videoQualities objectAtIndex:devNum];
        if (self.userVideoSettings.frameHeight == videoDeviceCapability.videoFrameHeight) {
            userPreferedVQRowIndex = devNum;
        }
		
        switch (videoDeviceCapability.videoFrameHeight) {
            case 288:
				videQualityName = NSLocalizedStringWithDefaultValue(@"label_video-settings_low-quality-short",
																	nil, [NSBundle mainBundle],
																	@"Low",
																	@"Translation should be the same as label_video-settings_low-quality but shortened.");
                break;
                
            case 480:
				videQualityName = NSLocalizedStringWithDefaultValue(@"label_video-settings_high-quality-short",
																	nil, [NSBundle mainBundle],
																	@"High",
																	@"Translation should be the same as label_video-settings_high-quality but shortened.");
                break;
                
            case 720:
				videQualityName = NSLocalizedStringWithDefaultValue(@"label_video-settings_720p-quality-short",
																	nil, [NSBundle mainBundle],
																	@"HD",
																	@"Probably should left as HD but maybe some languages use ohter idiom.");
                break;
                
            case 1080:
				videQualityName = NSLocalizedStringWithDefaultValue(@"label_video-settings_1080p-quality-short",
																	nil, [NSBundle mainBundle],
																	@"Full HD",
																	@"Probably should left as Full HD but maybe some languages use ohter idiom.");
                break;
                
            default:
                break;
        }
        STRowModel *row = [STRowModel new];
        row.title = videQualityName;
        [_qualitySection.items addObject:row];
    }
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:userPreferedVQRowIndex inSection:kVideoOptionsTableViewSectionQuality];
    [self.videoConfigurationArray replaceObjectAtIndex:indexPath.section withObject:@(indexPath.row)];
    
    [self.videoSettingsTableView reloadSections:[NSIndexSet indexSetWithIndex:[_dataSource indexOfObject:_qualitySection]]
                               withRowAnimation:UITableViewRowAnimationAutomatic];
}


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _dataSource[indexPath.section];
    
    if ([[_videoConfigurationArray objectAtIndex:indexPath.section] integerValue] != indexPath.row) {
        
        [self.videoConfigurationArray replaceObjectAtIndex:indexPath.section withObject:@(indexPath.row)];
        
        switch (sectionModel.type) {
            case kVideoOptionsTableViewSectionCamera:
            {
                SMVideoDevice *videoDevice = [_videoDevices objectAtIndex:[[_videoConfigurationArray objectAtIndex:kVideoOptionsTableViewSectionCamera] integerValue]];
                self.userVideoSettings.deviceId = videoDevice.deviceId;
                
                [self setVideoQualitySection:[_videoDevices objectAtIndex:indexPath.row]];
                SMVideoDeviceCapability *capability = [_videoQualities objectAtIndex:[[_videoConfigurationArray objectAtIndex:kVideoOptionsTableViewSectionQuality] integerValue]];
                self.userVideoSettings.frameHeight = capability.videoFrameHeight;
                self.userVideoSettings.frameWidth = capability.videoFrameWidth;
            }
                break;
                
            case kVideoOptionsTableViewSectionQuality:
            {
                SMVideoDeviceCapability *capability = [_videoQualities objectAtIndex:[[_videoConfigurationArray objectAtIndex:kVideoOptionsTableViewSectionQuality] integerValue]];
                self.userVideoSettings.frameHeight = capability.videoFrameHeight;
                self.userVideoSettings.frameWidth = capability.videoFrameWidth;
            }
                break;
                
            case kVideoOptionsTableViewSectionFPS:
            {
                self.userVideoSettings.fps = [[_videoFPS objectAtIndex:[[_videoConfigurationArray objectAtIndex:kVideoOptionsTableViewSectionFPS] integerValue]] integerValue];
            }
                break;
                
            default:
                break;
        }
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoOptionsViewController:hasSetVideoSettings:)]) {
            [self.delegate videoOptionsViewController:self hasSetVideoSettings:self.userVideoSettings];
        }
        
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                 withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
    [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:NO];
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _dataSource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    return rowModel.rowHeight;
}


#pragma mark - UITableView Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _dataSource.count;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows = 0;
    
    STSectionModel *sectionModel = _dataSource[section];
    
    numberOfRows = sectionModel.items.count;
    
    return numberOfRows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    static NSString *CameraCellIdentifier = @"CameraCellIdentifier";
    static NSString *QualityCellIdentifier = @"QualityCellIdentifier";
    static NSString *FPSCellIdentifier = @"FPSCellIdentifier";
    
    
    STSectionModel *sectionModel = _dataSource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    switch (sectionModel.type) {
        case kVideoOptionsTableViewSectionCamera:
        {
            cell = [tableView dequeueReusableCellWithIdentifier:CameraCellIdentifier];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CameraCellIdentifier];
            }
            
            cell.textLabel.text = rowModel.title;
        }
            break;
            
        case kVideoOptionsTableViewSectionQuality:
        {
            cell = [tableView dequeueReusableCellWithIdentifier:QualityCellIdentifier];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:QualityCellIdentifier];
            }
            
            cell.textLabel.text = rowModel.title;
        }
            break;
            
        case kVideoOptionsTableViewSectionFPS:
        {
            cell = [tableView dequeueReusableCellWithIdentifier:FPSCellIdentifier];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:FPSCellIdentifier];
            }
            
            cell.textLabel.text = rowModel.title;
        }
            break;
            
        default:
            break;
    }
    
    if ([[_videoConfigurationArray objectAtIndex:indexPath.section] integerValue] == indexPath.row) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    cell.textLabel.textColor = kSMBuddyCellTitleColor;
    
    return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    STSectionModel *sectionModel = _dataSource[section];
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
