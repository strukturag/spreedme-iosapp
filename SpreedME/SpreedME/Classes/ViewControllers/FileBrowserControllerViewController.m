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

#import "FileBrowserControllerViewController.h"

#import "FileSharingManagerObjC.h"
#import "SMLocalizedStrings.h"

@interface FileBrowserControllerViewController () <FileBrowserViewControllerDelegate, UIDocumentInteractionControllerDelegate>
{
	NSString *_directoryPath;
	NSMutableArray *_directoryContentsArray;
    
	UIDocumentInteractionController *_documentInteractionController;
}

@end

@implementation FileBrowserControllerViewController

- (id)initWithDirectoryPath:(NSString *)directoryPath
{
    self = [super initWithDirectoryPath:directoryPath];
    if (self) {
        _directoryPath = directoryPath;
		
		NSString *filesLocStr = NSLocalizedStringWithDefaultValue(@"tabbar-item_title_files",
																  nil, [NSBundle mainBundle],
																  @"Files",
																  @"This should be small enough to fit into tab. ~11 Latin symbols fit.");
		
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:filesLocStr image:[UIImage imageNamed:@"files_black"] tag:0];
		if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
			self.tabBarItem.selectedImage = [UIImage imageNamed:@"files_white"];
		} else {
			self.tabBarItem.selectedImage = [UIImage imageNamed:@"files_blue"];
		}
        
		self.navigationItem.title = filesLocStr;
        
        self.delegate = self;
        self.emptyDirectoryMessageText = NSLocalizedStringWithDefaultValue(@"message_no-files-in-this-directory",
																		   nil, [NSBundle mainBundle],
																		   @"There are no files in this directory.",
																		   @"There are no files in this directory.");
		
		self.noAppToOpenFileAlertTitle = nil;
		self.noAppToOpenFileAlertMessage = NSLocalizedStringWithDefaultValue(@"message_title_no-app-to-open-file",
																			 nil, [NSBundle mainBundle],
																			 @"We are sorry but you do not have any application that can open this file",
																			 @"We are sorry but you do not have any application that can open this file. User has no app installed which can handle the file.");
		self.noAppToOpenFileAlertOkButtonLabel = kSMLocalStringSadOKButton;
		
        
        [self.view setBackgroundColor:kGrayColor_e5e5e5];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileHasBeenDownloaded:) name:FileHasBeenDownloadedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasResetApp:) name:UserHasResetApplicationNotification object:nil];
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
    
    self.emptyDirectoryContainerView.backgroundColor = kGrayColor_e5e5e5;
    self.emptyDirectoryMessageLabel.font = [UIFont systemFontOfSize:kInformationTextFontSize];
    self.emptyDirectoryMessageLabel.textColor = kSMTableViewHeaderTextColor;
    
	[self populateDirectoryContentsArrayFromDirectoryAtPath:_directoryPath];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.tableView reloadData];
}


#pragma mark - Notifications


- (void)deleteAllFilesInDirectoryAtPath:(NSString *)directoryPath
{
	if ([directoryPath length] > 0) {
		NSError *error = nil;
		NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:&error];
		@autoreleasepool {
			for (NSString *itemName in contents) {
				NSError *deleteFileError = nil;
				BOOL success = [[NSFileManager defaultManager] removeItemAtPath:[directoryPath stringByAppendingPathComponent:itemName] error:&deleteFileError];
				if (!success || error) {
					spreed_me_log("Couldn't delete file on app reset %s", [itemName cStringUsingEncoding:NSUTF8StringEncoding]);
				}
			}
		}
	}
}


- (void)fileHasBeenDownloaded:(NSNotification *)notification
{
	NSString *filePath = [notification.userInfo objectForKey:kFilePathUserInfoKey];

	NSString *fileDirectory = [filePath stringByDeletingLastPathComponent];
	
	if ([self checkIfDirectory:fileDirectory isEqualToDirectory:_directoryPath]) {
		[self populateDirectoryContentsArrayFromDirectoryAtPath:_directoryPath];
		[self.tableView reloadData];
	}
}


- (void)userHasResetApp:(NSNotification *)notification
{
	[self deleteAllFilesInDirectoryAtPath:_directoryPath];
	[self populateDirectoryContentsArrayFromDirectoryAtPath:_directoryPath];
	[self.tableView reloadData];
}


#pragma mark - FileBrowserViewController Delegate

- (void)fileBrowser:(STFileBrowserViewController *)fileBrowser didPickFileAtPath:(NSString *)path
{

}


- (BOOL)fileBrowser:(STFileBrowserViewController *)fileBrowser shouldPresentDocumentsControllerForFileAtPath:(NSString *)path
{
    return YES;
}


#pragma mark - Utils

- (void)selectFileWithName:(NSString *)fileName
{
	if ([fileName length] > 0) {
	
		NSURL *url = [NSURL fileURLWithPathComponents:@[[[FileSharingManagerObjC defaultManager] fileLocation], fileName]];
		
		if (!_documentInteractionController) {
			_documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:url];
		}
		_documentInteractionController.URL = url;
		_documentInteractionController.delegate = self;
		
		BOOL canPreview = [_documentInteractionController presentPreviewAnimated:YES];
		
		if (!canPreview) {
			BOOL canShowActions = [_documentInteractionController presentOpenInMenuFromRect:self.view.frame inView:self.view animated:YES];
			if (!canShowActions) {
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.noAppToOpenFileAlertTitle
																message:self.noAppToOpenFileAlertMessage
															   delegate:nil
													  cancelButtonTitle:self.noAppToOpenFileAlertOkButtonLabel
													  otherButtonTitles:nil];
				
				[alert show];
			}
		}
	}
}


#pragma mark - Public methods

- (void)tryToOpenFileName:(NSString *)fileName recursive:(BOOL)recursive
{
	if ([fileName length] > 0) {
		NSUInteger fileIndex = [_directoryContentsArray indexOfObject:fileName];
		if (fileIndex != NSNotFound) {
			NSIndexPath *fileIndexPath = [NSIndexPath indexPathForRow:fileIndex inSection:0];
			//TODO: This has minor issue. If VC view is not loaded corresponding row will not be selected.
			[self.tableView selectRowAtIndexPath:fileIndexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle];
			[self selectFileWithName:fileName];
		}
	}
}


#pragma mark - UIDocumentInteractionControllerDelegate

- (UIViewController *) documentInteractionControllerViewControllerForPreview: (UIDocumentInteractionController *) controller
{
    return self;
}


@end
