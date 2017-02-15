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

#include <string>
#include <sys/time.h>
#include <sys/stat.h>


#include "utils.h"
#include "utils_objc.h"
#include "utils_objcpp.h"

// Prototypes
void deleteLargeLogFileIfNeeded();


static FILE *spreed_me_log_file = NULL;

const char *AudioFileName()
{
	NSString *appSupportDir = applicationSupportDirectory();
	if (appSupportDir) {
		NSString *appFile = [appSupportDir stringByAppendingPathComponent:@"inputaudio.wav"];
		return [appFile cStringUsingEncoding:NSUTF8StringEncoding];
	} else {
		return NULL;
	}
}


const char *LogFileName()
{
	NSString *appSupportDir = applicationSupportDirectory();
	if (appSupportDir) {
		NSString *appFile = [appSupportDir stringByAppendingPathComponent:@"spreed_me_log.log"];
		return [appFile cStringUsingEncoding:NSUTF8StringEncoding];
	} else {
		return NULL;
	}
}


NSString *applicationSupportDirectory()
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *appSupportDirectory = [paths objectAtIndex:0];
	
	NSString *appSettingsFilesDirName = [[NSBundle mainBundle] bundleIdentifier];
	NSString *appSettingsFilesDir = [appSupportDirectory stringByAppendingPathComponent:appSettingsFilesDirName];
	
	BOOL isDirectory = YES;
	if (![[NSFileManager defaultManager] fileExistsAtPath:appSettingsFilesDir isDirectory:&isDirectory]) {
		NSError *error = nil;
		BOOL succes = [[NSFileManager defaultManager] createDirectoryAtPath:appSettingsFilesDir withIntermediateDirectories:YES attributes:nil error:&error];
		if (!succes) {
			spreed_me_log("We couldn't create directory to store app settings!");
		} else {
			return nil;
		}
	}
	
	// Exclude from iTunes/iCloud backup
	NSError *error = nil;
	NSURL *url = [NSURL fileURLWithPath:appSettingsFilesDir];
	if (![url setResourceValue:@YES
						forKey:NSURLIsExcludedFromBackupKey
						 error:&error]) {
		spreed_me_log("Error excluding %s from backup %s", [[url lastPathComponent] cDescription], [error.localizedDescription cDescription]);
	}
		
	return appSettingsFilesDir;
}

#ifdef SPREEDME_ALLOW_LOGGING

int init_spreed_me_log()
{
	deleteLargeLogFileIfNeeded();
	
	if (spreed_me_log_file == NULL) {
		char error[128];
		
		if (!(spreed_me_log_file = fopen(LogFileName(), "a"))) {
			printf(error, "spreed_me_log() failed to open %s.\n", LogFileName());
			return -2;
		} else {
			NSURL *logFileUrl = [NSURL fileURLWithPath:[NSString stringWithCString:LogFileName() encoding:NSUTF8StringEncoding]];
			if ([[NSFileManager defaultManager] fileExistsAtPath:[logFileUrl path]]) {
				NSError *error = nil;
				BOOL success = [logFileUrl setResourceValue:[NSNumber numberWithBool:YES]
													 forKey:NSURLIsExcludedFromBackupKey
													  error:&error];
				if(!success) {
					NSLog(@"Error excluding %@ from backup %@", [logFileUrl lastPathComponent], error);
				}
			}
		}
	}
	return 0;
}


int spreed_me_log(const char *fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	
	char *message = NULL;
		
	int n = vasprintf(&message, fmt, args);
	
	if (n != -1 && message != NULL && spreed_me_log_file) {
		
		timeval tp;
		gettimeofday(&tp, 0);
		
		time_t t = time(NULL);
		struct tm tm = *localtime(&t);
		
		const char *appName = [[[NSProcessInfo processInfo] processName] cStringUsingEncoding:NSUTF8StringEncoding];
		int processId = [[NSProcessInfo processInfo] processIdentifier];
		
		fprintf(spreed_me_log_file, "%d-%02d-%02d %02d:%02d:%02d.%03d %s[%d] %s\n", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec, tp.tv_usec/1000, appName, processId, message);
		
//		printf("%d-%02d-%02d %02d:%02d:%02d.%03d %s[%d] %s\n", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec, tp.tv_usec/1000, appName, processId, message);
		
#ifdef SPREEDME_LOG_PRINT_TO_CONSOLE
		NSLog(@"%s", message);
#endif
		
		free(message);
		fflush(spreed_me_log_file);
//		fclose(spreed_me_log_file);
//		spreed_me_log_file = NULL;
		
	} else {
		printf("Could not create log entry.\n");
	}
	
	va_end(args);
	return n;
}

#endif // SPREEDME_ALLOW_LOGGING


off_t fsize(const char *filename) {
    struct stat st;
	
    if (stat(filename, &st) == 0)
        return st.st_size;
	
    return -1;
}


void deleteLargeLogFileIfNeeded()
{
	const off_t kMaxFileSize = 5 * 1024 * 1024; // 5 megabytes
	
	off_t actualSize = fsize(LogFileName());
	
	if (actualSize > kMaxFileSize) {
		int n = remove(LogFileName());
		if (n != 0) {
			printf("Error on deleting log file larger than %lld bytes", kMaxFileSize);
		}
	}
}


NSString *NSStr(const char *cString)
{
	NSString *string = nil;
	if (cString) {
		string = [NSString stringWithCString:cString encoding:NSUTF8StringEncoding];
	}
	return string;
}


NSDictionary * const kCiphersStringDictionary = @{
	@(0x0000) : @"SSL_NULL_WITH_NULL_NULL",
	@(0x0001) : @"SSL_RSA_WITH_NULL_MD5",
	@(0x0002) : @"SSL_RSA_WITH_NULL_SHA",
	@(0x0003) : @"SSL_RSA_EXPORT_WITH_RC4_40_MD5",
	@(0x0004) : @"SSL_RSA_WITH_RC4_128_MD5",
	@(0x0005) : @"SSL_RSA_WITH_RC4_128_SHA",
	@(0x0006) : @"SSL_RSA_EXPORT_WITH_RC2_CBC_40_MD5",
	@(0x0007) : @"SSL_RSA_WITH_IDEA_CBC_SHA",
	@(0x0008) : @"SSL_RSA_EXPORT_WITH_DES40_CBC_SHA",
	@(0x0009) : @"SSL_RSA_WITH_DES_CBC_SHA",
	@(0x000A) : @"SSL_RSA_WITH_3DES_EDE_CBC_SHA",
	@(0x000B) : @"SSL_DH_DSS_EXPORT_WITH_DES40_CBC_SHA",
	@(0x000C) : @"SSL_DH_DSS_WITH_DES_CBC_SHA",
	@(0x000D) : @"SSL_DH_DSS_WITH_3DES_EDE_CBC_SHA",
	@(0x000E) : @"SSL_DH_RSA_EXPORT_WITH_DES40_CBC_SHA",
	@(0x000F) : @"SSL_DH_RSA_WITH_DES_CBC_SHA",
	@(0x0010) : @"SSL_DH_RSA_WITH_3DES_EDE_CBC_SHA",
	@(0x0011) : @"SSL_DHE_DSS_EXPORT_WITH_DES40_CBC_SHA",
	@(0x0012) : @"SSL_DHE_DSS_WITH_DES_CBC_SHA",
	@(0x0013) : @"SSL_DHE_DSS_WITH_3DES_EDE_CBC_SHA",
	@(0x0014) : @"SSL_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA",
	@(0x0015) : @"SSL_DHE_RSA_WITH_DES_CBC_SHA",
	@(0x0016) : @"SSL_DHE_RSA_WITH_3DES_EDE_CBC_SHA",
	@(0x0017) : @"SSL_DH_anon_EXPORT_WITH_RC4_40_MD5",
	@(0x0018) : @"SSL_DH_anon_WITH_RC4_128_MD5",
	@(0x0019) : @"SSL_DH_anon_EXPORT_WITH_DES40_CBC_SHA",
	@(0x001A) : @"SSL_DH_anon_WITH_DES_CBC_SHA",
	@(0x001B) : @"SSL_DH_anon_WITH_3DES_EDE_CBC_SHA",
	@(0x001C) : @"SSL_FORTEZZA_DMS_WITH_NULL_SHA",
	@(0x001D) : @"SSL_FORTEZZA_DMS_WITH_FORTEZZA_CBC_SHA",
	
	/* TLS addenda using AES, per RFC 3268 */
	@(0x002F) : @"TLS_RSA_WITH_AES_128_CBC_SHA",
	@(0x0030) : @"TLS_DH_DSS_WITH_AES_128_CBC_SHA",
	@(0x0031) : @"TLS_DH_RSA_WITH_AES_128_CBC_SHA",
	@(0x0032) : @"TLS_DHE_DSS_WITH_AES_128_CBC_SHA",
	@(0x0033) : @"TLS_DHE_RSA_WITH_AES_128_CBC_SHA",
	@(0x0034) : @"TLS_DH_anon_WITH_AES_128_CBC_SHA",
	@(0x0035) : @"TLS_RSA_WITH_AES_256_CBC_SHA",
	@(0x0036) : @"TLS_DH_DSS_WITH_AES_256_CBC_SHA",
	@(0x0037) : @"TLS_DH_RSA_WITH_AES_256_CBC_SHA",
	@(0x0038) : @"TLS_DHE_DSS_WITH_AES_256_CBC_SHA",
	@(0x0039) : @"TLS_DHE_RSA_WITH_AES_256_CBC_SHA",
	@(0x003A) : @"TLS_DH_anon_WITH_AES_256_CBC_SHA",
	
	/* ECDSA addenda, RFC 4492 */
	@(0xC001) : @"TLS_ECDH_ECDSA_WITH_NULL_SHA"         ,
	@(0xC002) : @"TLS_ECDH_ECDSA_WITH_RC4_128_SHA"      ,
	@(0xC003) : @"TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA" ,
	@(0xC004) : @"TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA"  ,
	@(0xC005) : @"TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA"  ,
	@(0xC006) : @"TLS_ECDHE_ECDSA_WITH_NULL_SHA"        ,
	@(0xC007) : @"TLS_ECDHE_ECDSA_WITH_RC4_128_SHA"     ,
	@(0xC008) : @"TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA",
	@(0xC009) : @"TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA" ,
	@(0xC00A) : @"TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA" ,
	@(0xC00B) : @"TLS_ECDH_RSA_WITH_NULL_SHA"           ,
	@(0xC00C) : @"TLS_ECDH_RSA_WITH_RC4_128_SHA"        ,
	@(0xC00D) : @"TLS_ECDH_RSA_WITH_3DES_EDE_CBC_SHA"   ,
	@(0xC00E) : @"TLS_ECDH_RSA_WITH_AES_128_CBC_SHA"    ,
	@(0xC00F) : @"TLS_ECDH_RSA_WITH_AES_256_CBC_SHA"    ,
	@(0xC010) : @"TLS_ECDHE_RSA_WITH_NULL_SHA"          ,
	@(0xC011) : @"TLS_ECDHE_RSA_WITH_RC4_128_SHA"       ,
	@(0xC012) : @"TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA"  ,
	@(0xC013) : @"TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA"   ,
	@(0xC014) : @"TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA"   ,
	@(0xC015) : @"TLS_ECDH_anon_WITH_NULL_SHA"          ,
	@(0xC016) : @"TLS_ECDH_anon_WITH_RC4_128_SHA"       ,
	@(0xC017) : @"TLS_ECDH_anon_WITH_3DES_EDE_CBC_SHA"  ,
	@(0xC018) : @"TLS_ECDH_anon_WITH_AES_128_CBC_SHA"   ,
	@(0xC019) : @"TLS_ECDH_anon_WITH_AES_256_CBC_SHA"   ,
	
	/* TLS 1.2 addenda, RFC 5246 */
	
	/* Initial state. */
	@(0x0000) : @"TLS_NULL_WITH_NULL_NULL"                   ,
	
	/* Server provided RSA certificate for key exchange. */
	@(0x0001) : @"TLS_RSA_WITH_NULL_MD5"                     ,
	@(0x0002) : @"TLS_RSA_WITH_NULL_SHA"                     ,
	@(0x0004) : @"TLS_RSA_WITH_RC4_128_MD5"                  ,
	@(0x0005) : @"TLS_RSA_WITH_RC4_128_SHA"                  ,
	@(0x000A) : @"TLS_RSA_WITH_3DES_EDE_CBC_SHA"             ,
	//@(0x002F) : @"TLS_RSA_WITH_AES_128_CBC_SHA"            ,
	//@(0x0035) : @"TLS_RSA_WITH_AES_256_CBC_SHA"            ,
	@(0x003B) : @"TLS_RSA_WITH_NULL_SHA256"                  ,
	@(0x003C) : @"TLS_RSA_WITH_AES_128_CBC_SHA256"           ,
	@(0x003D) : @"TLS_RSA_WITH_AES_256_CBC_SHA256"           ,
	
	/* Server-authenticated (and optionally client-authenticated) Diffie-Hellman. */
	@(0x000D) : @"TLS_DH_DSS_WITH_3DES_EDE_CBC_SHA"          ,
	@(0x0010) : @"TLS_DH_RSA_WITH_3DES_EDE_CBC_SHA"          ,
	@(0x0013) : @"TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA"         ,
	@(0x0016) : @"TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA"         ,
	//@(0x0030) : @"TLS_DH_DSS_WITH_AES_128_CBC_SHA"           ,
	//@(0x0031) : @"TLS_DH_RSA_WITH_AES_128_CBC_SHA"           ,
	//@(0x0032) : @"TLS_DHE_DSS_WITH_AES_128_CBC_SHA"          ,
	//@(0x0033) : @"TLS_DHE_RSA_WITH_AES_128_CBC_SHA"          ,
	//@(0x0036) : @"TLS_DH_DSS_WITH_AES_256_CBC_SHA"           ,
	//@(0x0037) : @"TLS_DH_RSA_WITH_AES_256_CBC_SHA"           ,
	//@(0x0038) : @"TLS_DHE_DSS_WITH_AES_256_CBC_SHA"          ,
	//@(0x0039) : @"TLS_DHE_RSA_WITH_AES_256_CBC_SHA"          ,
	@(0x003E) : @"TLS_DH_DSS_WITH_AES_128_CBC_SHA256"        ,
	@(0x003F) : @"TLS_DH_RSA_WITH_AES_128_CBC_SHA256"        ,
	@(0x0040) : @"TLS_DHE_DSS_WITH_AES_128_CBC_SHA256"       ,
	@(0x0067) : @"TLS_DHE_RSA_WITH_AES_128_CBC_SHA256"       ,
	@(0x0068) : @"TLS_DH_DSS_WITH_AES_256_CBC_SHA256"        ,
	@(0x0069) : @"TLS_DH_RSA_WITH_AES_256_CBC_SHA256"        ,
	@(0x006A) : @"TLS_DHE_DSS_WITH_AES_256_CBC_SHA256"       ,
	@(0x006B) : @"TLS_DHE_RSA_WITH_AES_256_CBC_SHA256"       ,
	
	/* Completely anonymous Diffie-Hellman */
	@(0x0018) : @"TLS_DH_anon_WITH_RC4_128_MD5"              ,
	@(0x001B) : @"TLS_DH_anon_WITH_3DES_EDE_CBC_SHA"         ,
	//@(0x0034) : @"TLS_DH_anon_WITH_AES_128_CBC_SHA"          ,
	//@(0x003A) : @"TLS_DH_anon_WITH_AES_256_CBC_SHA"          ,
	@(0x006C) : @"TLS_DH_anon_WITH_AES_128_CBC_SHA256"       ,
	@(0x006D) : @"TLS_DH_anon_WITH_AES_256_CBC_SHA256"       ,
	
	/* Addendum from RFC 4279, TLS PSK */
	
	@(0x008A) : @"TLS_PSK_WITH_RC4_128_SHA"                  ,
	@(0x008B) : @"TLS_PSK_WITH_3DES_EDE_CBC_SHA"             ,
	@(0x008C) : @"TLS_PSK_WITH_AES_128_CBC_SHA"              ,
	@(0x008D) : @"TLS_PSK_WITH_AES_256_CBC_SHA"              ,
	@(0x008E) : @"TLS_DHE_PSK_WITH_RC4_128_SHA"              ,
	@(0x008F) : @"TLS_DHE_PSK_WITH_3DES_EDE_CBC_SHA"         ,
	@(0x0090) : @"TLS_DHE_PSK_WITH_AES_128_CBC_SHA"          ,
	@(0x0091) : @"TLS_DHE_PSK_WITH_AES_256_CBC_SHA"          ,
	@(0x0092) : @"TLS_RSA_PSK_WITH_RC4_128_SHA"              ,
	@(0x0093) : @"TLS_RSA_PSK_WITH_3DES_EDE_CBC_SHA"         ,
	@(0x0094) : @"TLS_RSA_PSK_WITH_AES_128_CBC_SHA"          ,
	@(0x0095) : @"TLS_RSA_PSK_WITH_AES_256_CBC_SHA"          ,
	
	/* RFC 4785 - Pre-Shared Key (PSK) Ciphersuites with NULL Encryption */
	
	@(0x002C) : @"TLS_PSK_WITH_NULL_SHA"                     ,
	@(0x002D) : @"TLS_DHE_PSK_WITH_NULL_SHA"                 ,
	@(0x002E) : @"TLS_RSA_PSK_WITH_NULL_SHA"                 ,
	
	/* Addenda from rfc 5288 AES Galois Counter Mode (GCM) Cipher Suites
	 for TLS. */
	@(0x009C) : @"TLS_RSA_WITH_AES_128_GCM_SHA256"           ,
	@(0x009D) : @"TLS_RSA_WITH_AES_256_GCM_SHA384"           ,
	@(0x009E) : @"TLS_DHE_RSA_WITH_AES_128_GCM_SHA256"       ,
	@(0x009F) : @"TLS_DHE_RSA_WITH_AES_256_GCM_SHA384"       ,
	@(0x00A0) : @"TLS_DH_RSA_WITH_AES_128_GCM_SHA256"        ,
	@(0x00A1) : @"TLS_DH_RSA_WITH_AES_256_GCM_SHA384"        ,
	@(0x00A2) : @"TLS_DHE_DSS_WITH_AES_128_GCM_SHA256"       ,
	@(0x00A3) : @"TLS_DHE_DSS_WITH_AES_256_GCM_SHA384"       ,
	@(0x00A4) : @"TLS_DH_DSS_WITH_AES_128_GCM_SHA256"        ,
	@(0x00A5) : @"TLS_DH_DSS_WITH_AES_256_GCM_SHA384"        ,
	@(0x00A6) : @"TLS_DH_anon_WITH_AES_128_GCM_SHA256"       ,
	@(0x00A7) : @"TLS_DH_anon_WITH_AES_256_GCM_SHA384"       ,
	
	/* RFC 5487 - PSK with SHA-256/384 and AES GCM */
	@(0x00A8) : @"TLS_PSK_WITH_AES_128_GCM_SHA256"           ,
	@(0x00A9) : @"TLS_PSK_WITH_AES_256_GCM_SHA384"           ,
	@(0x00AA) : @"TLS_DHE_PSK_WITH_AES_128_GCM_SHA256"       ,
	@(0x00AB) : @"TLS_DHE_PSK_WITH_AES_256_GCM_SHA384"       ,
	@(0x00AC) : @"TLS_RSA_PSK_WITH_AES_128_GCM_SHA256"       ,
	@(0x00AD) : @"TLS_RSA_PSK_WITH_AES_256_GCM_SHA384"       ,
	
	@(0x00AE) : @"TLS_PSK_WITH_AES_128_CBC_SHA256"           ,
	@(0x00AF) : @"TLS_PSK_WITH_AES_256_CBC_SHA384"           ,
	@(0x00B0) : @"TLS_PSK_WITH_NULL_SHA256"                  ,
	@(0x00B1) : @"TLS_PSK_WITH_NULL_SHA384"                  ,
	
	@(0x00B2) : @"TLS_DHE_PSK_WITH_AES_128_CBC_SHA256"       ,
	@(0x00B3) : @"TLS_DHE_PSK_WITH_AES_256_CBC_SHA384"       ,
	@(0x00B4) : @"TLS_DHE_PSK_WITH_NULL_SHA256"              ,
	@(0x00B5) : @"TLS_DHE_PSK_WITH_NULL_SHA384"              ,
	
	@(0x00B6) : @"TLS_RSA_PSK_WITH_AES_128_CBC_SHA256"       ,
	@(0x00B7) : @"TLS_RSA_PSK_WITH_AES_256_CBC_SHA384"       ,
	@(0x00B8) : @"TLS_RSA_PSK_WITH_NULL_SHA256"              ,
	@(0x00B9) : @"TLS_RSA_PSK_WITH_NULL_SHA384"              ,
	
	
	/* Addenda from rfc 5289  Elliptic Curve Cipher Suites with
	 HMAC SHA-256/384. */
	@(0xC023) : @"TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256"   ,
	@(0xC024) : @"TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384"   ,
	@(0xC025) : @"TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256"    ,
	@(0xC026) : @"TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384"    ,
	@(0xC027) : @"TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256"     ,
	@(0xC028) : @"TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384"     ,
	@(0xC029) : @"TLS_ECDH_RSA_WITH_AES_128_CBC_SHA256"      ,
	@(0xC02A) : @"TLS_ECDH_RSA_WITH_AES_256_CBC_SHA384"      ,
	
	/* Addenda from rfc 5289  Elliptic Curve Cipher Suites with
	 SHA-256/384 and AES Galois Counter Mode (GCM) */
	@(0xC02B) : @"TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"   ,
	@(0xC02C) : @"TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"   ,
	@(0xC02D) : @"TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256"    ,
	@(0xC02E) : @"TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384"    ,
	@(0xC02F) : @"TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"     ,
	@(0xC030) : @"TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"     ,
	@(0xC031) : @"TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256"      ,
	@(0xC032) : @"TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384"      ,
	
	/* RFC 5746 - Secure Renegotiation */
	@(0x00FF) : @"TLS_EMPTY_RENEGOTIATION_INFO_SCSV"         ,
	/*
	 * Tags for SSL 2 cipher kinds which are not specified
	 * for SSL 3.
	 */
	@(0xFF80) : @"SSL_RSA_WITH_RC2_CBC_MD5",
	@(0xFF81) : @"SSL_RSA_WITH_IDEA_CBC_MD5",
	@(0xFF82) : @"SSL_RSA_WITH_DES_CBC_MD5",
	@(0xFF83) : @"SSL_RSA_WITH_3DES_EDE_CBC_MD5",
	@(0xFFFF) : @"SSL_NO_SUCH_CIPHERSUITE"
				
};


char *cipherNameForNumber(int cipherNumber)
{
	NSString *cipherName = [kCiphersStringDictionary objectForKey:@(cipherNumber)];
	if (cipherName) {
		const char *cipherName_c = [cipherName cStringUsingEncoding:NSASCIIStringEncoding];
		int length = strlen(cipherName_c);
		char *retString = (char *)malloc(length+1);
		if (retString) {
			strcpy(retString, cipherName_c);
			return retString;
		}
	}
	
	return NULL;
}


@interface FileManagerDelegateForMoving : NSObject <NSFileManagerDelegate>
@end
@implementation FileManagerDelegateForMoving
- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSError *)error movingItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath
{
	// File exists
	if (error.code == 516) { return YES;}
	return NO;
}
@end

bool moveFile(const char *src, const char *dst)
{
	bool answer = false;
	
	if (src && dst) {
		@autoreleasepool {
			
		
			NSString *source = NSStr(src);
			NSString *destination = NSStr(dst);
			
			NSError *error = nil;
			FileManagerDelegateForMoving *delegateForOverwriting = [[FileManagerDelegateForMoving alloc] init];
			NSFileManager *fileManager = [[NSFileManager alloc] init];
			fileManager.delegate = delegateForOverwriting;
			answer = [fileManager moveItemAtPath:source toPath:destination error:&error]; // this is synchronous so next hack should work
			if (!answer) {
				spreed_me_log("Error moving file %s", [error cDescription]);
			}
			[delegateForOverwriting fileManager:nil shouldProceedAfterError:nil movingItemAtPath:nil toPath:nil]; // hack to prolong life of delegateForOverwriting
		}
	}
	
	return answer;
}


bool checkIfFileExists(const char *fileLocation)
{
	NSFileManager *fileManager = [[NSFileManager alloc] init];
	BOOL isDirectory = NO;
	NSString *fileLocation_objc = NSStr(fileLocation);
	BOOL fileExists = [fileManager fileExistsAtPath:fileLocation_objc isDirectory:&isDirectory];
	return fileExists;
}


void makeFileNameSuggestion(const char *srcFileLocation, char **suggestedFileNameLocation)
{
	*suggestedFileNameLocation = NULL;
	if (srcFileLocation) {
		NSString *srcFileLocation_objc = NSStr(srcFileLocation);
		NSString *srcFileFolder = [srcFileLocation_objc stringByDeletingLastPathComponent];
		
		NSString *fname = [srcFileLocation_objc lastPathComponent];
		NSString *fnameNoExt = [fname stringByDeletingPathExtension];
		NSString *extension = [fname pathExtension];
		
		int fileIndex = 1; // we don't expect more than lets say 10000 files with the same name
		while ([[NSFileManager defaultManager] fileExistsAtPath:[srcFileFolder stringByAppendingPathComponent:fname]])
		{
//			NSLog(@"FNAME : %@",fname);
			fname = [NSString stringWithFormat:@"%@_(%d).%@", fnameNoExt, fileIndex, extension];
//			NSLog(@"Setting filename to :: %@",fname);
			fileIndex++;
		}
		NSString *suggestedFileLocation_objc = [srcFileFolder stringByAppendingPathComponent:fname];
		NSUInteger length = [suggestedFileLocation_objc lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
		if (length) {
			*suggestedFileNameLocation = (char *)malloc(length + 1); // +1 stays for null terminator
			if (suggestedFileNameLocation) {
				BOOL success = [suggestedFileLocation_objc getCString:*suggestedFileNameLocation maxLength:length + 1 encoding:NSUTF8StringEncoding];
				if (!success) {
					spreed_me_log("Couldn't get cString for suggestedFileLocation_objc %s", [suggestedFileLocation_objc cDescription]);
				}
			}
		}
	}
}


NSError *convertErrorToNSError(const spreedme::Error &error)
{
	NSString *domain = NSStr(error.domain.c_str());
	NSString *description = NSStr(error.description.c_str());
	
	NSError *underlyingError = nil;
	
	if (error.underlyingError) {
		underlyingError = convertErrorToNSError(*error.underlyingError);
	}
	
	NSMutableDictionary *tempUserInfo = [NSMutableDictionary dictionary];
	
	if ([description length] > 0) {
		[tempUserInfo setObject:description forKey:NSLocalizedDescriptionKey];
	}
	if (underlyingError) {
		[tempUserInfo setObject:underlyingError forKey:NSUnderlyingErrorKey];
	}
	
	NSDictionary *userInfo = [tempUserInfo count] > 0 ? [NSDictionary dictionaryWithDictionary:tempUserInfo] : nil;
	
	NSError *nsError = [NSError errorWithDomain:domain code:error.code userInfo:userInfo];
	
	return nsError;
}
