//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

enum LibraryError: Error {
    case publicationIsNotValid
    case bookNotFound
    case bookDeletionFailed(Error?)
    case importFailed(Error)
    case publicationIsRestricted(Error)
    case openFailed(Error)
    case downloadFailed(Error?)
}

extension LibraryError: UserErrorConvertible {
    func userError() -> UserError {
        UserError(cause: self) {
            switch self {
            case .publicationIsNotValid:
                return "library_error_publicationIsNotValid".localized
            case .bookNotFound:
                return "library_error_bookNotFound".localized
            case .importFailed:
                return "library_error_importFailed".localized
            case .openFailed:
                return "library_error_openFailed".localized
            case .downloadFailed:
                return "library_error_downloadFailed".localized
            case .bookDeletionFailed:
                return "library_error_bookDeletionFailed".localized
            case let .publicationIsRestricted(error):
                if let error = error as? UserErrorConvertible {
                    return error.userError().message
                } else {
                    return "library_error_publicationIsRestricted".localized
                }
            }
        }
    }
}
