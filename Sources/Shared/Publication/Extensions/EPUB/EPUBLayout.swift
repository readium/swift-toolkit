//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Hint about the nature of the layout for the linked resources.
public enum EPUBLayout: String, Sendable {
    case fixed, reflowable
}

package extension EPUBLayout {
    init(_ layout: Layout?) {
        self = (layout == .fixed) ? .fixed : .reflowable
    }
}

package extension Layout {
    init(_ layout: EPUBLayout) {
        switch layout {
        case .fixed:
            self = .fixed
        case .reflowable:
            self = .reflowable
        }
    }
}
