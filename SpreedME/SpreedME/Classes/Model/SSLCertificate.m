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

#import "SSLCertificate.h"


#include "cert.h"
#include "nss.h"
#include "utilrename.h"
#include "keyhi.h"
#include "hasht.h"
#include "sechash.h"
#include "prtime.h"


CERTCertificate* CreateNSSCertHandleFromBytes(const char* data, int length);
CERTCertificate* CreateNSSCertHandleFromOSHandle(SecCertificateRef cert_handle);
NSString* getHexStringFromBuffer(uint8_t *buffer, size_t length);


@interface SSLCertificate ()
{
	CERTCertificate *_nssCertificate;
}


@end


@implementation SSLCertificate


#pragma mark - Object lifecycle

- (instancetype)initWithNativeHandle:(SecCertificateRef)nativeCertificate
{
	self = [super init];
	if (self) {
		if (nativeCertificate) {
			_nssCertificate = CreateNSSCertHandleFromOSHandle(nativeCertificate);
			
			if (!_nssCertificate){
				self = nil;
				return self;
			}
			
			if (![self calculateFingerprints]) {
				self = nil;
				return self;
			}
		}
	}
	
	return self;
}


- (instancetype)initWithDerData:(NSData *)derData
{
	self = [super init];
	if (self) {
		if (derData.length) {
			_nssCertificate = CreateNSSCertHandleFromBytes(derData.bytes, derData.length);
			
			if (!_nssCertificate){
				self = nil;
				return self;
			}
			
			if (![self calculateFingerprints]) {
				self = nil;
				return self;
			}
		}
	}
	
	return self;
}


// This method should be called only once per instance!!!
- (BOOL)calculateFingerprints
{
	SSLCertificateFingerprint sha1_fingerprint;
	BOOL success = [self fingerprint:&sha1_fingerprint withAlgorithm:HashAlgorithm_SHA1];
	if (success) {
		_sha1_fingerprint = sha1_fingerprint;
		_sha1_fingerprint.algo = HashAlgorithm_SHA1;
	} else {
		return NO;
	}
	
	SSLCertificateFingerprint md5_fingerprint;
	success = [self fingerprint:&md5_fingerprint withAlgorithm:HashAlgorithm_MD5];
	if (success) {
		_md5_fingerprint = md5_fingerprint;
		_md5_fingerprint.algo = HashAlgorithm_MD5;
	} else {
		return NO;
	}
	
	_uId = [[SSLCertificate stringRepresentationForFingerprint:_sha1_fingerprint] copy];
	
	return YES;
}


- (void)dealloc
{
	if (_nssCertificate) {
		CERT_DestroyCertificate(_nssCertificate);
	}
}


#pragma mark - Certificate fields getters

- (NSString *)issuerRawString
{
	return NSStr(_nssCertificate->issuerName);
}

- (NSString *)issuer; //returned value depends on fields in certificate, can be CN or O or OU
{
	NSString *issuer = [self issuerRawString];
	
	NSArray *components = [issuer componentsSeparatedByString:@","];
	for (NSString *string in components) {
		NSArray *subcomponents = [string componentsSeparatedByString:@"="];
		// we should receive pairs like CN example.com
		if ([subcomponents count] == 2) {
			NSString *identifier = [subcomponents firstObject];
			NSString *value = [subcomponents lastObject];
			identifier = [identifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if ([identifier isEqualToString:@"CN"]) {
				issuer = value;
			}
			if ([identifier isEqualToString:@"OU"]) {
				issuer = value;
			}
			if ([identifier isEqualToString:@"O"]) {
				issuer = value;
			}
		}
	}
	
	return issuer;
}


- (NSString *)issuerCommonName
{
	char *issuerLastCN = CERT_GetCommonName(&_nssCertificate->issuer);
	NSString *issuerCommonName = NSStr(issuerLastCN);
	PORT_Free(issuerLastCN);
	
	return issuerCommonName;
}


- (NSString *)subjectCommonName
{
	char *subjectLastCN = CERT_GetCommonName(&_nssCertificate->subject);
	NSString *subjectCommonName = NSStr(subjectLastCN);
	PORT_Free(subjectLastCN);
	
	return subjectCommonName;
}


- (NSString *)email
{
	return NSStr(_nssCertificate->emailAddr);
}


- (NSString *)rawSubjectString
{
	return NSStr(_nssCertificate->subjectName);
}


- (NSString *)versionString
{
	NSString *versionString = nil;
	
	uint32_t version = [self version];
	
	switch (version) {
		case 0:
			versionString = @"1";
		break;
		case 1:
			versionString = @"2";
		break;
		case 2:
			versionString = @"3";
		break;
			
		default:
			versionString = @"unkonwn";
		break;
	}
	
	return versionString;
}


- (uint32_t)version
{
	uint32_t version = 0;
	
	if (_nssCertificate->version.len == 1) {
		version = (uint32_t)*_nssCertificate->version.data;
	}
	
	return version;
}


- (NSData *)publicKey
{
	NSData *pubKey = nil;
	
	SECKEYPublicKey *publicKey = CERT_ExtractPublicKey(_nssCertificate);

	if (publicKey) {
		switch (publicKey->keyType) {
			case nullKey:
				
			break;
			case rsaKey:
				pubKey = [[NSData alloc] initWithBytes:publicKey->u.rsa.modulus.data length:publicKey->u.rsa.modulus.len];
			break;
			case dsaKey:
				
			break;
			case dhKey:
				
			break;
			case ecKey:
				
			break;
			case rsaPssKey:
			
			break;
			case rsaOaepKey:
				
			break;
			case fortezzaKey: // deprecated
				
			break;
			case keaKey: // deprecated
				
			break;
			default:
			break;
		}
		
		SECKEY_DestroyPublicKey(publicKey);
		//	PORT_Free(publicKey);
	}
	
	return pubKey;
}


- (NSData *)spkiSHA256Fingerprint
{
	SECItem *spki =	SECKEY_EncodeDERSubjectPublicKeyInfo(CERT_ExtractPublicKey(_nssCertificate));
	
	const SECHashObject *ho;
	
	uint8_t hash_val[64];
	size_t hash_len = 0;
	
	ho = HASH_GetHashObject(HASH_AlgSHA256);
	
	NSAssert(ho->length >= 16, @"hash object length is inappropriate");  // Can't happen
	
	SECStatus rv = HASH_HashBuf(ho->type, hash_val,
								spki->data,
								spki->len);
	
	if (rv != SECSuccess) {
		return nil;
	}
	
	hash_len = ho->length;
	
	NSData *data = [NSData dataWithBytes:hash_val length:hash_len];

	return data;
}


- (NSString *)publicKeyString
{
	NSString *pubKeyString = nil;
	
	SECKEYPublicKey *publicKey = CERT_ExtractPublicKey(_nssCertificate);
	
	if (publicKey) {
		switch (publicKey->keyType) {
			case nullKey:
				
				break;
			case rsaKey:
			{
				NSString *temp = getHexStringFromBuffer(publicKey->u.rsa.modulus.data, publicKey->u.rsa.modulus.len);
				
				pubKeyString = temp;
			}
				break;
			case dsaKey:
				
				break;
			case dhKey:
				
				break;
			case ecKey:
				
				break;
			case rsaPssKey:
				
				break;
			case rsaOaepKey:
				
				break;
			case fortezzaKey: // deprecated
				
				break;
			case keaKey: // deprecated
				
				break;
			default:
				break;
		}
		
		SECKEY_DestroyPublicKey(publicKey);
		//	PORT_Free(publicKey);
	}
	
	return pubKeyString;
}


- (NSString *)publicKeyAlgorithm
{
	NSString *algo = nil;

	SECKEYPublicKey *publicKey = CERT_ExtractPublicKey(_nssCertificate);
	
	if (publicKey) {
		switch (publicKey->keyType) {
			case nullKey:
				algo = @"Null";
				break;
			case rsaKey:
				algo = @"RSA";
				break;
			case dsaKey:
				algo = @"DSA";
				break;
			case dhKey:
				algo = @"DH";
				break;
			case ecKey:
				algo = @"EC";
				break;
			case rsaPssKey:
				algo = @"RSAPSS";
				break;
			case rsaOaepKey:
				algo = @"RSAOAEP";
				break;
			case fortezzaKey: // deprecated
				algo = @"FORTEZZA";
				break;
			case keaKey: // deprecated
				algo = @"KEA";
				break;
			default:
				break;
		}
		
		SECKEY_DestroyPublicKey(publicKey);
		//	PORT_Free(publicKey);
	}

	return algo;
}


- (NSData *)serialNumber
{
	NSData *serialNumber = nil;
	
	serialNumber = [[NSData alloc] initWithBytes:_nssCertificate->serialNumber.data length:_nssCertificate->serialNumber.len];
	
	return serialNumber;
}


- (NSString *)serialNumberString
{
	NSString *serialNumber = getHexStringFromBuffer(_nssCertificate->serialNumber.data, _nssCertificate->serialNumber.len);
	
	return serialNumber;
}


- (NSDate *)notValidAfter
{
	NSDate *notValidAfter = nil;
	
	PRTime notBefore = 0;
	PRTime notAfter = 0;
	SECStatus status =  CERT_GetCertTimes(_nssCertificate, &notBefore, &notAfter);
	if (status == SECSuccess) {
		notValidAfter = [NSDate dateWithTimeIntervalSince1970:((double)notAfter / 1000000.0)]; // PRTime is in microseconds
	}
	return notValidAfter;
}


- (NSDate *)notValidBefore
{
	NSDate *notValidbefore = nil;
	
	PRTime notBefore = 0;
	PRTime notAfter = 0;
	SECStatus status =  CERT_GetCertTimes(_nssCertificate, &notBefore, &notAfter);
	if (status == SECSuccess) {
		notValidbefore = [NSDate dateWithTimeIntervalSince1970:((double)notBefore / 1000000.0)]; // PRTime is in microseconds
	}
	return notValidbefore;
}


#pragma mark - Conversions

- (NSData *)toDER
{
	NSData *derData = [[NSData alloc] initWithBytes:_nssCertificate->derCert.data length:_nssCertificate->derCert.len];
	
	return derData;
}


#pragma mark - Equality and validation

- (BOOL)isEqualByFingerprints:(SSLCertificate *)otherCertificate
{
	if (self.sha1_fingerprint.length >= 16 &&
		otherCertificate.sha1_fingerprint.length >= 16 &&
		self.sha1_fingerprint.length == otherCertificate.sha1_fingerprint.length &&
		self.md5_fingerprint.length >= 16 &&
		otherCertificate.md5_fingerprint.length >= 16 &&
		self.md5_fingerprint.length == otherCertificate.md5_fingerprint.length) {
		
		int result_sha1 = memcmp(self.sha1_fingerprint.data, otherCertificate.sha1_fingerprint.data, self.sha1_fingerprint.length);
		int result_md5 = memcmp(self.md5_fingerprint.data, otherCertificate.md5_fingerprint.data, self.md5_fingerprint.length);
		
		return (result_sha1 == 0 && result_md5 == 0);
	}
	
	return NO;
}


- (BOOL)isValid
{
	BOOL isValid = NO;
	
	SECCertTimeValidity timeValidity = CERT_CheckCertValidTimes(_nssCertificate, PR_Now(), 0);
	
	if (timeValidity == secCertTimeValid) {
		isValid = YES;
	}
	
	return isValid;
}


- (BOOL)isEqualBySPKIsha256Fingerprint:(SSLCertificate *)otherCertificate
{
	return [[self spkiSHA256Fingerprint] isEqualToData:[otherCertificate spkiSHA256Fingerprint]];
}


- (BOOL)hasTheSameSPKI_SHA256Fingerprint:(NSData *)skpiSHA256Fingerprint
{
	return [[self spkiSHA256Fingerprint] isEqualToData:skpiSHA256Fingerprint];
}


#pragma mark - Fingerprint generation

- (BOOL)fingerprint:(SSLCertificateFingerprint *)outFingerprint withAlgorithm:(HashAlgorithm)algorithm
{
	if (!outFingerprint) {
		return NO;
	}
	
	const SECHashObject *ho;
	HASH_HashType hash_type;
	
	if (algorithm == HashAlgorithm_MD5) {
		hash_type = HASH_AlgMD5;
	} else if (algorithm == HashAlgorithm_SHA1) {
		hash_type = HASH_AlgSHA1;
		// HASH_AlgSHA224 is not supported in the chromium linux build system.
#if 0
	} else if (algorithm == HashAlgorithm_SHA224) {
		hash_type = HASH_AlgSHA224;
#endif
	} else if (algorithm == HashAlgorithm_SHA256) {
		hash_type = HASH_AlgSHA256;
	} else if (algorithm == HashAlgorithm_SHA384) {
		hash_type = HASH_AlgSHA384;
	} else if (algorithm == HashAlgorithm_SHA512) {
		hash_type = HASH_AlgSHA512;
	} else {
		return NO;
	}
	
	uint8_t hash_val[64];
	size_t hash_len = 0;
	
	ho = HASH_GetHashObject(hash_type);
	
	NSAssert(ho->length >= 16, @"hash object length is inappropriate");  // Can't happen
	
	
	
	SECStatus rv = HASH_HashBuf(ho->type, hash_val,
								_nssCertificate->derCert.data,
								_nssCertificate->derCert.len);
	if (rv != SECSuccess) {
		return NO;
	}
	
	hash_len = ho->length;
	
	outFingerprint->length = hash_len;
	memmove(outFingerprint->data, hash_val, hash_len);
	
	return YES;
}


#pragma mark - Public Class utility methods

+ (NSString *)stringRepresentationForFingerprint:(SSLCertificateFingerprint)fingerprint
{
	NSString *nsHashString = getHexStringFromBuffer(fingerprint.data, fingerprint.length);
		
	return nsHashString;
}


@end

#pragma mark - Utility Functions

NSString* getHexStringFromBuffer(uint8_t *buffer, size_t length)
{
	NSString *hexString = @"";
	@autoreleasepool {
		if (buffer && length > 0) {
			for (size_t i = 0; i < length; i++) {
				hexString = [hexString stringByAppendingFormat:@"%02hhX", buffer[i]];
				if (i + 1 < length) {
					hexString = [hexString stringByAppendingString:@" "];
				}
			}
		}
	}
	
	return [hexString length] > 0 ? hexString : nil;
}


#pragma mark - Utility Functions for Native -> NSS conversion

CERTCertificate* CreateNSSCertHandleFromOSHandle(SecCertificateRef cert_handle)
{
	CFDataRef cert_data = SecCertificateCopyData(cert_handle);
	CERTCertificate* cert = CreateNSSCertHandleFromBytes((const char*)(CFDataGetBytePtr(cert_data)), CFDataGetLength(cert_data));
	CFRelease(cert_data);
	return cert;
}


CERTCertificate* CreateNSSCertHandleFromBytes(const char* data, int length)
{
	if (length < 0)
		return NULL;
	if (!NSS_IsInitialized())
		return NULL;
	SECItem der_cert;
	der_cert.data = (unsigned char*)((char*)(data));
	der_cert.len = length;
	der_cert.type = siDERCertBuffer;
	// Parse into a certificate structure.
	return CERT_NewTempCertificate(CERT_GetDefaultCertDB(), &der_cert, NULL,
								   PR_FALSE, PR_TRUE);
}
