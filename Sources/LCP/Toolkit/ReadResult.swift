//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension ReadResult<Data> {
    /// Decodes the data as a LCP License Document.
    func asLCPL() -> ReadResult<LicenseDocument> {
        flatMap { data in
            do {
                return try .success(LicenseDocument(data: data))
            } catch {
                return .failure(.decoding("Not a valid LCP License Document", cause: error))
            }
        }
    }
}
