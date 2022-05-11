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
    }

    public let code: Code

    public var locale: Locale { Locale(identifier: code.bcp47) }

    public var localizedName: String {
        Locale.current.localizedString(forIdentifier: code.bcp47)
            ?? code.bcp47
    }

    public init(code: Code) {
        self.code = code
    }

    public init(locale: Locale) {
        self.init(code: .bcp47(locale.identifier))
    }
}