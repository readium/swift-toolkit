//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

enum LibraryError: LocalizedError {
    case publicationIsNotValid
    case bookNotFound
    case bookDeletionFailed(Error?)
    case importFailed(Error)
    case openFailed(Error)
    case downloadFailed(Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .publicationIsNotValid:
            return NSLocalizedString("library_error_publicationIsNotValid", comment: "Error message used when trying to import a publication that is not valid")
        case .bookNotFound:
            return NSLocalizedString("library_error_bookNotFound", comment: "Error message used when trying to open a book whose file is not found")
        case let .importFailed(error):
            return String(format: NSLocalizedString("library_error_importFailed", comment: "Error message used when a low-level error occured while importing a publication"), error.localizedDescription)
        case let .openFailed(error):
            return String(format: NSLocalizedString("library_error_openFailed", comment: "Error message used when a low-level error occured while opening a publication"), error.localizedDescription)
        case let .downloadFailed(error):
            return String(format: NSLocalizedString("library_error_downloadFailed", comment: "Error message when the download of a publication failed"), error.localizedDescription)
        default:
            return nil
        }
    }
}
