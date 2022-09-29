//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Readium CSS layout variant to use.
///
/// See https://github.com/readium/readium-css/tree/master/css/dist
struct CSSLayout: Equatable {
    let language: Language?
    let stylesheets: Stylesheets
    let readingProgression: ReadingProgression

    /// Readium CSS stylesheet variants.
    enum Stylesheets {
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
        language: Language?,
        hasMultipleLanguages: Bool,
        readingProgression: ReadingProgression,
        verticalText: Bool?
    ) {
        // https://github.com/readium/readium-css/blob/master/docs/CSS16-internationalization.md#missing-page-progression-direction
        let rp: ReadingProgression = {
            if readingProgression == .ltr || readingProgression == .rtl {
                return readingProgression
            } else if !hasMultipleLanguages && language?.isRTL == true {
                return .rtl
            } else {
                return .ltr
            }
        }()

        let stylesheets: Stylesheets = {
            if verticalText == true {
                return .cjkVertical
            } else if language?.isCJK == true {
                if rp == .rtl && verticalText != false {
                    return .cjkVertical
                } else {
                    return .cjkHorizontal
                }
            } else if rp == .rtl {
                return .rtl
            } else {
                return .default
            }
        }()

        self.init(language: language, stylesheets: stylesheets, readingProgression: rp)
    }
}

private extension Language {

    var isRTL: Bool {
        let c = code.bcp47.lowercased()
        return c == "ar"
            || c == "fa"
            || c == "he"
            || c == "zh-hant"
            || c == "zh-tw"
    }

    var isCJK: Bool {
        let c = code.bcp47.lowercased()
        return c == "ja"
            || c == "ko"
            || removingRegion().code.bcp47.lowercased() == "zh"
    }
}
