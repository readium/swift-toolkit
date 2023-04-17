//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

extension ArchiveFetcher {
    convenience init(url: URL, password: String? = nil) throws {
        try self.init(archive: DefaultArchiveFactory().open(url: url, password: password).get())
    }
}
