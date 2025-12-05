//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Default implementation of ``ArchiveOpener`` supporting ZIP archives.
public class DefaultArchiveOpener: CompositeArchiveOpener {
    /// - Parameter additionalArchiveOpeners: Additional archive openers to use.
    public init(additionalArchiveOpeners: [any ArchiveOpener] = []) {
        super.init(additionalArchiveOpeners + [ZIPArchiveOpener()])
    }
}
