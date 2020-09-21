//
//  DOMRange.swift
//  r2-shared-swift
//
//  Created by Mickaël on 25/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// This construct enables a serializable representation of a DOM Range.
///
/// In a DOM Range object, the startContainer + startOffset tuple represents the `start` boundary
/// point. Similarly, the the endContainer + endOffset tuple represents the `end` boundary point.
/// In both cases, the start/endContainer property is a pointer to either a DOM text node, or a DOM
/// element (this typically depends on the mechanism from which the DOM Range instance originates,
/// for example when obtaining the currently-selected document fragment using the `window.selection`
/// API). In the case of a DOM text node, the start/endOffset corresponds to a position within the
/// character data. In the case of a DOM element node, the start/endOffset corresponds to a position
/// that designates a child text node.
///
/// Note that `end` field is optional. When only the start field is specified, the domRange object
/// represents a "collapsed" range that has identical `start` and `end` boundary points.
///
/// https://github.com/readium/architecture/blob/master/models/locators/extensions/html.md#the-domrange-object
public struct DOMRange: JSONEquatable {
    
    /// A serializable representation of the "start" boundary point of the DOM Range.
    let start: Point
    
    /// A serializable representation of the "end" boundary point of the DOM Range.
    let end: Point?
    
    public init(start: Point, end: Point? = nil) {
        self.start = start
        self.end = end
    }
    
    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        // Convenience when parsing parent structures.
        if json == nil {
            return nil
        }
        guard let jsonObject = json as? [String: Any],
            let start = try? Point(json: jsonObject["start"], warnings: warnings) else
        {
            warnings?.log("`start` is required", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }
        self.init(start: start, end: try? Point(json: jsonObject["end"], warnings: warnings))
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "start": encodeIfNotEmpty(start.json),
            "end": encodeIfNotEmpty(end?.json)
        ])
    }
    
    /// A serializable representation of a boundary point in a DOM Range.
    ///
    /// The `cssSelector` field always references a DOM element. If the original DOM Range
    /// start/endContainer property references a DOM text node, the `textNodeIndex` field is used to
    /// complement the CSS Selector; thereby providing a pointer to a child DOM text node; and
    /// `charOffset` is used to tell a position within the character data of that DOM text node
    /// (just as the DOM Range start/endOffset does). If the original DOM Range start/endContainer
    /// property references a DOM Element, then the `textNodeIndex` field is used to designate the
    /// child Text node (just as the DOM Range start/endOffset does), and the optional `charOffset`
    /// field is not used (as there is no explicit position within the character data of the text
    /// node).
    ///
    /// https://github.com/readium/architecture/blob/master/models/locators/extensions/html.md#the-start-and-end-object
    public struct Point: JSONEquatable {
        let cssSelector: String
        let textNodeIndex: Int
        let charOffset: Int?
        
        public init(cssSelector: String, textNodeIndex: Int, charOffset: Int? = nil) {
            self.cssSelector = cssSelector
            self.textNodeIndex = textNodeIndex
            self.charOffset = charOffset
        }

        public init?(json: Any?, warnings: WarningLogger? = nil) throws {
            // Convenience when parsing parent structures.
            if json == nil {
                return nil
            }
            guard let jsonObject = json as? [String: Any],
                let cssSelector = jsonObject["cssSelector"] as? String,
                let textNodeIndex: Int = parsePositive(jsonObject["textNodeIndex"]) else
            {
                warnings?.log("`cssSelector` and `textNodeIndex` are required", model: Self.self, source: json, severity: .moderate)
                throw JSONError.parsing(Self.self)
            }
            self.init(
                cssSelector: cssSelector,
                textNodeIndex: textNodeIndex,
                charOffset: parsePositive(jsonObject["charOffset"])
            )
        }
        
        public var json: [String: Any] {
            return makeJSON([
                "cssSelector": cssSelector,
                "textNodeIndex": textNodeIndex,
                "charOffset": encodeIfNotNil(charOffset)
            ])
        }
    }
    
}
