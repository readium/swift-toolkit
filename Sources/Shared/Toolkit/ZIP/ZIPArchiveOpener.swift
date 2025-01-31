//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An ``ArchiveOpener`` for ZIP resources.
public class ZIPArchiveOpener: CompositeArchiveOpener {
    public init() {
        super.init([
            MinizipArchiveOpener(),
            ZIPFoundationArchiveOpener(),
        ])
    }
}
