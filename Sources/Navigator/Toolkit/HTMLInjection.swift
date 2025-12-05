//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared

/// An object that can be injected into an HTML document.
protocol HTMLInjectable {
    /// Extension point to do treatment on the HTML document before injection.
    func willInject(in html: String) -> String

    func injections(for html: String) throws -> [HTMLInjection]
}

extension HTMLInjectable {
    func willInject(in html: String) -> String { html }

    /// Injects the receiver in the given `html` document.
    func inject(in html: String) throws -> String {
        var result = willInject(in: html)
        for injection in try injections(for: html) {
            result = try injection.inject(in: result)
        }
        return result
    }
}

/// Represents a raw injection in an HTML document.
struct HTMLInjection: Hashable {
    /// Raw content to inject.
    let content: String

    /// Target HTML element where the content will be injected.
    let target: HTMLElement

    /// Location in the target element where the content will be injected.
    let location: HTMLElement.Location

    /// Injects the receiver in the given `html` document.
    func inject(in html: String) throws -> String {
        guard let index = target.locate(location, in: html) else {
            return html
        }
        var res = html
        res.insert(contentsOf: content, at: index)
        return res
    }
}

struct HTMLElement: Hashable {
    static let html = HTMLElement(tag: "html")
    static let head = HTMLElement(tag: "head")
    static let body = HTMLElement(tag: "body")

    let tag: String
    private let startRegex: NSRegularExpression
    private let endRegex: NSRegularExpression

    init(tag: String) {
        self.tag = tag
        startRegex = NSRegularExpression("<\(tag)[^>]*>", options: [.caseInsensitive, .dotMatchesLineSeparators])
        endRegex = NSRegularExpression("</\(tag)\\s*>", options: [.caseInsensitive, .dotMatchesLineSeparators])
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
                .map { html.index($0.lowerBound, offsetBy: tag.count + 1) }
        }
    }

    /// Injection location in an HTML element.
    enum Location: String, Hashable {
        /// Injects at the beginning of the element's content.
        case start
        /// Injects at the end of the element's content.
        case end
        /// Injects an attribute of the element.
        case attributes
    }
}

extension HTMLElement: CustomStringConvertible {
    var description: String {
        "<\(tag)>"
    }
}

extension HTMLElement.Location: CustomStringConvertible {
    var description: String {
        rawValue
    }
}

extension HTMLInjection {
    /// Injects an HTML attribute with the given `name` on the element `target`.
    static func attribute(_ name: String, on target: HTMLElement, value: String) -> HTMLInjection {
        HTMLInjection(
            content: " \(name)=\"\(escapeAttribute(value))\"",
            target: target,
            location: .attributes
        )
    }

    static func dirAttribute(on target: HTMLElement, rtl: Bool) -> HTMLInjection {
        .attribute("dir", on: target, value: rtl ? "rtl" : "ltr")
    }

    static func langAttribute(on target: HTMLElement, language: Language) -> HTMLInjection {
        .attribute("xml:lang", on: target, value: language.code.bcp47)
    }

    static func styleAttribute(on target: HTMLElement, css: String) -> HTMLInjection {
        .attribute("style", on: target, value: css)
    }

    /// Injects a `link` tag in the `head` element.
    static func link(href: String, rel: String, type: MediaType? = nil, as asValue: String? = nil, crossOrigin: String? = nil, prepend: Bool = false) -> HTMLInjection {
        var content = "<link rel=\"\(rel)\" href=\"\(escapeAttribute(href))\""
        if let type = type {
            content += " type=\"\(type.string)\""
        }
        if let asValue = asValue {
            content += " as=\"\(asValue)\""
        }
        if let crossOrigin = crossOrigin {
            content += " crossorigin=\"\(crossOrigin)\""
        }
        content += "/>"

        return HTMLInjection(
            content: content,
            target: .head,
            location: prepend ? .start : .end
        )
    }

    static func stylesheetLink(href: String, prepend: Bool = false) -> HTMLInjection {
        .link(href: href, rel: "stylesheet", type: .css, prepend: prepend)
    }

    /// Injects a `meta` tag in the `head` element.
    static func meta(name: String, content: String) -> HTMLInjection {
        HTMLInjection(
            content: "<meta name=\"\(escapeAttribute(name))\" content=\"\(escapeAttribute(content))\"/>",
            target: .head,
            location: .end
        )
    }

    /// Injects a `style` tag in the `head` element.
    static func style(_ css: String, prepend: Bool = false) -> HTMLInjection {
        HTMLInjection(
            content: "<style type=\"text/css\">\(css)</style>",
            target: .head,
            location: prepend ? .start : .end
        )
    }
}

private func escapeAttribute(_ value: String) -> String {
    value.replacingOccurrences(of: "\"", with: "&quot;")
}
