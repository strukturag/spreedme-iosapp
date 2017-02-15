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

#import "SpreedMeTrustedSSLStore.h"

#import "SSLCertificate.h"


@interface SpreedMeTrustedSSLStore ()
{
	NSArray *_spreedMeCertificates;
}

@end


@implementation SpreedMeTrustedSSLStore

+ (instancetype)sharedTrustedStore
{
	static dispatch_once_t once;
    static SpreedMeTrustedSSLStore *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		//		First SubjectPublicKeyInfo fingerprint (sha256):
		//		e2:f0:f1:d7:ab:12:1b:13:97:8b:55:64:a8:fb:bc:9a:9c:00:11:b3:df:cd:8c:56:94:07:ea:a6:67:1d:ab:1f
		//		Base64: 4vDx16sSGxOXi1VkqPu8mpwAEbPfzYxWlAfqpmcdqx8=
		//
		//		Second SubjectPublicKeyInfo fingerprint (sha256):
		//		9f:29:f5:f1:93:5f:56:ca:b5:e1:00:7e:1b:cd:08:d2:b3:ba:24:12:b1:76:0e:f0:89:b6:ef:5b:db:f3:0b:5a
		//		Base64: nyn18ZNfVsq14QB+G80I0rO6JBKxdg7wibbvW9vzC1o=
		
		int8_t first[] = {
			0xe2, 0xf0, 0xf1, 0xd7,
			0xab, 0x12, 0x1b, 0x13,
			0x97, 0x8b, 0x55, 0x64,
			0xa8, 0xfb, 0xbc, 0x9a,
			0x9c, 0x00, 0x11, 0xb3,
			0xdf, 0xcd, 0x8c, 0x56,
			0x94, 0x07, 0xea, 0xa6,
			0x67, 0x1d, 0xab, 0x1f};
		
		int8_t second[] = {
			0x9f, 0x29, 0xf5, 0xf1,
			0x93, 0x5f, 0x56, 0xca,
			0xb5, 0xe1, 0x00, 0x7e,
			0x1b, 0xcd, 0x08, 0xd2,
			0xb3, 0xba, 0x24, 0x12,
			0xb1, 0x76, 0x0e, 0xf0,
			0x89, 0xb6, 0xef, 0x5b,
			0xdb, 0xf3, 0x0b, 0x5a};
		
		NSData *sha256_1 = [NSData dataWithBytes:first length:sizeof(first)];
		NSData *sha256_2 = [NSData dataWithBytes:second length:sizeof(second)];
		_spreedMeCertificates = @[sha256_1, sha256_2];
	}
	
	return self;
}


- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
                  forDomain:(NSString *)domain
   shouldValidateDomainName:(BOOL)shouldValidateDomainName
{
	BOOL answer = NO;

	SecCertificateRef secCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0); // take the leaf only
	
	SSLCertificate *certificate = [[SSLCertificate alloc] initWithNativeHandle:secCertificate];
	
	for (NSData *spreedMeCertSPKIHash in _spreedMeCertificates) {
		answer = [certificate hasTheSameSPKI_SHA256Fingerprint:spreedMeCertSPKIHash];
		if (answer == YES) {
			break;
		}
	}
	
	return answer;
}

@end
