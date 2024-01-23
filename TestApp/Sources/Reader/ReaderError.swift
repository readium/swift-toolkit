//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

enum ReaderError: LocalizedError {
    case formatNotSupported
    case epubNotValid

    var errorDescription: String? {
        switch self {
        case .formatNotSupported:
            return NSLocalizedString("reader_error_formatNotSupported", comment: "Error message when trying to read a publication with a unsupported format")
        case .epubNotValid:
            return NSLocalizedString("reader_error_epubNotValid", comment: "Error message when trying to read an EPUB that is invalid")
        }
    }
}
