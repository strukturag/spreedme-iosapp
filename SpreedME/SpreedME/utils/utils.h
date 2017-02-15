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

#ifndef SpreedME_utils_h
#define SpreedME_utils_h


#define SPREEDME_LOG_PRINT_TO_CONSOLE 1



#ifdef __cplusplus
extern "C"
{
#endif

const char *AudioFileName();

    
#ifdef SPREEDME_ALLOW_LOGGING    
    int init_spreed_me_log(); //This should be called once per app run from the main thread before any calls to spreed_me_log()
    int spreed_me_log(const char *fmt, ...);
#else
#   define init_spreed_me_log()
#   define spreed_me_log(...)
#endif
    


char *cipherNameForNumber(int cipherNumber); // You need to free received string
	
bool moveFile(const char *src, const char *dst);
bool checkIfFileExists(const char *fileLocation);
void makeFileNameSuggestion(const char *srcFileLocation, char **suggestedFileNameLocation); // You are responsible for releasing suggestedFileNameLocation

#ifdef __cplusplus
}
#endif

	
#endif
