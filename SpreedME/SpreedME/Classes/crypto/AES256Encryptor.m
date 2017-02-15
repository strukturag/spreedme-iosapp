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

#import "AES256Encryptor.h"

#import "JSONKit.h"

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>


NSString * const kSMCryptoInitVectorKey					= @"iv";
NSString * const kSMCryptoVersionKey					= @"v";
NSString * const kSMCryptoSaltKey						= @"salt";
NSString * const kSMCryptoKeySizeKey					= @"ks";
NSString * const kSMCryptoIterationNumberKey			= @"iter";
NSString * const kSMCryptoCipherKey						= @"cipher";
NSString * const kSMCryptoCipherTextFileNameKey			= @"ct_path";
NSString * const kSMCryptoCipherTextKey					= @"cipher_text";
NSString * const kSMCryptoModeKey						= @"mode";

NSString * const kSMCryptoCCMMode			= @"ccm";
NSString * const kSMCryptoCipherAES			= @"aes";


NSString * const kSMCryptoMetadataFileName = @"meta.json";
NSString * const kSMCryptoCipherTextFileName = @"data.bin";


@implementation NSData (AES256Encryptor)


- (NSData *)AES256EncryptWithKey:(NSString *)key iv:(NSData **)iv
{
	// 'key' should be 32 bytes for AES256, will be null-padded otherwise
	char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
	bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
	
	// fetch key data
	[key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
	
	NSData *keyData = [[NSData alloc] initWithBytes:keyPtr length:kCCKeySizeAES256];
	
	return [self AES256EncryptWithKeyData:keyData iv:iv];
}


- (NSData *)AES256DecryptWithKey:(NSString *)key iv:(NSData *)iv {
	// 'key' should be 32 bytes for AES256, will be null-padded otherwise
	char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
	bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
	
	// fetch key data
	[key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
	
	NSData *keyData = [[NSData alloc] initWithBytes:keyPtr length:kCCKeySizeAES256];
	return [self AES256DecryptWithKeyData:keyData iv:iv];
}


- (NSData *)AES256EncryptWithKeyData:(NSData *)key iv:(NSData **)iv
{
	// 'key' should be 32 bytes for AES256
	if (key.length != kCCKeySizeAES256) {
		*iv = nil;
		return nil;
	}
		
	NSUInteger dataLength = [self length];
	
	//See the doc: For block ciphers, the output size will always be less than or
	//equal to the input size plus the size of one block.
	//That's why we need to add the size of one block here
	size_t bufferSize = dataLength + kCCBlockSizeAES128;
	void *buffer = malloc(bufferSize);
	
	NSData *data = [AES256Encryptor randomDataOfLength:kCCBlockSizeAES128];
	if (data) {
		*iv = data;
	} else {
		*iv = nil;
		return nil;
	}
	
	size_t numBytesEncrypted = 0;
	CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
                                          key.bytes, kCCKeySizeAES256,
                                          (*iv).bytes /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesEncrypted);
	if (cryptStatus == kCCSuccess) {
		//the returned NSData takes ownership of the buffer and will free it on deallocation
		return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
	}
    
	free(buffer); //free the buffer;
	return nil;
}


- (NSData *)AES256DecryptWithKeyData:(NSData *)key iv:(NSData *)iv
{
	// 'key' should be 32 bytes for AES256
	if (key.length != kCCKeySizeAES256) {
		return nil;
	}
	
	NSUInteger dataLength = [self length];
	
	//See the doc: For block ciphers, the output size will always be less than or
	//equal to the input size plus the size of one block.
	//That's why we need to add the size of one block here
	size_t bufferSize = dataLength + kCCBlockSizeAES128;
	void *buffer = malloc(bufferSize);
	
	size_t numBytesDecrypted = 0;
	CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
                                          key.bytes, kCCKeySizeAES256,
                                          iv.bytes ? iv.bytes : NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesDecrypted);
	
	if (cryptStatus == kCCSuccess) {
		//the returned NSData takes ownership of the buffer and will free it on deallocation
		return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
	}
	
	free(buffer); //free the buffer;
	return nil;
}


@end


@implementation AES256Encryptor


- (NSData *)encryptString:(NSString *)plaintext withKey:(NSString *)key iv:(NSData **)iv
{
	return [[plaintext dataUsingEncoding:NSUTF8StringEncoding] AES256EncryptWithKey:key iv:iv];
}


- (NSString*)decryptData:(NSData*)ciphertext withKey:(NSString*)key andIV:(NSData *)iv
{
	return [[NSString alloc] initWithData:[ciphertext AES256DecryptWithKey:key iv:iv]
	                              encoding:NSUTF8StringEncoding];
}


- (NSData *)encryptString:(NSString *)plaintext withKeyData:(NSData *)key iv:(NSData **)iv
{
	return [[plaintext dataUsingEncoding:NSUTF8StringEncoding] AES256EncryptWithKeyData:key iv:iv];
}


- (NSString *)decryptData:(NSData *)ciphertext withKeyData:(NSData *)key andIV:(NSData *)iv
{
	return [[NSString alloc] initWithData:[ciphertext AES256DecryptWithKeyData:key iv:iv]
								 encoding:NSUTF8StringEncoding];
}


- (NSDictionary *)encryptData:(NSData *)dataToEncrypt
				 withPassword:(NSString *)password
					  outData:(NSData * __autoreleasing *)outData
{
	if (dataToEncrypt.length > 0 && password.length > 0) {
		
		NSData *salt = [AES256Encryptor randomDataOfLength:16];
		
		if (!salt) {
			return nil;
		}
		
		// since we don't expect to transfer these files to other devices
		// we can safely calculate number of iterations for current device.
		// Even if we transfer this to other device it just might take more time to
		// derive the key there.
		uint numberOfIterations = CCCalibratePBKDF(kCCPBKDF2,
												   password.length,
												   salt.length,
												   kCCPRFHmacAlgSHA256,
												   32, // expected key length for SHA256
												   100); // expected time in msec
		
		
		char *passwordPtr = malloc(password.length + 1); // room for terminator (unused)
		bzero(passwordPtr, sizeof(passwordPtr)); // fill with zeroes (for padding)
		
		// fetch key data
		[password getCString:passwordPtr maxLength:(password.length + 1) encoding:NSUTF8StringEncoding];
		
		uint8_t key[32]; // expected key length for SHA256
		
		int result = CCKeyDerivationPBKDF(kCCPBKDF2,
										  passwordPtr,
										  password.length,
										  (uint8_t *)salt.bytes,
										  salt.length,
										  kCCPRFHmacAlgSHA256,
										  numberOfIterations,
										  key,
										  32); // expected key length for SHA256
		if (result != kCCSuccess) {
			spreed_me_log("Failed to derive key with error %d", result);
			bzero(passwordPtr, sizeof(passwordPtr));
			free(passwordPtr);
			return nil;
		}
		
		
		NSData *keyData = [[NSData alloc] initWithBytes:key length:sizeof(key)];
		
		
		NSData *iv = nil; // iv length in our case is kCCBlockSizeAES128
		NSData *encryptedData = [dataToEncrypt AES256EncryptWithKeyData:keyData iv:&iv];
		
		if (!iv || !encryptedData) {
			spreed_me_log("Couldn't create init vector while encrypting or couldn't encrypt data");
			bzero(passwordPtr, sizeof(passwordPtr));
			free(passwordPtr);
			return nil;
		}
		
		NSDictionary *metadataDict = @{kSMCryptoInitVectorKey : [iv base64Encoding],
									   kSMCryptoVersionKey : @(1),
									   kSMCryptoSaltKey : [salt base64Encoding],
									   kSMCryptoKeySizeKey : @(256),
									   kSMCryptoIterationNumberKey : @(numberOfIterations),
									   kSMCryptoCipherKey : kSMCryptoCipherAES,
									   kSMCryptoModeKey	: kSMCryptoCCMMode};
		
		bzero(passwordPtr, sizeof(passwordPtr));
		free(passwordPtr);
		
		*outData = encryptedData;
		return metadataDict;
	}
	
	return nil;
}


- (NSData *)decryptData:(NSData *)encData metadataDict:(NSDictionary *)metadata withPassword:(NSString *)password
{
	if (encData && metadata && password.length > 0) {
		
		NSData *iv = [[NSData alloc] initWithBase64Encoding:[metadata objectForKey:kSMCryptoInitVectorKey]];
		int version = [[metadata objectForKey:kSMCryptoVersionKey] intValue];
		NSData *salt = [[NSData alloc] initWithBase64Encoding:[metadata objectForKey:kSMCryptoSaltKey]];
		NSUInteger iter = [[metadata objectForKey:kSMCryptoIterationNumberKey] unsignedIntegerValue];
		NSString *cipher = [metadata objectForKey:kSMCryptoCipherKey];
		NSInteger keySize = [[metadata objectForKey:kSMCryptoKeySizeKey] integerValue];
		NSString *mode = [metadata objectForKey:kSMCryptoModeKey];
		
		if (version == 1 &&
			salt.length > 0 &&
			iv.length > 0 &&
			iter > 0 &&
			[cipher isEqualToString:kSMCryptoCipherAES] &&
			keySize == 256 &&
			[mode isEqualToString:kSMCryptoCCMMode]) {
			
			
			char *passwordPtr = malloc(password.length + 1); // room for terminator (unused)
			bzero(passwordPtr, sizeof(passwordPtr)); // fill with zeroes (for padding)
			
			// fetch key data
			[password getCString:passwordPtr maxLength:(password.length + 1) encoding:NSUTF8StringEncoding];
			
			uint8_t key[32]; // expected key length for SHA256
			
			int result = CCKeyDerivationPBKDF(kCCPBKDF2,
											  passwordPtr,
											  password.length,
											  (uint8_t *)salt.bytes,
											  salt.length,
											  kCCPRFHmacAlgSHA256,
											  iter,
											  key,
											  32); // expected key length for SHA256
			if (result != kCCSuccess) {
				spreed_me_log("Failed to derive key with error %d", result);
				return nil;
			}
			NSData *keyData = [[NSData alloc] initWithBytes:key length:sizeof(key)];
			
			NSData *decrData = [encData AES256DecryptWithKeyData:keyData iv:iv];
			
			bzero(passwordPtr, sizeof(passwordPtr));
			free(passwordPtr);
			
			return decrData;
		} else {
			spreed_me_log("Unsupported encrypted metadata!");
			return nil;
		}
	}
	
	return nil;
}


- (NSString *)jsonStringEncryptData:(NSData *)dataToEncrypt withPassword:(NSString *)password
{
	NSString *resultString = nil;
	
	if (dataToEncrypt.length > 0 && password.length > 0) {
		NSData *encData = nil;
		NSDictionary *metadataDict = [self encryptData:dataToEncrypt withPassword:password outData:&encData];
		if (metadataDict && encData) {
			NSMutableDictionary *metadataMutableDict = [NSMutableDictionary dictionaryWithDictionary:metadataDict];
			NSString *cipherText = [encData base64Encoding];
			[metadataMutableDict setObject:cipherText forKey:kSMCryptoCipherTextKey];
			
			resultString = [metadataMutableDict JSONString];
		}
	}
	
	return resultString;
}


- (NSData *)decryptDataFromJsonString:(NSString *)jsonStr withPassword:(NSString *)password
{
	NSData *decData = nil;
	
	if (jsonStr.length > 0 && password.length > 0) {
		NSDictionary *dict = [jsonStr objectFromJSONString];
		NSData *encData = [[NSData alloc] initWithBase64Encoding:[dict objectForKey:kSMCryptoCipherTextKey]];
		decData = [self decryptData:encData metadataDict:dict withPassword:password];
	}
	
	return decData;
}


#pragma mark - Files

- (BOOL)saveDataEncrypted:(NSData *)dataToEncrypt withKeyData:(NSData *)keyData toPath:(NSString *)path
{
	BOOL success = NO;
	
	if (dataToEncrypt.length > 0 && keyData.length == 32 && path.length > 0) {
		
		NSData *iv = nil; // iv length in our case is kCCBlockSizeAES128
		NSData *encryptedData = [dataToEncrypt AES256EncryptWithKeyData:keyData iv:&iv];
		if (encryptedData && iv) {
			NSMutableData *wholeFileData = [NSMutableData dataWithData:iv];
			
			[wholeFileData appendData:encryptedData];
			
			success = [wholeFileData writeToFile:path atomically:YES];
			if (success) {
				spreed_me_log("saved data to path %s", [path cDescription]);
			}
		}
	}
	
	return success;
}


- (NSData *)loadDataFromEncryptedFileAtPath:(NSString *)path withKeyData:(NSData *)keyData
{
	NSData *decrData = nil;
	if (path.length > 0 && keyData.length == 32) {
		NSData *loadedData = [NSData dataWithContentsOfFile:path];
		// check if data size is bigger than supposedly saved iv
		if (loadedData.length > kCCBlockSizeAES128) {
			NSData *iv = [NSData dataWithBytes:loadedData.bytes length:kCCBlockSizeAES128];
			NSData *dataToDecryt = [NSData dataWithBytes:loadedData.bytes + kCCBlockSizeAES128 length:loadedData.length - kCCBlockSizeAES128];
			
			decrData = [dataToDecryt AES256DecryptWithKeyData:keyData iv:iv];
		}
	}
	
	return decrData;
}


// This method will create 2 files in given directory: data.bin meta.json
- (BOOL)saveDataEncrypted:(NSData *)dataToEncrypt withPassword:(NSString *)password toDir:(NSString *)dir
{
	BOOL success = NO;
	
	if (dataToEncrypt.length > 0 && password.length > 0 && dir.length > 0) {
		
		NSData *encryptedData = nil;
		NSDictionary *metadataDict = [self encryptData:dataToEncrypt withPassword:password outData:&encryptedData];
		
		if (metadataDict) {
			NSMutableDictionary *metadataMutableDict = [NSMutableDictionary dictionaryWithDictionary:metadataDict];
			
			NSString *binFileName = kSMCryptoCipherTextFileName;
			NSString *metaFilePath = [dir stringByAppendingPathComponent:kSMCryptoMetadataFileName];
			
			[metadataMutableDict setObject:binFileName forKey:kSMCryptoCipherTextFileNameKey];
			
			NSString *binFilePath = [dir stringByAppendingPathComponent:binFileName];
			
			if (encryptedData) {
				
				NSString *json = [metadataMutableDict JSONString];
				NSError *error = nil;
				success = [json writeToFile:metaFilePath
								 atomically:YES
								   encoding:NSUTF8StringEncoding
									  error:&error];
				if (!success) {
					spreed_me_log("Couldn't save metadata to %s with error %s", [metaFilePath cDescription], [error cDescription]);
					return NO;
				}
				
				success = [encryptedData writeToFile:binFilePath atomically:YES];
			}
			
		} else {
			spreed_me_log("Couldn't encrypt data to save");
		}
	}
	
	return success;
}


- (NSData *)loadDataFromEncryptedFileInDir:(NSString *)dir withPassword:(NSString *)password
{
	NSData *decrData = nil;
	if (dir.length > 0 && password.length > 0) {
		
		NSString *metaFilePath = [dir stringByAppendingPathComponent:kSMCryptoMetadataFileName];
		
		NSString *jsonString = [[NSString alloc] initWithContentsOfFile:metaFilePath
															   encoding:NSUTF8StringEncoding
																  error:NULL];
		
		if (jsonString.length <= 0) {
			spreed_me_log("Couldn't read metadata file at path %s", [metaFilePath cDescription]);
			return nil;
		}
		
		NSDictionary *json = [jsonString objectFromJSONString];
		if (!json) {
			spreed_me_log("Couldn't parse json file at path %s", [metaFilePath cDescription]);
			return nil;
		}
		
	
		NSString *binDataName = [json objectForKey:kSMCryptoCipherTextFileNameKey];
		
		
		if (binDataName.length > 0) {
			
			NSString *binDataPath = [dir stringByAppendingPathComponent:binDataName];
			
			NSError *error = nil;
			NSData *loadedData = [NSData dataWithContentsOfFile:binDataPath options:0 error:&error];
			if (loadedData.length > 0) {
				decrData = [self decryptData:loadedData metadataDict:json withPassword:password];
			} else if (error) {
				spreed_me_log("Couldn't load data %s", [error cDescription]);
			}
			
		} else {
			spreed_me_log("No binDataName for file to decrypt!");
			return nil;
		}
	}
	
	return decrData;
}


#pragma mark - Utils

+ (NSData *)randomDataOfLength:(size_t)length
{
	NSMutableData *data = [NSMutableData dataWithLength:length];
	
	int result = SecRandomCopyBytes(kSecRandomDefault,
									length,
									data.mutableBytes);
	if (result != 0) {
		return nil;
	}
	
	return [NSData dataWithData:data];
}


- (BOOL)encryptDecryptTestWith:(int)numberOfRandomStrings
{
    NSInteger numberOfSuccess = 0;
    
    for (int i=0; i<numberOfRandomStrings; i++) {
        @autoreleasepool {
            NSString *testString = [self randomStringWithLength:i];
            NSString *testKey = [self randomStringWithLength:numberOfRandomStrings/2];
			NSData *iv = nil;
            NSData *encryptedTestString = [self encryptString:testString withKey:testKey iv:&iv];
            NSString *decryptedTestString = [self decryptData:encryptedTestString withKey:testKey andIV:iv];
            
            if ([testString isEqualToString:decryptedTestString]) {
                numberOfSuccess ++;
            }
        }
    }
	
    NSLog(@"Number of Success : %d of %d", numberOfSuccess, numberOfRandomStrings);
    
	if (numberOfSuccess == numberOfRandomStrings) {
        return YES;
    }
    
    return NO;
}


- (NSString *)randomStringWithLength:(int)len {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
    }
    
    return randomString;
}


@end