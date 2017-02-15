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

#ifndef __SpreedME__Error__
#define __SpreedME__Error__

#include <iostream>

namespace spreedme {
	
	
extern const char kErrorDomainPeerConnectionWrapper[];
extern const char kErrorDomainCall[];

// PeerConnectionWrapper Domain errors
extern const int kUnknownErrorErrorCode;
extern const int kFailedToParseOfferErrorCode;
extern const int kFailedToParseAnswerErrorCode;
extern const int kFailedToCreateOfferErrorCode;
extern const int kFailedToCreateAnswerErrorCode;
extern const int kFailedToApplyConstraintsErrorCode;
extern const int kWrongStateOnSettingDescriptionErrorCode;
	
// Call Domain errors
extern const int kPeerConnectionFailedErrorCode;
	

struct Error {
	std::string domain;
	std::string description;
	int code;
	Error *underlyingError; // We assume that no more than ONE level of undelying error is present!
	
	
	Error() : domain(""), description(""), code(0), underlyingError(NULL) {};
	Error(const std::string &domain, const std::string &description, int code) : domain(domain), description(description), code(code), underlyingError(NULL) {};
	virtual ~Error() {if (underlyingError) {delete underlyingError;}};
	
	Error& operator=(const Error &other) {
		if (this != &other) {
			domain = other.domain;
			description = other.description;
			code = other.code;
			
			Error *localError = other.underlyingError ? new Error(*other.underlyingError) : NULL;
			if (underlyingError) { delete underlyingError; }
			underlyingError = localError;
		}
		return *this;
	};
	
	Error(const Error &other) {
		domain = other.domain;
		description = other.description;
		code = other.code;
		underlyingError = other.underlyingError ? new Error(*other.underlyingError) : NULL;
	}
	
	//TODO: Possibly add move constructor
};
	
} // namespace spreedme


#endif /* defined(__SpreedME__Error__) */
