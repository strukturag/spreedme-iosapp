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

#ifndef __SpreedME__MediaConstraints__
#define __SpreedME__MediaConstraints__

#include <iostream>

#include <deque>
#include <map>

#include <talk/app/webrtc/mediaconstraintsinterface.h>
#include <talk/app/webrtc/mediastreaminterface.h>
#include <webrtc/base/stringencode.h>

namespace spreedme {


class MediaConstraints : public webrtc::MediaConstraintsInterface {
public:
	MediaConstraints() {};
	virtual ~MediaConstraints() {};
	
	virtual const Constraints& GetMandatory() const {
        return mandatory_;
    }
	
    virtual const Constraints& GetOptional() const {
        return optional_;
    }
	
	virtual Constraints* GetMandatoryRef() {
		return &mandatory_;
	}
	
	virtual Constraints* GetOptionalRef() {
		return &optional_;
	}
	
	template <class T>
    void AddMandatory(const std::string& key, const T& value) {
        mandatory_.push_back(Constraint(key, rtc::ToString<T>(value)));
    }
	
    template <class T>
    void AddOptional(const std::string& key, const T& value) {
        optional_.push_back(Constraint(key, rtc::ToString<T>(value)));
    }
	
	void PurgeAll() {
		optional_.clear();
		mandatory_.clear();
	}
	
	MediaConstraints *Copy() {
		MediaConstraints *copy = new MediaConstraints;
		for (Constraints::iterator it = mandatory_.begin(); it != mandatory_.end(); ++it) {
			copy->AddMandatory(it->key, it->value);
		}
		
		for (Constraints::iterator it = optional_.begin(); it != optional_.end(); ++it) {
			copy->AddOptional(it->key, it->value);
		}
		
		return copy;
	};
	
private:
    Constraints mandatory_;
    Constraints optional_;
};

} // namespace spreedme

#endif /* defined(__SpreedME__MediaConstraints__) */
