//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumLCP

extension LCPError: UserErrorConvertible {
    func userError() -> UserError {
        UserError(cause: self) {
            switch self {
            case .missingPassphrase:
                return "lcp_error_missing_passphrase".localized
            case .notALicenseDocument, .licenseIntegrity, .licenseProfileNotSupported, .parsing:
                return "lcp_error_invalid_license".localized
            case .licenseIsBusy, .licenseInteractionNotAvailable:
                return "lcp_error_invalid_operation".localized
            case .licenseContainer:
                return "lcp_error_container".localized
            case .crlFetching, .runtime, .unknown:
                return "lcp_error_internal".localized
            case .network:
                return "lcp_error_network".localized
            case let .licenseStatus(error):
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium

                switch error {
                case let .cancelled(date):
                    return "lcp_error_status_cancelled".localized(dateFormatter.string(from: date))
                case let .returned(date):
                    return "lcp_error_status_returned".localized(dateFormatter.string(from: date))

                case let .expired(start: start, end: end):
                    if start > Date() {
                        return "lcp_error_status_expired_start".localized(dateFormatter.string(from: start))
                    } else {
                        return "lcp_error_status_expired_end".localized(dateFormatter.string(from: end))
                    }

                case let .revoked(date, devicesCount):
                    return "lcp_error_status_revoked".localized(dateFormatter.string(from: date), devicesCount)
                }
            case let .licenseRenew(error):
                switch error {
                case .renewFailed:
                    return "lcp_error_renew_failed".localized
                case .invalidRenewalPeriod:
                    return "lcp_error_invalid_renewal_period".localized
                case .unexpectedServerError:
                    return "lcp_error_network".localized
                }
            case let .licenseReturn(error):
                switch error {
                case .returnFailed:
                    return "lcp_error_return_failed".localized
                case .alreadyReturnedOrExpired:
                    return "lcp_error_already_returned_or_expired".localized
                case .unexpectedServerError:
                    return "lcp_error_network".localized
                }
            }
        }
    }
}
