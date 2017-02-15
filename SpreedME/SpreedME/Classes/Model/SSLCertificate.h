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

#import <Foundation/Foundation.h>
#import <Security/Security.h>

// This corresponds to HASH_HashType in nss library
typedef enum {
    HashAlgorithm_NULL   = 0,
    HashAlgorithm_MD2    = 1,
    HashAlgorithm_MD5    = 2,
    HashAlgorithm_SHA1   = 3,
    HashAlgorithm_SHA256 = 4,
    HashAlgorithm_SHA384 = 5,
    HashAlgorithm_SHA512 = 6,
    HashAlgorithm_SHA224 = 7,
    HashAlgorithm_TOTAL

} HashAlgorithm;

typedef struct SSLCertificateFingerprint {
	uint8_t data[64];
	size_t length;
	HashAlgorithm algo;
} SSLCertificateFingerprint;

BOOL CompareFingerprints(SSLCertificateFingerprint num1, SSLCertificateFingerprint num2);


@interface SSLCertificate : NSObject

// initialization
- (instancetype)initWithNativeHandle:(SecCertificateRef)nativeCertificate;
- (instancetype)initWithDerData:(NSData *)derData;


// Conversion
- (NSData *)toDER;


// Validation
- (BOOL)isValid; //validates only against time now
- (BOOL)isEqualByFingerprints:(SSLCertificate *)otherCertificate;// compares sha1 and md5 fingerprints of certificates
- (BOOL)isEqualBySPKIsha256Fingerprint:(SSLCertificate *)otherCertificate;

- (BOOL)hasTheSameSPKI_SHA256Fingerprint:(NSData *)skpiSHA256Fingerprint;


// Get properties of certificate
- (NSString *)issuerRawString;
- (NSString *)issuer; //returned value depends on fields in certificate, can be CN or O or OU
- (NSString *)issuerCommonName;
- (NSString *)subjectCommonName;
- (NSString *)email;
- (NSString *)rawSubjectString;
- (NSString *)versionString;
- (uint32_t)version;
- (NSData *)publicKey;// at the moment supports only RSA key extraction
- (NSData *)spkiSHA256Fingerprint;
- (NSString *)publicKeyString; // at the moment supports only RSA key extraction
- (NSString *)publicKeyAlgorithm; // not implemented. Always returns nil
- (NSString *)serialNumberString;
- (NSData *)serialNumber;
- (NSDate *)notValidAfter;
- (NSDate *)notValidBefore;


// utility methods
+ (NSString *)stringRepresentationForFingerprint:(SSLCertificateFingerprint)fingerprint;


@property (nonatomic, assign, readonly) SSLCertificateFingerprint sha1_fingerprint;
@property (nonatomic, assign, readonly) SSLCertificateFingerprint md5_fingerprint;
@property (nonatomic, copy, readonly) NSString *uId;


@end
