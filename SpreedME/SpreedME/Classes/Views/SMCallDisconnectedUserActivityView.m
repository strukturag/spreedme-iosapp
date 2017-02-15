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

#import "SMCallDisconnectedUserActivityView.h"

#import "SMActivityIndicator.h"
#import "SpreedMeRoundedButton.h"


const CGFloat kSMCallDisconnectedUserActivityViewLabelHeight		= 58.0f;
const CGFloat kSMCallDisconnectedUserActivityViewAnimationHeight	= 24.0f;
const CGFloat kSMCallDisconnectedUserActivityViewButtonHeight		= 44.0f;
const CGFloat kSMCallDisconnectedUserActivityViewPadding            = 2.0f;


@interface SMCallDisconnectedUserActivityView ()
{
	id _target;
	SEL _action;
	
	NSTimer *_timer;
	
	BOOL _presentActionButton;
}

@property (nonatomic, strong) SMActivityIndicator *activityIndicator;
@property (nonatomic, strong) UILabel *informationLabel;
@property (nonatomic, strong) SpreedMeRoundedButton *button;

@end

@implementation SMCallDisconnectedUserActivityView

- (instancetype)init
{
	self = [self initWithFrame:CGRectMake(0.0f, 0.0f, 120.0f, 90.0f)];
	if (self) {
		
	}
	
	return self;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.alpha = 0.5f;
		self.backgroundColor = [UIColor whiteColor];
        self.layer.cornerRadius = 5.0f;
        
        self.informationLabel = [[UILabel alloc] initWithFrame:CGRectMake(kSMCallDisconnectedUserActivityViewPadding,
                                                                          kSMCallDisconnectedUserActivityViewPadding,
                                                                          self.frame.size.width - (2 * kSMCallDisconnectedUserActivityViewPadding),
                                                                          kSMCallDisconnectedUserActivityViewLabelHeight)];
		self.informationLabel.backgroundColor = [UIColor clearColor];
		self.informationLabel.textAlignment = NSTextAlignmentCenter;
        self.informationLabel.numberOfLines = 0;
        self.informationLabel.lineBreakMode = NSLineBreakByWordWrapping;
		self.informationLabel.font = [UIFont boldSystemFontOfSize:16.0f];
		self.informationLabel.text = NSLocalizedStringWithDefaultValue(@"label_establishing-connection",
																	   nil, [NSBundle mainBundle],
																	   @"Establishing connection",
																	   @"Message shows continuous process of establishing connection");
		[self addSubview:self.informationLabel];
		
		self.activityIndicator = [[SMActivityIndicator alloc] initWithHeight:kSMCallDisconnectedUserActivityViewAnimationHeight];
		self.activityIndicator.center = CGPointMake(self.frame.size.width / 2,
                                                    self.informationLabel.frame.origin.y + self.informationLabel.frame.size.height +(self.activityIndicator.frame.size.height / 2));
		[self addSubview:self.activityIndicator];
		
		
		
		self.button = [[SpreedMeRoundedButton alloc] initWithFrame:CGRectMake(0.0f,
																			  0.0f,
																			  frame.size.width,
																			  kSMCallDisconnectedUserActivityViewButtonHeight)];
		[self.button configureButtonWithButtonType:kSpreedMeButtonTypeHangUp];
		self.button.hidden = YES;
		[self addSubview:self.button];
    }
    return self;
}


#pragma mark - UIView overrides

- (void)layoutSubviews
{
    self.informationLabel.frame = CGRectMake(kSMCallDisconnectedUserActivityViewPadding,
                                             kSMCallDisconnectedUserActivityViewPadding,
                                             self.frame.size.width - (2 * kSMCallDisconnectedUserActivityViewPadding),
                                             kSMCallDisconnectedUserActivityViewLabelHeight);
    
    self.activityIndicator.center = CGPointMake(self.frame.size.width / 2,
                                                self.informationLabel.frame.origin.y + self.informationLabel.frame.size.height +(self.activityIndicator.frame.size.height / 2));
    
	if (!_presentActionButton) {
        self.button.hidden = YES;
	} else {
		self.button.hidden = NO;
		
		self.button.frame = CGRectMake(kSMCallDisconnectedUserActivityViewPadding,
									   self.activityIndicator.frame.origin.y + self.activityIndicator.frame.size.height + (2 * kSMCallDisconnectedUserActivityViewPadding),
									   self.frame.size.width - (2 * kSMCallDisconnectedUserActivityViewPadding),
									   kSMCallDisconnectedUserActivityViewButtonHeight);
	}
}


- (void)setHidden:(BOOL)hidden
{
	[super setHidden:hidden];
	if (hidden) {
		
	} else {
		
	}
}


#pragma mark - Setters/Getters

- (void)setShowButtonTimeInterval:(NSTimeInterval)showButtonTimeInterval
{
	_showButtonTimeInterval = showButtonTimeInterval;
	if (_showButtonTimeInterval > 0.001) {
		
	} else {
		[_timer invalidate];
		_timer = nil;
	}
}


#pragma mark - Public methods

- (void)setTarget:(id)target action:(SEL)action
{
	_target = target;
	_action = action;
	
	if (self.button) {
		[self.button removeTarget:nil
						   action:NULL
				 forControlEvents:UIControlEventAllEvents];
		
		if (_target && _action) {
			[self.button addTarget:_target action:_action forControlEvents:UIControlEventTouchUpInside];
		}
	}
}


- (void)startAnimating
{
	[self.activityIndicator startAnimating];
	
	if (self.showButtonTimeInterval > 0.001) {
		_timer = [NSTimer scheduledTimerWithTimeInterval:self.showButtonTimeInterval
												  target:self
												selector:@selector(startShowingButton:)
												userInfo:nil
												 repeats:NO];
	}
}


- (void)stopAnimating
{
	[self.activityIndicator stopAnimating];
	[_timer invalidate];
	_timer = nil;
	if (_presentActionButton) {
		_presentActionButton = NO;
		self.frame = CGRectMake(self.frame.origin.x,
								self.frame.origin.y + kSMCallDisconnectedUserActivityViewButtonHeight / 2.0f,
								self.frame.size.width,
								self.frame.size.height - (kSMCallDisconnectedUserActivityViewButtonHeight + (2 * kSMCallDisconnectedUserActivityViewPadding)));
		[self setNeedsLayout];
	}
}


#pragma mark - Private methods

- (void)startShowingButton:(NSTimer *)theTimer
{
	if (!_presentActionButton) {
		_presentActionButton = YES;
		self.frame = CGRectMake(self.frame.origin.x,
								self.frame.origin.y - kSMCallDisconnectedUserActivityViewButtonHeight / 2.0f,
								self.frame.size.width,
								self.frame.size.height + (kSMCallDisconnectedUserActivityViewButtonHeight + (2 * kSMCallDisconnectedUserActivityViewPadding)));
		[self setNeedsLayout];
	}
}


@end
