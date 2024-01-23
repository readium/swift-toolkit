//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

@available(*, unavailable, message: "Use `publication.metadata.effectiveReadingProgression` instead")
public enum ContentLayout: String {
    case rtl
    case ltr
    case cjkVertical = "cjk-vertical"
    case cjkHorizontal = "cjk-horizontal"

    @available(*, unavailable, message: "Use `publication.metadata.effectiveReadingProgression` instead", renamed: "metadata.effectiveReadingProgression")
    public var readingProgression: ReadingProgression {
        switch self {
        case .rtl, .cjkVertical:
            return .rtl
        case .ltr, .cjkHorizontal:
            return .ltr
        }
    }
}
