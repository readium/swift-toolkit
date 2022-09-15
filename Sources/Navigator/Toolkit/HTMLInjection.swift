//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared
import ReadiumInternal

/// Represents a raw injection in an HTML document.
struct HTMLInjection: Hashable {
    /// Raw content to inject.
    let content: String

    /// Target HTML element where the content will be injected.
    let target: HTMLElement

    /// Location in the target element where the content will be injected.
    let location: HTMLElement.Location

    /// Injects the receiver in the given `html` document.
    func inject(in html: String) -> String {
        guard let index = target.locate(location, in: html) else {
            return html
        }
        var res = html
        res.insert(contentsOf: content, at: index)
        return res
    }
}

struct HTMLElement: Hashable {
    static let head = HTMLElement(tag: "head")
    static let body = HTMLElement(tag: "body")

    let tag: String
    private let startRegex: NSRegularExpression
    private let endRegex: NSRegularExpression

    init(tag: String) {
        self.tag = tag
        self.startRegex = NSRegularExpression("<\(tag)[^>]*>", options: [.caseInsensitive, .dotMatchesLineSeparators])
        self.endRegex = NSRegularExpression("</\(tag)\\s*>", options: [.caseInsensitive, .dotMatchesLineSeparators])
    }


    /// Locates the `location` of this element in the given `html` document.
    func locate(_ location: Location, in html: String) -> String.Index? {
        switch location {
        case .start:
            return startRegex.matches(in: html).first?
                .range(in: html)?.upperBound
        case .end:
            return endRegex.matches(in: html).first?
                .range(in: html)?.lowerBound
        case .attributes:
            return startRegex.matches(in: html).first
                .flatMap { $0.range(in: html) }
                .map { html.index($0.upperBound, offsetBy: -1) }
        }
    }

    /// Injection location in an HTML element.
    enum Location: Hashable {
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

struct HTMLAttribute: HTMLInjectable {
    let target: HTMLElement
    let name: String
    let value: String

    func injections() -> [HTMLInjection] {
        [
            HTMLInjection(
                content: " \(name)=\"\(escapeAttribute(value))\"",
                target: target,
                location: .attributes
            )
        ]
    }

    static func dir(rtl: Bool, on target: HTMLElement) -> HTMLAttribute {
        HTMLAttribute(target: target, name: "dir", value: rtl ? "rtl" : "ltr")
    }

    static func lang(_ language: Language, on target: HTMLElement) -> HTMLAttribute {
        HTMLAttribute(target: target, name: "xml:lang", value: language.code.bcp47)
    }

    static func style(_ stylesheet: String, on target: HTMLElement) -> HTMLAttribute {
        HTMLAttribute(target: .body, name: "style", value: stylesheet)
    }
}

struct HTMLLinkTag: HTMLInjectable {
    let href: String
    let rel: String
    let type: MediaType
    let before: Bool

    init(href: String, rel: String, type: MediaType, before: Bool = false) {
        self.href = href
        self.rel = rel
        self.type = type
        self.before = before
    }

    func injections() -> [HTMLInjection] {
        [
            HTMLInjection(
                content: "<link rel=\"\(rel)\" type=\"\(type.string)\" href=\"\(escapeAttribute(href))\"/>",
                target: .head,
                location: before ? .start : .end
            )
        ]
    }

    static func stylesheet(href: String, before: Bool = false) -> HTMLLinkTag {
        HTMLLinkTag(href: href, rel: "stylesheet", type: .css, before: before)
    }
}

struct HTMLMetaTag: HTMLInjectable {
    let name: String
    let content: String

    func injections() -> [HTMLInjection] {
        [
            HTMLInjection(
                content: "<meta name=\"\(escapeAttribute(name))\" content=\"\(escapeAttribute(content))\"/>",
                target: .head,
                location: .end
            )
        ]
    }
}

struct HTMLStyleTag: HTMLInjectable {
    let stylesheet: String
    let before: Bool

    init(stylesheet: String, before: Bool = false) {
        self.stylesheet = stylesheet
        self.before = before
    }

    func injections() -> [HTMLInjection] {
        [
            HTMLInjection(
                content: "<style type=\"text/css\">\(stylesheet)</style>",
                target: .head,
                location: before ? .start : .end
            )
        ]
    }
}

private func escapeAttribute(_ value: String) -> String {
    value.replacingOccurrences(of: "\"", with: "&quot;")
}
