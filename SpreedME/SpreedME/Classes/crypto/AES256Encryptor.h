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

extern NSString * const kSMCryptoInitVectorKey;
extern NSString * const kSMCryptoVersionKey;
extern NSString * const kSMCryptoSaltKey;
extern NSString * const kSMCryptoKeySizeKey;
extern NSString * const kSMCryptoIterationNumberKey;
extern NSString * const kSMCryptoCipherKey;
extern NSString * const kSMCryptoCipherTextFileNameKey;
extern NSString * const kSMCryptoCipherTextKey;
extern NSString * const kSMCryptoModeKey;

extern NSString * const kSMCryptoCCMMode;
extern NSString * const kSMCryptoCipherAES;


//	{"iv":"tsQVHuuURg1DVPcyHQc8dQ==",
//	"v":1,
//	"iter":1000,
//	"ks":128,
//	"mode":"ccm",
//	"cipher":"aes",
//	"salt":"E1E1JQ==",
//	"cipher_text":"/sE6Hc7VN4oh8xGP"}


@interface AES256Encryptor : NSObject

// These methods greatly depend on key string, can be insecure!
- (NSData *)encryptString:(NSString *)plaintext withKey:(NSString *)key iv:(NSData **)iv;
- (NSString *)decryptData:(NSData *)ciphertext withKey:(NSString *)key andIV:(NSData *)iv;

// These methods will return nil if key is not 32 byte long
- (NSData *)encryptString:(NSString *)plaintext withKeyData:(NSData *)key iv:(NSData **)iv;
- (NSString *)decryptData:(NSData *)ciphertext withKeyData:(NSData *)key andIV:(NSData *)iv;

+ (NSData *)randomDataOfLength:(size_t)length;

// files
- (BOOL)saveDataEncrypted:(NSData *)dataToEncrypt withKeyData:(NSData *)keyData toPath:(NSString *)path;
- (NSData *)loadDataFromEncryptedFileAtPath:(NSString *)path withKeyData:(NSData *)keyData;

// This method will create 2 files in given directory: data.bin meta.json
- (BOOL)saveDataEncrypted:(NSData *)dataToEncrypt withPassword:(NSString *)password toDir:(NSString *)dir;
- (NSData *)loadDataFromEncryptedFileInDir:(NSString *)dir withPassword:(NSString *)password;


// These are convenience methods to encrypt/decrypt data with metadata dictionary
- (NSDictionary *)encryptData:(NSData *)dataToEncrypt
				 withPassword:(NSString *)password
					  outData:(NSData * __autoreleasing *)outData;
- (NSData *)decryptData:(NSData *)encData metadataDict:(NSDictionary *)metadata withPassword:(NSString *)password;

// These are convenient methods to encrypt/decrypt data as a json encoded string
- (NSString *)jsonStringEncryptData:(NSData *)dataToEncrypt withPassword:(NSString *)password;
- (NSData *)decryptDataFromJsonString:(NSString *)jsonStr withPassword:(NSString *)password;

// test
- (BOOL)encryptDecryptTestWith:(int)numberOfRandomStrings;

@end
