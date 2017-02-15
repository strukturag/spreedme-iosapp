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

#include "Error.h"

using namespace spreedme;

namespace spreedme {
	
const char kErrorDomainPeerConnectionWrapper[]			= "ErrorDomainPeerConnectionWrapper";
const char kErrorDomainCall[]							= "ErrorDomainCall";

const int kUnknownErrorErrorCode					= -3400;
const int kFailedToParseOfferErrorCode				= -3401;
const int kFailedToParseAnswerErrorCode				= -3402;
const int kFailedToCreateOfferErrorCode				= -3403;
const int kFailedToCreateAnswerErrorCode			= -3404;
const int kFailedToApplyConstraintsErrorCode		= -3405;
const int kWrongStateOnSettingDescriptionErrorCode  = -3406;

	
const int kPeerConnectionFailedErrorCode			= -3301;
}
