//
//  LibraryError.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 12.06.19.
//
//  Copyright 2019 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
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
        case .importFailed(let error):
            return String(format: NSLocalizedString("library_error_importFailed", comment: "Error message used when a low-level error occured while importing a publication"), error.localizedDescription)
        case .openFailed(let error):
            return String(format: NSLocalizedString("library_error_openFailed", comment: "Error message used when a low-level error occured while opening a publication"), error.localizedDescription)
        case .downloadFailed(let error):
            return String(format: NSLocalizedString("library_error_downloadFailed", comment: "Error message when the download of a publication failed"), error.localizedDescription)
        default:
            return nil
        }
    }

}
