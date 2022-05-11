//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public struct Language: Hashable {

    public static var current: Language {
        Language(locale: Locale.current)
    }

    public enum Code: Hashable {
        case bcp47(String)

        public var bcp47: String {
            switch self {
            case .bcp47(let code):
                return code
            }
        }

        public func removingRegion() -> Code {
            .bcp47(String(bcp47.prefix { $0 != "-" && $0 != "_" }))
        }
    }

    public let code: Code

    public var locale: Locale { Locale(identifier: code.bcp47) }

    public func localizedDescription(in locale: Locale = Locale.current) -> String {
        locale.localizedString(forIdentifier: code.bcp47)
            ?? code.bcp47
    }

    public func localizedLanguage(in targetLocale: Locale = Locale.current) -> String? {
        locale.languageCode.flatMap { targetLocale.localizedString(forLanguageCode: $0) }
    }

    public func localizedRegion(in targetLocale: Locale = Locale.current) -> String? {
        locale.regionCode.flatMap { targetLocale.localizedString(forRegionCode: $0) }
    }

    public init(code: Code) {
        self.code = code
    }

    public init(locale: Locale) {
        self.init(code: .bcp47(locale.identifier))
    }

    public func removingRegion() -> Language {
        Language(code: code.removingRegion())
    }
}

extension Language: CustomStringConvertible {
    public var description: String {
        code.bcp47
    }
}