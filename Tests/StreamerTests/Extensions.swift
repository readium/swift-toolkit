//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension ArchiveFetcher {
    convenience init(file: FileURL, password: String? = nil) throws {
        try self.init(archive: DefaultArchiveFactory().open(file: file, password: password).get())
    }
}
