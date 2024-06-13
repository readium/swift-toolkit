//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public extension Locator {
    init(href: String, type: MediaType) {
        self.init(href: AnyURL(string: href)!, type: type)
    }
}
