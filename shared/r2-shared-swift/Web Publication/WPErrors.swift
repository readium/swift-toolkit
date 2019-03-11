//
//  WPErrors.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

enum WPParsingError: Error {
    case subcollection
    case publication
    case metadata
    case rendition
    case contributor
    case subject
    case link
    case properties
    case encrypted
    case localizedString
}
