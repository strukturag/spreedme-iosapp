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

#import "DateFormatterManager.h"

NSString * const kFullReadableDateFormat		= @"yyyy-MM-dd : HH:mm:ss";


@implementation DateFormatterManager
{
	NSDateFormatter *_defaultLocalizedShortDateTimeStyleFormatter;
	NSDateFormatter *_defaultLocalizedShortDateMediumTimeStyleFormatter;
	NSDateFormatter *_fullReadableDateFormatter;
	NSDateFormatter *_RFC3339DateFormatter;
	NSDateFormatter *_userVisibleDateFormatter;
	NSDateFormatter *_dayLimitedDateDormatter;
}


+ (DateFormatterManager *)sharedInstance
{
	static dispatch_once_t once;
    static DateFormatterManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (NSDateFormatter *)defaultLocalizedShortDateTimeStyleFormatter
{
	if (!_defaultLocalizedShortDateTimeStyleFormatter) {
		_defaultLocalizedShortDateTimeStyleFormatter = [[NSDateFormatter alloc] init];
		[_defaultLocalizedShortDateTimeStyleFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[_defaultLocalizedShortDateTimeStyleFormatter setDateStyle:NSDateFormatterShortStyle];
		[_defaultLocalizedShortDateTimeStyleFormatter setTimeStyle:NSDateFormatterShortStyle];
		[_defaultLocalizedShortDateTimeStyleFormatter setDoesRelativeDateFormatting:YES];
	}
	
	return _defaultLocalizedShortDateTimeStyleFormatter;
}


- (NSDateFormatter *)defaultLocalizedShortDateMediumTimeStyleFormatter
{
	if (!_defaultLocalizedShortDateMediumTimeStyleFormatter) {
		_defaultLocalizedShortDateMediumTimeStyleFormatter = [[NSDateFormatter alloc] init];
		[_defaultLocalizedShortDateMediumTimeStyleFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[_defaultLocalizedShortDateMediumTimeStyleFormatter setDateStyle:NSDateFormatterShortStyle];
		[_defaultLocalizedShortDateMediumTimeStyleFormatter setTimeStyle:NSDateFormatterMediumStyle];
		[_defaultLocalizedShortDateMediumTimeStyleFormatter setDoesRelativeDateFormatting:YES];
	}
	
	return _defaultLocalizedShortDateMediumTimeStyleFormatter;
}


- (NSDateFormatter *)fullReadableDateFormatter
{
	if (!_fullReadableDateFormatter) {
		_fullReadableDateFormatter = [[NSDateFormatter alloc] init];
		_fullReadableDateFormatter.dateFormat = kFullReadableDateFormat;
	}
	return _fullReadableDateFormatter;
}


- (NSDateFormatter *)RFC3339DateFormatter
{
	if (!_RFC3339DateFormatter) {
		NSLocale *enUSPOSIXLocale;
		
		_RFC3339DateFormatter = [[NSDateFormatter alloc] init];
		assert(_RFC3339DateFormatter != nil);
		
		enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
		assert(enUSPOSIXLocale != nil);
		
		[_RFC3339DateFormatter setLocale:enUSPOSIXLocale];
		[_RFC3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ssZ"];
		[_RFC3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	}
	
	return _RFC3339DateFormatter;
}


- (NSDateFormatter *)userVisibleDateFormatter
{
    if (!_userVisibleDateFormatter) {
        _userVisibleDateFormatter = [[NSDateFormatter alloc] init];
        assert(_userVisibleDateFormatter != nil);
        [_userVisibleDateFormatter setDateFormat:@"MMM dd, yyyy HH:mm"];
        [_userVisibleDateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [_userVisibleDateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    }
	return _userVisibleDateFormatter;
}


- (NSDateFormatter *)dayLimitedDateDormatter
{
	if (!_dayLimitedDateDormatter) {
		_dayLimitedDateDormatter = [[NSDateFormatter alloc] init];
        assert(_dayLimitedDateDormatter != nil);
        
        [_dayLimitedDateDormatter setDateFormat:@"yyyy-MM-dd"];
	}
	return _dayLimitedDateDormatter;
}


@end
