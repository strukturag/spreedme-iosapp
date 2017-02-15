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

#import "STChatFileTableViewCell.h"

const CGFloat kSTChatSharingExplanationTextViewHeight	= 24.0f;
const CGFloat kSTChatFileIconHeight						= 20.0f;
const CGFloat kSTChatFileIconWidth						= kSTChatFileIconHeight;
const CGFloat kSTChatFileNameLabelHeight				= 20.0f;
const CGFloat kSTChatFileDownloadProgressViewHeight		= 9.0f;

const CGFloat kSTChatDownloadFileButtonHeight			= 44.0f;
const CGFloat kSTChatDownloadFileButtonWidth			= kSTChatDownloadFileButtonHeight;

const CGFloat kSTChatDownloadFileWellViewHeight			= 54.0f;

const CGFloat kSTChatFileSizeLabelWidth					= 120.0f;

typedef enum : NSUInteger {
	kSTChatDownloadFileCellUIStateNotSet = 0,
    kSTChatDownloadFileCellUIStateUploadFileInactive,
    kSTChatDownloadFileCellUIStateUploadFileActive,
	kSTChatDownloadFileCellUIStateUploadFileCanceled,
    kSTChatDownloadFileCellUIStateDownloadFileInactive,
	kSTChatDownloadFileCellUIStateDownloadFileActive,
	kSTChatDownloadFileCellUIStateDownloadFileFinished,
	kSTChatDownloadFileCellUIStateDownloadFileCanceled,
} STChatDownloadFileCellUIState;


@interface STChatFileTableViewCell ()
{
	id<STChatFileTableViewCellDelegate> _delegate;
	NSInteger _cellIndex;
}

@property (nonatomic, strong) UIImageView *fileIconImageView;
@property (nonatomic, strong) UITextView *sharingExplanationTextView;
@property (nonatomic, strong) UILabel *fileNameLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *fileSizeLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIView *wellView;

@property (nonatomic, strong) STFontAwesomeRoundedButton *fileTransferControlButton;


@property (nonatomic, assign) STChatDownloadFileCellUIState uiState;

@end



@implementation STChatFileTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
		
		_cellIndex = -1;
		
		self.wellView = [[UIView alloc] initWithFrame:CGRectZero];
		self.wellView.layer.cornerRadius = kViewCornerRadius;
		self.wellView.layer.borderColor = [UIColor blackColor].CGColor;
		self.wellView.layer.borderWidth = 0.5f;
		
		self.sharingExplanationTextView = [[UITextView alloc] initWithFrame:CGRectZero];
		self.sharingExplanationTextView.backgroundColor = [UIColor clearColor];
		self.sharingExplanationTextView.font = [UIFont systemFontOfSize:14.0f];
        self.sharingExplanationTextView.scrollEnabled = NO;
        self.sharingExplanationTextView.editable = NO;
		
        //Workaround to align text with delivery status
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
            self.sharingExplanationTextView.contentInset = UIEdgeInsetsMake(-4, 0, 0, 0);
        } else {
            self.sharingExplanationTextView.contentInset = UIEdgeInsetsMake(-6, 0, 0, 0);
        }
		
		self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
		self.progressView.progressTintColor = [UIColor blueColor];
		
		UIImage *progressImage = [[UIImage imageNamed:@"pr_ind_for"] resizableImageWithCapInsets:UIEdgeInsetsMake(1, 4, 1, 4) resizingMode:UIImageResizingModeStretch];
		UIImage *trackImage = [[UIImage imageNamed:@"pr_ind_back"] resizableImageWithCapInsets:UIEdgeInsetsMake(1, 4, 1, 4) resizingMode:UIImageResizingModeStretch];
		
		self.progressView.progressImage = progressImage;
		self.progressView.trackImage = trackImage;
		
//		self.fileIconImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
		
		self.fileNameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.fileNameLabel.backgroundColor = [UIColor clearColor];
		self.fileNameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
		self.fileNameLabel.font = [UIFont systemFontOfSize:16.0f];
		self.fileNameLabel.textAlignment = NSTextAlignmentCenter;
		
		self.fileSizeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.fileSizeLabel.backgroundColor = [UIColor clearColor];
		self.fileSizeLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
		self.fileSizeLabel.font = [UIFont systemFontOfSize:16.0f];
		self.fileSizeLabel.textAlignment = NSTextAlignmentCenter;
	
		self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		
		self.fileTransferControlButton = [STFontAwesomeRoundedButton buttonWithType:UIButtonTypeCustom];
		[self.fileTransferControlButton setTitleWithIcon:FADownload forState:UIControlStateNormal];
		[self.fileTransferControlButton setBackgroundColor:kSTChatFileTVCBlueButtonColor forState:UIControlStateNormal];
        [self.fileTransferControlButton setBackgroundColor:kSTChatFileTVCBlueButtonSelectedColor forState:UIControlStateSelected];
		[self.fileTransferControlButton setCornerRadius:kViewCornerRadius];
//		[self.fileTransferControlButton addTarget:self action:@selector(startPauseButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
		
		[self.wellView addSubview:self.progressView];
		[self.wellView addSubview:self.fileIconImageView];
		[self.wellView addSubview:self.fileNameLabel];
		[self.wellView addSubview:self.fileSizeLabel];
		[self.wellView addSubview:self.fileTransferControlButton];
		[self.wellView addSubview:self.spinner];
		
		
		[self.contentView addSubview:self.wellView];
		[self.contentView addSubview:self.sharingExplanationTextView];

		self.backgroundColor = [UIColor clearColor];
    }
    return self;
}


- (void)setupButtonAccordingToCellUIState:(STChatDownloadFileCellUIState)state
{
	[self.fileTransferControlButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
	self.fileTransferControlButton.enabled = YES;
	
	switch (state) {
		
		case kSTChatDownloadFileCellUIStateUploadFileInactive:
		case kSTChatDownloadFileCellUIStateUploadFileActive:
			[self.fileTransferControlButton setTitleWithIcon:FATrashO forState:UIControlStateNormal];
			[self.fileTransferControlButton setBackgroundColor:kSTChatFileTVCRedButtonColor forState:UIControlStateNormal];
			[self.fileTransferControlButton setBackgroundColor:kSTChatFileTVCRedButtonSelectedColor forState:UIControlStateSelected];
			[self.fileTransferControlButton addTarget:self action:@selector(cancelUploadOrDownload:) forControlEvents:UIControlEventTouchUpInside];
		break;
		case kSTChatDownloadFileCellUIStateUploadFileCanceled:
		case kSTChatDownloadFileCellUIStateDownloadFileCanceled:
			[self.fileTransferControlButton setTitleWithIcon:FABan forState:UIControlStateNormal];
			[self.fileTransferControlButton setBackgroundColor:kSTChatFileTVCRedButtonColor forState:UIControlStateNormal];
			[self.fileTransferControlButton setBackgroundColor:kSTChatFileTVCRedButtonSelectedColor forState:UIControlStateSelected];
			self.fileTransferControlButton.enabled = NO;
		break;
		case kSTChatDownloadFileCellUIStateDownloadFileInactive:
			[self.fileTransferControlButton setTitleWithIcon:FADownload forState:UIControlStateNormal];
			[self.fileTransferControlButton setBackgroundColor:kSTChatFileTVCBlueButtonColor forState:UIControlStateNormal];
			[self.fileTransferControlButton setBackgroundColor:kSTChatFileTVCBlueButtonSelectedColor forState:UIControlStateSelected];
			[self.fileTransferControlButton addTarget:self action:@selector(startDownloading:) forControlEvents:UIControlEventTouchUpInside];
		break;
		case kSTChatDownloadFileCellUIStateDownloadFileActive:
			[self.fileTransferControlButton setTitleWithIcon:FAStop forState:UIControlStateNormal];
            [self.fileTransferControlButton setBackgroundColor:kSTChatFileTVCBlueButtonColor forState:UIControlStateNormal];
            [self.fileTransferControlButton setBackgroundColor:kSTChatFileTVCBlueButtonSelectedColor forState:UIControlStateSelected];
			[self.fileTransferControlButton addTarget:self action:@selector(cancelUploadOrDownload:) forControlEvents:UIControlEventTouchUpInside];
		break;
		case kSTChatDownloadFileCellUIStateDownloadFileFinished:
			[self.fileTransferControlButton setTitleWithIcon:FAHddO forState:UIControlStateNormal];
            [self.fileTransferControlButton setBackgroundColor:kSTChatFileTVCBlueButtonColor forState:UIControlStateNormal];
            [self.fileTransferControlButton setBackgroundColor:kSTChatFileTVCBlueButtonSelectedColor forState:UIControlStateSelected];
			[self.fileTransferControlButton addTarget:self action:@selector(openDownloadedFile:) forControlEvents:UIControlEventTouchUpInside];
		break;
			
		case kSTChatDownloadFileCellUIStateNotSet:
		default:
			self.fileTransferControlButton.hidden = YES;
		break;
	}
}


- (void)cancelUploadOrDownload:(id)sender
{
	if (_delegate && _cellIndex > -1 && [_delegate respondsToSelector:@selector(fileTableViewCell:actionButtonWasPressedWithAction:atIndex:)]) {
		[_delegate fileTableViewCell:self actionButtonWasPressedWithAction:kSTChatFileTableViewCellActionTypeCancelTransfer atIndex:_cellIndex];
	}
}


- (void)startDownloading:(id)sender
{
	if (_delegate && _cellIndex > -1 && [_delegate respondsToSelector:@selector(fileTableViewCell:actionButtonWasPressedWithAction:atIndex:)]) {
		[_delegate fileTableViewCell:self actionButtonWasPressedWithAction:kSTChatFileTableViewCellActionTypeStartDownload atIndex:_cellIndex];
	}
}


- (void)openDownloadedFile:(id)sender
{
	if (_delegate && _cellIndex > -1 && [_delegate respondsToSelector:@selector(fileTableViewCell:actionButtonWasPressedWithAction:atIndex:)]) {
		[_delegate fileTableViewCell:self actionButtonWasPressedWithAction:kSTChatFileTableViewCellActionTypeOpenDownloadedFile atIndex:_cellIndex];
	}
}


- (void)setupCellWithMessage:(id<STFileTransferChatMesage>)fileMessage
{
	[super setupCellWithMessage:fileMessage];
	
	if (fileMessage) {
		self.fileNameLabel.text = [fileMessage fileName];
		
		NSString *fileSizeString = [NSByteCountFormatter stringFromByteCount:[fileMessage fileSize] countStyle:NSByteCountFormatterCountStyleBinary];
		self.fileSizeLabel.text = fileSizeString;
		self.progressView.progress = 0.0f;
		
		
		STChatFileTransferType fileTransferType = [fileMessage fileTransferType];
		
		switch (fileTransferType) {
			case kSTChatFileTransferTypeDownload: {
				// set explanation label text
				self.sharingExplanationTextView.text = NSLocalizedStringWithDefaultValue(@"label_incoming-file",
																						 nil, [NSBundle mainBundle],
																						 @"Incoming file:",
																						 @"I believe colon should be preserved.");
				
				// set _uiState to inactive first
				_uiState = kSTChatDownloadFileCellUIStateDownloadFileInactive;
				
				// check if we have at least one byte downloaded, if yes
				if ([fileMessage hasTransferStarted]) {
					_uiState = kSTChatDownloadFileCellUIStateDownloadFileActive;
					
					
					if ([fileMessage fileSize] != 0) {
						self.progressView.hidden = NO;
						CGFloat progress = (CGFloat)[fileMessage downloadedBytes] / (CGFloat)[fileMessage fileSize];
						self.progressView.progress = progress;
						fileSizeString = [fileSizeString stringByAppendingFormat:@" / %3.0f%%", progress * 100.0f];
						self.fileSizeLabel.text = fileSizeString;
					} else {
//						NSLog(@"Avoided division by zero. File size is zero");
						self.progressView.hidden = YES;
					}
				}
				
				if ([fileMessage isCanceled]) {
					if ([fileMessage fileSize] == [fileMessage downloadedBytes]) {
						self.progressView.progress = 1.0f;
						_uiState = kSTChatDownloadFileCellUIStateDownloadFileFinished;
					} else {
						self.progressView.hidden = YES;
						_uiState = kSTChatDownloadFileCellUIStateDownloadFileCanceled;
					}
				}
			}
			break;
				
			case kSTChatFileTransferTypeUpload: {
				self.sharingExplanationTextView.text = NSLocalizedStringWithDefaultValue(@"label_outgoing-file",
																						 nil, [NSBundle mainBundle],
																						 @"You are sharing this file:",
																						 @"I believe colon should be preserved.");
				self.progressView.hidden = YES;
				
				_uiState = kSTChatDownloadFileCellUIStateUploadFileInactive;
				[self.spinner stopAnimating];
				
				if ([fileMessage sharingSpeed] > 0) {
					_uiState = kSTChatDownloadFileCellUIStateUploadFileActive;
					self.spinner.hidden = NO;
					[self.spinner startAnimating];
				}
				
				if ([fileMessage isCanceled]) {
					_uiState = kSTChatDownloadFileCellUIStateUploadFileCanceled;
				}
			}
			break;
			
			case kSTChatFileTransferTypePeerToPeerSharing:
			case kSTChatFileTransferTypeUnspecified:
			default:
//				NSLog(@"This shouldn't happen. Unsupported file transfer cell type");
			break;
		}
		
		[self setupButtonAccordingToCellUIState:_uiState];
		
		[self setNeedsLayout];
	}
}


- (void)layoutSubviews
{
	[super layoutSubviews];
		
	id<STFileTransferChatMesage> fileDownloadMessage = (id<STFileTransferChatMesage>)_message;
		
	if (self.top) {
		self.avatarImageView.hidden = NO;
		self.userNameLabel.hidden = NO;
		
        self.sharingExplanationTextView.frame = CGRectMake(self.deliveryStatusContainerView.frame.origin.x + self.deliveryStatusContainerView.frame.size.width + kSTChatCellHorisontalGap,
                                                           self.avatarImageView.frame.origin.y + self.avatarImageView.frame.size.height + kSTChatCellVerticalGap,
                                                           self.contentView.bounds.size.width - kSTChatCellHorisontalEdge * 2.0f - self.deliveryStatusContainerView.frame.size.width - kSTChatCellHorisontalGap,
                                                           kSTChatSharingExplanationTextViewHeight);
        
        self.deliveryStatusContainerView.frame = CGRectMake(kSTChatCellHorisontalEdge,
                                                            self.sharingExplanationTextView.frame.origin.y + (self.sharingExplanationTextView.frame.size.height / 2) - (self.deliveryStatusContainerView.frame.size.height / 2),
                                                            self.deliveryStatusContainerView.frame.size.width,
                                                            self.deliveryStatusContainerView.frame.size.height);
		
		
	} else {
		self.avatarImageView.hidden = YES;
		self.userNameLabel.hidden = YES;
        
        self.sharingExplanationTextView.frame = CGRectMake(self.deliveryStatusContainerView.frame.origin.x + self.deliveryStatusContainerView.frame.size.width + kSTChatCellHorisontalGap,
                                                           self.timestampLabel.frame.origin.y + self.timestampLabel.frame.size.height + kSTChatCellVerticalGap,
                                                           self.contentView.bounds.size.width - kSTChatCellHorisontalEdge * 2.0f - self.deliveryStatusContainerView.frame.size.width - kSTChatCellHorisontalGap,
                                                           kSTChatSharingExplanationTextViewHeight);
		
        // Hide it??
        self.timestampLabel.frame = CGRectMake(kSTChatCellHorisontalEdge,
                                               self.timestampLabel.frame.origin.y,
                                               self.contentView.bounds.size.width - kSTChatCellHorisontalEdge * 2.0f,
                                               self.timestampLabel.frame.size.height);
        
        self.deliveryStatusContainerView.frame = CGRectMake(kSTChatCellHorisontalEdge,
                                                            self.sharingExplanationTextView.frame.origin.y + (self.sharingExplanationTextView.frame.size.height / 2) - (self.deliveryStatusContainerView.frame.size.height / 2),
                                                            self.deliveryStatusContainerView.frame.size.width,
                                                            self.deliveryStatusContainerView.frame.size.height);
	}
	
	self.wellView.frame = CGRectMake(kSTChatCellHorisontalEdge,
									 self.sharingExplanationTextView.frame.origin.y + self.sharingExplanationTextView.frame.size.height + kSTChatCellVerticalGap,
									 self.contentView.bounds.size.width - kSTChatCellHorisontalEdge * 2.0f,
									 kSTChatDownloadFileWellViewHeight);
	
//	self.fileIconImageView.frame = CGRectMake(kSTChatCellHorisontalEdge,
//											  self.avatarImageView.frame.origin.y + self.avatarImageView.frame.size.height + kSTChatCellVerticalGap,
//											  kSTChatFileIconWidth, kSTChatFileIconHeight);
	
	
	
	// All next views live in self.wellView
	
	if ([fileDownloadMessage isSentByLocalUser]) {
	
		self.fileTransferControlButton.frame = CGRectMake(kSTChatCellHorisontalEdge,
												 self.wellView.bounds.size.height / 2.0f - kSTChatDownloadFileButtonHeight / 2.0f, // y center of wellView
												 kSTChatDownloadFileButtonWidth,
												 kSTChatDownloadFileButtonHeight);
		
		self.fileNameLabel.frame = CGRectMake(self.fileTransferControlButton.frame.origin.x + self.fileTransferControlButton.frame.size.width + kSTChatCellHorisontalGap,
											  kSTChatCellVerticalEdge,
											  self.wellView.frame.size.width - self.fileTransferControlButton.frame.origin.x - self.fileTransferControlButton.frame.size.width - kSTChatCellHorisontalGap - kSTChatCellHorisontalEdge,
											  kSTChatFileNameLabelHeight);
		
		self.spinner.frame = CGRectMake(self.fileNameLabel.frame.origin.x,
										self.fileNameLabel.frame.origin.y + self.fileNameLabel.frame.size.height + kSTChatCellVerticalGap,
										self.spinner.frame.size.width,
										self.spinner.frame.size.height);
		
		self.fileSizeLabel.frame = CGRectMake(self.fileNameLabel.frame.origin.x + self.fileNameLabel.frame.size.width / 2.0f - kSTChatFileSizeLabelWidth / 2.0f, // x center of self.fileNameLabel
											  self.fileNameLabel.frame.origin.y + self.fileNameLabel.frame.size.height + kSTChatCellVerticalGap,
											  kSTChatFileSizeLabelWidth,
											  kSTChatFileNameLabelHeight);
	} else {
		self.fileTransferControlButton.frame = CGRectMake(self.wellView.bounds.size.width - kSTChatCellHorisontalGap - kSTChatCellHorisontalEdge - kSTChatDownloadFileButtonWidth,
												 self.wellView.bounds.size.height / 2.0f - kSTChatDownloadFileButtonHeight / 2.0f, // y center of wellView
												 kSTChatDownloadFileButtonWidth,
												 kSTChatDownloadFileButtonHeight);
				
		self.fileNameLabel.frame = CGRectMake(kSTChatCellHorisontalEdge,
											  kSTChatCellVerticalEdge,
											  self.wellView.frame.size.width - self.fileTransferControlButton.frame.size.width - kSTChatCellHorisontalGap * 2.0f - kSTChatCellHorisontalEdge * 2.0f,
											  kSTChatFileNameLabelHeight);
		
		self.spinner.frame = CGRectMake(self.fileNameLabel.frame.origin.x,
										self.fileNameLabel.frame.origin.y + self.fileNameLabel.frame.size.height + kSTChatCellVerticalGap,
										self.spinner.frame.size.width,
										self.spinner.frame.size.height);
		
		self.fileSizeLabel.frame = CGRectMake(self.fileNameLabel.frame.origin.x + self.fileNameLabel.frame.size.width / 2.0f - kSTChatFileSizeLabelWidth / 2.0f, // x center of self.fileNameLabel
											  self.fileNameLabel.frame.origin.y + self.fileNameLabel.frame.size.height + kSTChatCellVerticalGap,
											  kSTChatFileSizeLabelWidth,
											  kSTChatFileNameLabelHeight);
		
		if ([fileDownloadMessage fileTransferType] == kSTChatFileTransferTypeDownload) {
			self.progressView.frame = CGRectMake(self.fileNameLabel.frame.origin.x,
												 self.fileNameLabel.frame.origin.y + self.fileNameLabel.frame.size.height + kSTChatCellVerticalGap,
												 self.fileNameLabel.frame.size.width,
												 self.fileNameLabel.frame.size.height);
		}
	}
}


- (void)prepareForReuse
{
	self.progressView.progress = 0;
	self.progressView.hidden = YES;
	
	[super prepareForReuse];
}


#pragma mark - Height calculation

+ (CGFloat)neededHeightForCellWithFileChatMessage:(id<STFileTransferChatMesage>)message
									   topMessage:(BOOL)isTopMessage
									bottomMessage:(BOOL)isBottomMessage
								restrictedToWidth:(CGFloat)restrictedToWidth
{
	CGFloat height = 44.0f;
	
	if (isTopMessage) {
		height = kSTChatCellVerticalEdge * 2.0f +
		kSTChatCellAvatarImageHeight + kSTChatCellVerticalGap + // avatar
		kSTChatSharingExplanationTextViewHeight + kSTChatCellVerticalGap + // sharing explanation
		kSTChatDownloadFileWellViewHeight; // well view with contents
	} else {
		height = kSTChatCellVerticalEdge * 2.0f +
		kSTChatCellTimeStampLabelHeight + kSTChatCellVerticalGap +
		kSTChatSharingExplanationTextViewHeight + kSTChatCellVerticalGap + // sharing explanation
		kSTChatDownloadFileWellViewHeight; // well view with contents
	}
	
	if (isBottomMessage) {
		height += kSTChatCellBottomEmptySpaceHeight;
	}
	
	
	return height;
}


#pragma mark - Actions Delegation

- (void)setDelegate:(id<STChatFileTableViewCellDelegate>)delegate withCellIndex:(NSInteger)cellIndex
{
	_delegate = delegate;
	_cellIndex = cellIndex;
}


- (void)clearDelegate
{
	_delegate = nil;
	_cellIndex = -1;
}


@end
