//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension Data {
    /// Decodes the data as a LCP License Document.
    func asLCPL() throws(ReadError) -> LicenseDocument {
        do {
            return try LicenseDocument(data: self)
        } catch {
            throw .decoding("Not a valid LCP License Document", cause: error)
        }
    }
}
