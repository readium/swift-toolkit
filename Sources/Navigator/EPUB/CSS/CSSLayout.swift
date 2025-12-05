//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Readium CSS layout variant to use.
///
/// See https://github.com/readium/readium-css/tree/master/css/dist
struct CSSLayout: Hashable {
    let language: Language?
    let stylesheets: Stylesheets
    let readingProgression: ReadingProgression

    /// Readium CSS stylesheet variants.
    enum Stylesheets: Hashable {
        /// Left to right
        case `default`
        /// Right to left
        case rtl
        /// Asian language, laid out horizontally
        case cjkHorizontal
        /// Asian language, laid out vertically.
        ///
        /// The HTML `dir` attribute must not be modified with vertical CJK:
        /// https://github.com/readium/readium-css/tree/master/css/dist#vertical
        case cjkVertical

        var folder: String? {
            switch self {
            case .default: return nil
            case .rtl: return "rtl"
            case .cjkHorizontal: return "cjk-horizontal"
            case .cjkVertical: return "cjk-vertical"
            }
        }

        var htmlDir: HTMLDir {
            switch self {
            case .default: return .ltr
            case .rtl: return .rtl
            case .cjkHorizontal: return .ltr
            case .cjkVertical: return .unspecified
            }
        }
    }

    enum HTMLDir: String {
        case unspecified = ""
        case ltr
        case rtl

        var isRTL: Bool? {
            switch self {
            case .unspecified:
                return nil
            case .ltr:
                return false
            case .rtl:
                return true
            }
        }
    }

    init(
        language: Language? = nil,
        stylesheets: Stylesheets = .default,
        readingProgression: ReadingProgression = .ltr
    ) {
        self.language = language
        self.stylesheets = stylesheets
        self.readingProgression = readingProgression
    }

    init(
        verticalText: Bool,
        language: Language?,
        readingProgression: ReadingProgression
    ) {
        self.init(
            language: language,
            stylesheets: {
                if verticalText {
                    return .cjkVertical
                } else if language?.isCJK == true {
                    return .cjkHorizontal
                } else if readingProgression == .rtl {
                    return .rtl
                } else {
                    return .default
                }
            }(),
            readingProgression: readingProgression
        )
    }
}
