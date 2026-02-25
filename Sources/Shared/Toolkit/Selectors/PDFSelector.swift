//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// MARK: - PDF Selector

/// Identifies a page or an area in a page within a PDF document.
///
/// - https://www.rfc-editor.org/rfc/rfc8118
public struct PDFSelector: Hashable, Sendable {
    /// 1-based page number within the PDF resource.
    public var page: Int

    /// View rectangle in the page.
    public var rect: Rect?

    /// A rectangle within a PDF page.
    ///
    /// Coordinate values are expressed in the default user space coordinate
    /// system of the document: 1/72 of an inch measured down and to the right
    /// from the upper left corner of the (current) page ([ISOPDF2] 8.3.2.3
    /// "User Space").
    public struct Rect: Hashable, Sendable {
        public var left: Double
        public var top: Double
        public var width: Double
        public var height: Double

        public init(
            left: Double,
            top: Double,
            width: Double,
            height: Double
        ) {
            self.left = left
            self.top = top
            self.width = width
            self.height = height
        }
    }

    /// Returns `true` when this selector points to the first page in the PDF
    /// document.
    var isAtStart: Bool {
        page == 1 && rect == nil
    }

    public init(page: Int, rect: Rect? = nil) {
        self.page = page
        self.rect = rect
    }
}

// MARK: - Fragment

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

public extension URLFragment {
    /// Parses the fragment as a ``PDFSelector`` following RFC 8118.
    var pdfSelector: PDFSelector? {
        PDFSelector(fragment: self)
    }
}
