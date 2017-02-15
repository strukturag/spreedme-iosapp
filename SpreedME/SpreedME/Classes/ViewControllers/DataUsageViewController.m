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

#import "DataUsageViewController.h"

#import "DetailedDataUsageViewController.h"
#import "SMConnectionController.h"
#import "SMLocalizedStrings.h"


@interface DataUsageViewController () <UITableViewDataSource, UITableViewDelegate>
{
    NSTimer *_refreshValuesTimer;
}

@property (nonatomic, strong) IBOutlet UITableView *dataUsageTableView;

@property (nonatomic, assign) STByteCount dataUsageSentBytes;
@property (nonatomic, assign) STByteCount dataUsageReceivedBytes;
@property (nonatomic, assign) STByteCount dataUsageTotalBytes;

@end

@implementation DataUsageViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
		self.title = kSMLocalStringDataUsageLabel;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.view.backgroundColor = kGrayColor_e5e5e5;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.dataUsageTableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.dataUsageTableView.backgroundView = nil;
    }
    
    self.dataUsageTableView.scrollEnabled = NO;
}


- (void)viewWillAppear:(BOOL)animated
{
    [self refreshDataUsageValues];
    
    _refreshValuesTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerTicked:) userInfo:nil repeats:YES];
}


- (void)viewWillDisappear:(BOOL)animated
{
    [_refreshValuesTimer invalidate];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Timers

- (void)timerTicked:(NSTimer*)timer
{
    [self refreshDataUsageValues];
}


#pragma mark - Utils


- (void)refreshDataUsageValues
{
    self.dataUsageSentBytes = [[SMConnectionController sharedInstance].ndController sentByteCountForAllServices];
    self.dataUsageReceivedBytes = [[SMConnectionController sharedInstance].ndController receivedByteCountForAllServices];
    self.dataUsageTotalBytes = [[SMConnectionController sharedInstance].ndController totalByteCountForAllServices];
    
    [self.dataUsageTableView reloadData];
}


- (void)cleanDataUsageValues
{
    [[SMConnectionController sharedInstance].ndController resetStatistics];
    [self refreshDataUsageValues];
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


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
            
        case kDataUsageSectionTypes:
        {
            if (![SMConnectionController sharedInstance].spreedMeMode) {
                DetailedDataUsageViewController *detailedDataUsageVC = [[DetailedDataUsageViewController alloc]initWithDataUsageType:indexPath.row];
                [self.navigationController pushViewController:detailedDataUsageVC animated:YES];
            }
        }
            break;
            
        case kDataUsageSectionOptions:
        {
            [self cleanDataUsageValues];
        }
            break;
            
        default:
            break;
    }
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}


#pragma mark - UITableView Datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows = 0;
    
    switch (section) {
            
        case kDataUsageSectionTypes:
            numberOfRows = kDataUsageTypesCount;
            break;
            
        case kDataUsageSectionOptions:
            numberOfRows = 1;
            break;
			
        default:
			break;
    }
    
	return numberOfRows;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return kDataUsageSectionsCount;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = nil;
	
	static NSString *SentDataCellIdentifier = @"SentDataCellIdentifier";
	static NSString *ReceivedDataCellIdentifier = @"ReceivedDataCellIdentifier";
    static NSString *TotalDataCellIdentifier = @"TotalDataCellIdentifier";
	static NSString *ClearDataCellIdentifier = @"ClearDataCellIdentifier";
	
	switch (indexPath.section) {
		case kDataUsageSectionTypes:
		{
            switch (indexPath.row) {
                case kDataUsageTypeSent:
                    cell = [tableView dequeueReusableCellWithIdentifier:SentDataCellIdentifier];
                    if (!cell) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:SentDataCellIdentifier];
                    }
                    
                    cell.textLabel.text = NSLocalizedStringWithDefaultValue(@"label_sent-data",
																			nil, [NSBundle mainBundle],
																			@"Sent data",
																			@"Sent data. Sent as adjective.");
                    cell.detailTextLabel.text = [self calculateBytesStringFromSTByteCount:self.dataUsageSentBytes];
                    break;
                
                case kDataUsageTypeReceived:
                    cell = [tableView dequeueReusableCellWithIdentifier:ReceivedDataCellIdentifier];
                    if (!cell) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:ReceivedDataCellIdentifier];
                    }
                    
                    cell.textLabel.text = NSLocalizedStringWithDefaultValue(@"label_received-data",
																			nil, [NSBundle mainBundle],
																			@"Received data",
																			@"Received data. Received as adjective.");
                    cell.detailTextLabel.text = [self calculateBytesStringFromSTByteCount:self.dataUsageReceivedBytes];
                    break;
                    
                case kDataUsageTypeTotal:
                    cell = [tableView dequeueReusableCellWithIdentifier:TotalDataCellIdentifier];
                    if (!cell) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:TotalDataCellIdentifier];
                    }
                    
                    cell.textLabel.text = NSLocalizedStringWithDefaultValue(@"label_total-data",
																			nil, [NSBundle mainBundle],
																			@"Total data",
																			@"Total data. Total as adjective");
                    cell.detailTextLabel.text = [self calculateBytesStringFromSTByteCount:self.dataUsageTotalBytes];
                    break;
                    
                default:
                    break;
            }
            
            if ([SMConnectionController sharedInstance].spreedMeMode) {
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
		}
            break;
            
		case kDataUsageSectionOptions:
		{
            cell = [tableView dequeueReusableCellWithIdentifier:ClearDataCellIdentifier];
			if (!cell) {
				cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ClearDataCellIdentifier];
			}
			
			cell.textLabel.text = NSLocalizedStringWithDefaultValue(@"button_clean-data",
																	nil, [NSBundle mainBundle],
																	@"Clean data",
																	@"Clean data. Clean as a verb.");
		}
            break;
            
		default:
            break;
	}
    
	if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        cell.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
    }
    
	return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	NSString *title = nil;
	return title;
}


#pragma mark - Byte calculation

- (NSString *)calculateBytesStringFromSTByteCount:(STByteCount)byteCount
{
	NSString *bytesString = kSMLocalStringNoDataLabel;
    
    if (STIsByteCountValid(byteCount)) {
        bytesString = [NSByteCountFormatter stringFromByteCount:byteCount.bytes countStyle:NSByteCountFormatterCountStyleBinary];
    }
    
    return bytesString;
}

@end
