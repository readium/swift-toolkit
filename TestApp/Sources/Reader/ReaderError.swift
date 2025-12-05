//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

enum ReaderError: Error {
    case formatNotSupported
    case epubNotValid
}

extension ReaderError: UserErrorConvertible {
    func userError() -> UserError {
        UserError(cause: self) {
            switch self {
            case .formatNotSupported:
                return "reader_error_formatNotSupported".localized
            case .epubNotValid:
                return "reader_error_epubNotValid".localized
            }
        }
    }
}
