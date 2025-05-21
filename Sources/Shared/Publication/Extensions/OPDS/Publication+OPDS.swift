//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// OPDS Web Publication Extension
public extension Publication {
    var images: [Link] {
        subcollections["images"]?.flatMap(\.links) ?? []
    }
}
