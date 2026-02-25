//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// MARK: - TextSelector

public extension TextSelector {
    /// Creates a ``TextSelector`` from a URL fragment following the WICG
    /// Scroll-to-Text Fragment specification.
    ///
    /// Fragment format: `:~:text=[prefix-,]textStart[,textEnd][,-suffix]`
    ///
    /// - https://wicg.github.io/scroll-to-text-fragment/
    init?(fragment: URLFragment) {
        let raw = fragment.rawValue
        let prefix = ":~:text="
        guard raw.hasPrefix(prefix) else { return nil }
        let directive = String(raw.dropFirst(prefix.count))
        guard !directive.isEmpty else { return nil }

        var parts = directive.components(separatedBy: ",")

        var before = ""
        var after = ""

        // Check for context prefix (ends with `-`)
        if parts[0].hasSuffix("-") {
            let encoded = String(parts[0].dropLast())
            before = encoded.removingPercentEncoding ?? encoded
            parts.removeFirst()
        }

        // Check for context suffix (starts with `-`)
        if let last = parts.last, last.hasPrefix("-") {
            let encoded = String(last.dropFirst())
            after = encoded.removingPercentEncoding ?? encoded
            parts.removeLast()
        }

        guard !parts.isEmpty, !parts[0].isEmpty else { return nil }

        let startEncoded = parts[0]
        let start = startEncoded.removingPercentEncoding ?? startEncoded

        var end = ""
        if parts.count >= 2 {
            let endEncoded = parts[1]
            end = endEncoded.removingPercentEncoding ?? endEncoded
        }

        self = .quote(TextQuote(before: before, start: start, end: end, after: after))
    }

    /// Returns a URL fragment representation of this selector following the
    /// WICG Scroll-to-Text Fragment specification.
    ///
    /// - https://wicg.github.io/scroll-to-text-fragment/
    var fragment: URLFragment {
        switch self {
        case let .quote(q):
            var parts: [String] = []
            let allowed = CharacterSet.urlQueryAllowed
            if !q.before.isEmpty {
                parts.append((q.before.addingPercentEncoding(withAllowedCharacters: allowed) ?? q.before) + "-")
            }
            parts.append(q.start.addingPercentEncoding(withAllowedCharacters: allowed) ?? q.start)
            if !q.end.isEmpty {
                parts.append(q.end.addingPercentEncoding(withAllowedCharacters: allowed) ?? q.end)
            }
            if !q.after.isEmpty {
                parts.append("-" + (q.after.addingPercentEncoding(withAllowedCharacters: allowed) ?? q.after))
            }
            return URLFragment(rawValue: ":~:text=" + parts.joined(separator: ","))!

        case let .position(p):
            var parts: [String] = []
            let allowed = CharacterSet.urlQueryAllowed
            if !p.before.isEmpty {
                parts.append((p.before.addingPercentEncoding(withAllowedCharacters: allowed) ?? p.before) + "-")
            }
            // No start text for a pure position — emit an empty start segment
            parts.append("")
            if !p.after.isEmpty {
                parts.append("-" + (p.after.addingPercentEncoding(withAllowedCharacters: allowed) ?? p.after))
            }
            return URLFragment(rawValue: ":~:text=" + parts.joined(separator: ","))!
        }
    }
}

// MARK: - TemporalSelector

public extension TemporalSelector {
    /// Creates a ``TemporalSelector`` from a URL fragment following the W3C
    /// Media Fragments URI specification (temporal dimension).
    ///
    /// Fragment format: `t=[npt:]start[,end]`
    ///
    /// - https://www.w3.org/TR/media-frags/#naming-time
    init?(fragment: URLFragment) {
        let raw = fragment.rawValue
        guard raw.hasPrefix("t=") else { return nil }
        var value = String(raw.dropFirst(2))

        // Strip optional `npt:` prefix
        if value.hasPrefix("npt:") {
            value = String(value.dropFirst(4))
        }

        let parts = value.components(separatedBy: ",")

        switch parts.count {
        case 1:
            guard !parts[0].isEmpty, let t = TimeInterval(parts[0]) else { return nil }
            self = .position(TemporalPosition(time: t))

        case 2:
            let startStr = parts[0]
            let endStr = parts[1]

            let start: TimeInterval? = startStr.isEmpty ? nil : TimeInterval(startStr)
            let end: TimeInterval? = endStr.isEmpty ? nil : TimeInterval(endStr)

            if start == nil, end == nil { return nil }

            if !startStr.isEmpty, endStr.isEmpty {
                // `t=10,` — open-ended clip, not a point
                guard let t = start else { return nil }
                self = .clip(TemporalClip(start: t, end: nil))
            } else {
                self = .clip(TemporalClip(start: start, end: end))
            }

        default:
            return nil
        }
    }

    /// Returns a URL fragment representation of this selector following the
    /// W3C Media Fragments URI specification (temporal dimension).
    ///
    /// - https://www.w3.org/TR/media-frags/#naming-time
    var fragment: URLFragment {
        switch self {
        case let .position(p):
            return URLFragment(rawValue: "t=\(p.time)")!
        case let .clip(c):
            let start = c.start.map { "\($0)" } ?? ""
            let end = c.end.map { "\($0)" } ?? ""
            return URLFragment(rawValue: "t=\(start),\(end)")!
        }
    }
}

// MARK: - SpatialSelector

public extension SpatialSelector {
    /// Creates a ``SpatialSelector`` from a URL fragment following the W3C
    /// Media Fragments URI specification (spatial dimension).
    ///
    /// Fragment format: `xywh=[unit:]x,y,w,h`
    ///
    /// - https://www.w3.org/TR/media-frags/#naming-space
    init?(fragment: URLFragment) {
        let raw = fragment.rawValue
        guard raw.hasPrefix("xywh=") else { return nil }
        var value = String(raw.dropFirst(5))

        let unit: Unit
        if value.hasPrefix("percent:") {
            unit = .percent
            value = String(value.dropFirst(8))
        } else if value.hasPrefix("pixel:") {
            unit = .pixel
            value = String(value.dropFirst(6))
        } else {
            unit = .pixel
        }

        let parts = value.components(separatedBy: ",")
        guard parts.count == 4,
              let x = Double(parts[0]),
              let y = Double(parts[1]),
              let w = Double(parts[2]),
              let h = Double(parts[3])
        else { return nil }

        self.init(x: x, y: y, width: w, height: h, unit: unit)
    }

    /// Returns a URL fragment representation of this selector following the
    /// W3C Media Fragments URI specification (spatial dimension).
    ///
    /// - https://www.w3.org/TR/media-frags/#naming-space
    var fragment: URLFragment {
        let unitPrefix: String
        switch unit {
        case .percent: unitPrefix = "percent:"
        case .pixel: unitPrefix = ""
        }
        return URLFragment(rawValue: "xywh=\(unitPrefix)\(x),\(y),\(width),\(height)")!
    }
}

// MARK: - CSSSelector

public extension CSSSelector {
    /// Creates a ``CSSSelector`` from a URL fragment by treating it as an HTML
    /// element ID.
    ///
    /// A plain fragment (e.g. `section1`) is converted to a CSS ID selector
    /// (e.g. `#section1`).
    ///
    /// - Important: This initializer accepts any non-empty fragment string,
    ///   including structured directives such as `:~:text=…` or `t=…`. Callers
    ///   are responsible for trying more specific ``TextSelector`` or
    ///   ``TemporalSelector`` initializers first.
    init(fragment: URLFragment) {
        self.init(cssSelector: "#\(fragment.rawValue)")
    }
}

// MARK: - PDFSelector

public extension PDFSelector {
    /// Creates a ``PDFSelector`` from a URL fragment following RFC 8118.
    ///
    /// Fragment format: `page=N[&viewrect=left,top,width,height]`
    ///
    /// - https://www.rfc-editor.org/rfc/rfc8118
    init?(fragment: URLFragment) {
        let pairs = fragment.rawValue.components(separatedBy: "&")
        var pageValue: Int?
        var rectValue: Rect?

        for pair in pairs {
            let kv = pair.components(separatedBy: "=")
            guard kv.count == 2 else { continue }
            let key = kv[0]
            let value = kv[1]

            switch key {
            case "page":
                guard let n = Int(value), n >= 1 else { return nil }
                pageValue = n

            case "viewrect":
                let coords = value.components(separatedBy: ",")
                guard coords.count == 4,
                      let left = Double(coords[0]),
                      let top = Double(coords[1]),
                      let width = Double(coords[2]),
                      let height = Double(coords[3])
                else { return nil }
                rectValue = Rect(left: left, top: top, width: width, height: height)

            default:
                break
            }
        }

        guard let page = pageValue else { return nil }
        self.init(page: page, rect: rectValue)
    }

    /// Returns a URL fragment representation of this selector following RFC
    /// 8118.
    ///
    /// - https://www.rfc-editor.org/rfc/rfc8118
    var fragment: URLFragment {
        var raw = "page=\(page)"
        if let r = rect {
            raw += "&viewrect=\(r.left),\(r.top),\(r.width),\(r.height)"
        }
        return URLFragment(rawValue: raw)!
    }
}

// MARK: - URLFragment Extensions

public extension URLFragment {
    /// Parses the fragment as a ``TextSelector`` following the WICG
    /// Scroll-to-Text Fragment specification.
    var textSelector: TextSelector? {
        TextSelector(fragment: self)
    }

    /// Parses the fragment as a ``TemporalSelector`` following the W3C Media
    /// Fragments URI specification.
    var temporalSelector: TemporalSelector? {
        TemporalSelector(fragment: self)
    }

    /// Parses the fragment as a ``SpatialSelector`` following the W3C Media
    /// Fragments URI specification.
    var spatialSelector: SpatialSelector? {
        SpatialSelector(fragment: self)
    }

    /// Interprets the fragment as an HTML element ID and returns a
    /// ``CSSSelector``.
    var cssSelector: CSSSelector {
        CSSSelector(fragment: self)
    }

    /// Parses the fragment as a ``PDFSelector`` following RFC 8118.
    var pdfSelector: PDFSelector? {
        PDFSelector(fragment: self)
    }
}
