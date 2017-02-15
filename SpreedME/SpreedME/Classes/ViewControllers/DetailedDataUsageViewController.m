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

#import "DetailedDataUsageViewController.h"

#import "SMConnectionController.h"
#import "SMLocalizedStrings.h"

@interface DetailedDataUsageViewController () <UITableViewDataSource, UITableViewDelegate>
{
    NSMutableArray *_services;
    kDataUsageTypes _dataUsageType;
    NSTimer *_refreshValuesTimer;
}

@property (nonatomic, strong) IBOutlet UITableView *detailedDataUsageTableView;

@end

@implementation DetailedDataUsageViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


- (id)initWithDataUsageType:(kDataUsageTypes) dataUsageType
{
    self = [super initWithNibName:@"DetailedDataUsageViewController" bundle:nil];
    if (self) {
        NSString *title = nil;
        
        switch (dataUsageType) {
            case kDataUsageTypeSent:
                title = NSLocalizedStringWithDefaultValue(@"screen_title_sent",
														  nil, [NSBundle mainBundle],
														  @"Sent",
														  @"Sent");
                break;
                
            case kDataUsageTypeReceived:
				title = NSLocalizedStringWithDefaultValue(@"screen_title_received",
														  nil, [NSBundle mainBundle],
														  @"Received",
														  @"Received");
                break;
                
            case kDataUsageTypeTotal:
				title = NSLocalizedStringWithDefaultValue(@"screen_title_total",
														  nil, [NSBundle mainBundle],
														  @"Total",
														  @"Total");
                break;
                
            default:
                break;
        }
        self.title = title;
    }
    
    _dataUsageType = dataUsageType;
    
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
        self.detailedDataUsageTableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.detailedDataUsageTableView.backgroundView = nil;
    }
    
    self.detailedDataUsageTableView.scrollEnabled = NO;
    
    _services = [NSMutableArray arrayWithArray:[[[SMConnectionController sharedInstance].ndController servicesNames] allObjects]];
}


- (void)viewWillAppear:(BOOL)animated
{
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
    [self.detailedDataUsageTableView reloadData];    
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


#pragma mark - UITableView Datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [_services count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DetailedDataUsageCellIdentifier"];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"DetailedDataUsageCellIdentifier"];
    }
    
    NSString *serviceName = [_services objectAtIndex:indexPath.row];
    STByteCount byteCountForService = STByteCountMakeInvalid();
    
    switch (_dataUsageType) {
        case kDataUsageTypeSent:
            byteCountForService = [[SMConnectionController sharedInstance].ndController sentByteCountForServiceName:serviceName];
            break;
            
        case kDataUsageTypeReceived:
            byteCountForService = [[SMConnectionController sharedInstance].ndController receivedByteCountForServiceName:serviceName];
            break;
            
        case kDataUsageTypeTotal:
            byteCountForService = [[SMConnectionController sharedInstance].ndController totalByteCountForServiceName:serviceName];
            break;
            
        default:
            break;
    }
    
    cell.textLabel.text = serviceName;
    cell.detailTextLabel.text = [self calculateBytesStringFromSTByteCount:byteCountForService];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        cell.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
    }
    
	return cell;
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
