//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftUI

enum AccessibilityID: String {
    case open
    case close
    case allMemoryDeallocated
    case isNavigatorReady
}

extension View {
    func accessibilityIdentifier(_ id: AccessibilityID) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityIdentifier(id.rawValue)
    }
}
