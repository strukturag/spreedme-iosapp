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

#import "SSLCertificateViewController.h"

#import "DateFormatterManager.h"
#import "SSLCertificate.h"
#import "StaticTextViewController.h"
#import "STPair.h"


NSString * const SSLCertificateVCSummarySection				= @"SSLCertificateVCSummarySection";
NSString * const SSLCertificateVCFingerprintSection			= @"SSLCertificateVCFingerprintSection";
NSString * const SSLCertificateVCDateValiditySection		= @"SSLCertificateVCDateValiditySection";
NSString * const SSLCertificateVCPublicKeySection			= @"SSLCertificateVCPublicKeySection";
NSString * const SSLCertificateVCExtensionsSection			= @"SSLCertificateVCExtensionsSection";


typedef enum : NSUInteger {
    kSSLCertificateVCSectionSummary = 0,
    kSSLCertificateVCSectionFingerprints,
    kSSLCertificateVCSectionPublicKey,
	kSSLCertificateVCSectionCount
} SSLCertificateVCSectionEnum;


@interface SSLCertificateViewController () <UITableViewDataSource, UITableViewDelegate>
{
	SSLCertificate *_sslCert;
	
	NSMutableDictionary *_certFields; // key - predefined NSString, value - NSArray of STPair values where key is a field name, value is a field value.
}


@property (nonatomic, strong) IBOutlet UITableView *tableView;

@end


@implementation SSLCertificateViewController

- (instancetype)initWithSSLCertificate:(SSLCertificate *)cert
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _sslCert = cert;
		_certFields = [[NSMutableDictionary alloc] init];
		[self fillCertFieldsStructureWithCertificate:_sslCert];
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
}



#pragma mark - Certificate related methods

- (void)fillCertFieldsStructureWithCertificate:(SSLCertificate *)cert
{
	[_certFields removeAllObjects];
	
	// Summary
		// subject CN
		// issuer
		// expires
		// serial number
		// version
	// fingerprints
		// sha1 fingerprint
		// md5 fingerprint
	// Public key
		// public key algorithm
		// public key
	
	NSDateFormatter *dateFormatter = [DateFormatterManager sharedInstance].RFC3339DateFormatter;
	
	// Summary section
	NSMutableArray *summary = [NSMutableArray array];

	STPair *subjectCN = [STPair pairWithKey:NSLocalizedStringWithDefaultValue(@"label_ssl_subject-cn",
																			  nil, [NSBundle mainBundle],
																			  @"Subject CN",
																			  @"Subject common name, as defined for SSL certs")
									  value:[cert subjectCommonName]];
	STPair *issuer = [STPair pairWithKey:NSLocalizedStringWithDefaultValue(@"label_ssl_issuer",
																		   nil, [NSBundle mainBundle],
																		   @"Issuer",
																		   @"Issuer of the certificate")
								   value:[cert issuer]];
	STPair *expires = [STPair pairWithKey:NSLocalizedStringWithDefaultValue(@"label_ssl_expires",
																			nil, [NSBundle mainBundle],
																			@"Expires",
																			@"When cert expires")
									value:[dateFormatter stringFromDate:[cert notValidAfter]]];
	STPair *serialNumber = [STPair pairWithKey:NSLocalizedStringWithDefaultValue(@"label_ssl_serial-number",
																				 nil, [NSBundle mainBundle],
																				 @"Serial number",
																				 @"Serial number of certificate")
										 value:[cert serialNumberString]];
	STPair *version = [STPair pairWithKey:NSLocalizedStringWithDefaultValue(@"label_ssl_version",
																			nil, [NSBundle mainBundle],
																			@"Version",
																			@"Version of cert")
									value:[cert versionString]];
    if (subjectCN) {
        [summary addObject:subjectCN];
    }
    if (issuer) {
        [summary addObject:issuer];
    }
    if (expires) {
        [summary addObject:expires];
    }
    if (serialNumber) {
        [summary addObject:serialNumber];
    }
    if (version) {
        [summary addObject:version];
    }
	
	[_certFields setObject:summary forKey:SSLCertificateVCSummarySection];
	
	// Fingerprints section
	NSMutableArray *fingerprints = [NSMutableArray array];
	
	STPair *sha1Fingerprint = [STPair pairWithKey:NSLocalizedStringWithDefaultValue(@"label_ssl_fingerprint-sha1",
																					nil, [NSBundle mainBundle],
																					@"SHA1 fingerprint",
																					@"SHA1 fingerprint of cert")
									  value:[SSLCertificate stringRepresentationForFingerprint:cert.sha1_fingerprint]];
	STPair *md5Fingerprint = [STPair pairWithKey:NSLocalizedStringWithDefaultValue(@"label_ssl_fingerpring-md5",
																				   nil, [NSBundle mainBundle],
																				   @"MD5 fingerprint",
																				   @"MD5 fingerprint of cert")
											value:[SSLCertificate stringRepresentationForFingerprint:cert.md5_fingerprint]];
	
	[fingerprints addObject:sha1Fingerprint];
	[fingerprints addObject:md5Fingerprint];
	
	[_certFields setObject:fingerprints forKey:SSLCertificateVCFingerprintSection];
	
	// Public key section
	NSMutableArray *publicKey = [NSMutableArray array];
	
	STPair *publicKeyAlgorithm = [STPair pairWithKey:NSLocalizedStringWithDefaultValue(@"label_ssl_public-key-algorithm",
																					   nil, [NSBundle mainBundle],
																					   @"Algorithm",
																					   @"Algorithm")
											   value:[cert publicKeyAlgorithm]];
	NSString *checkPubKeyString = [cert publicKeyString];
	NSString *pubKeyString = [checkPubKeyString length] > 0 ? checkPubKeyString : NSLocalizedStringWithDefaultValue(@"label_ssl_not-supported-yet",
																													nil, [NSBundle mainBundle],
																													@"Not supported yet",
																													@"Not supported yet");
	
	STPair *publicKeyStringPair = [STPair pairWithKey:NSLocalizedStringWithDefaultValue(@"label_ssl_public-key",
																						nil, [NSBundle mainBundle],
																						@"Public key",
																						@"Public key of cert")
												value:pubKeyString];
	
	[publicKey addObject:publicKeyAlgorithm];
	[publicKey addObject:publicKeyStringPair];
	
	[_certFields setObject:publicKey forKey:SSLCertificateVCPublicKeySection];
}


#pragma mark - UITableView Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [_certFields count];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSInteger numberOfRows = 0;
	switch (section) {
		case kSSLCertificateVCSectionSummary:
			numberOfRows = [[_certFields objectForKey:SSLCertificateVCSummarySection] count];
			break;
			
		case kSSLCertificateVCSectionFingerprints:
			numberOfRows = [[_certFields objectForKey:SSLCertificateVCFingerprintSection] count];
			break;
			
		case kSSLCertificateVCSectionPublicKey:
			numberOfRows = [[_certFields objectForKey:SSLCertificateVCPublicKeySection] count];
			break;
			
		default:
			break;
	}
	
	return numberOfRows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"CellIdentifier";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
	}
	
	switch (indexPath.section) {
		case kSSLCertificateVCSectionSummary:
		{
			NSArray *summaryArray = [_certFields objectForKey:SSLCertificateVCSummarySection];
			STPair *pair = (STPair *)[summaryArray objectAtIndex:indexPath.row];
			cell.textLabel.text = pair.key;
			cell.detailTextLabel.text = pair.value;
		}
			break;
			
		case kSSLCertificateVCSectionFingerprints:
		{
			NSArray *fingerprintArray = [_certFields objectForKey:SSLCertificateVCFingerprintSection];
			STPair *pair = (STPair *)[fingerprintArray objectAtIndex:indexPath.row];
			cell.textLabel.text = pair.key;
			cell.detailTextLabel.text = pair.value;
		}
			break;
			
		case kSSLCertificateVCSectionPublicKey:
		{
			NSArray *publicKeyArray = [_certFields objectForKey:SSLCertificateVCPublicKeySection];
			STPair *pair = (STPair *)[publicKeyArray objectAtIndex:indexPath.row];
			cell.textLabel.text = pair.key;
			cell.detailTextLabel.text = pair.value;
		}
			break;
			
		default:
			break;
	}
	
	return cell;
}


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	
	StaticTextViewController *staticTextVC = [[StaticTextViewController alloc] initWithText:cell.detailTextLabel.text andTitle:cell.textLabel.text];
	[self.navigationController pushViewController:staticTextVC animated:YES];
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
