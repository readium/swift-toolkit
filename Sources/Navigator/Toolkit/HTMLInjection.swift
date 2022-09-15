//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a raw injection in an HTML document.
struct HTMLInjection {
    /// Raw content to inject.
    let content: String

    /// Target HTML element where the content will be injected.
    let target: HTMLElement

    /// Location in the target element where the content will be injected.
    let location: HTMLElement.Location

    /// Injects the receiver in the given `html` document.
    func inject(in html: String) -> String {
        html
    }
}

class HTMLElement {
    static let head = HTMLElement(tag: "head")
    static let body = HTMLElement(tag: "body")

    let tag: String

    init(tag: String) {
        self.tag = tag
    }

    private lazy var startRegex =
        try! NSRegularExpression(pattern: "<\(tag).*?>", options: [/*.caseInsensitive, .dotMatchesLineSeparators*/])

    /// Locates the given `location` of this element in the given `html` document.
    func locate(_ location: Location, in html: String) -> String.Index? {
        switch location {
        case .start:
            let range = NSRange(text.startIndex..., in: text)
            startRegex.matches(in: html, options: <#T##MatchingOptions##Foundation.NSRegularExpression.MatchingOptions#>, range: <#T##NSRange##Foundation.NSRange#>)
            guard
                let range = html.range(of: startRegex, options: .regularExpression),
                !range.isEmpty
            else {
                return nil
            }
            return range.upperBound
        case .end:
            return nil
        case .attributes:
            return nil
        }
    }

    /// Injection location in an HTML element.
    enum Location {
        /// Injects at the beginning of the element's content.
        case start
        /// Injects at the end of the element's content.
        case end
        /// Injects an attribute of the element.
        case attributes
    }
}

/// An object that can be injected into an HTML document.
protocol HTMLInjectable {
    func injections() -> [HTMLInjection]
}

extension HTMLInjectable {

    /// Injects the receiver in the given `html` document.
    func inject(in html: String) -> String {
        var result = html
        for injection in injections() {
            result = injection.inject(in: result)
        }
        return result
    }
}