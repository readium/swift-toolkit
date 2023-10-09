//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Presentation extensions for `Metadata`.
public extension Metadata {
    var presentation: Presentation {
        (try? Presentation(json: otherMetadata["presentation"], warnings: self)) ?? Presentation()
    }
}
