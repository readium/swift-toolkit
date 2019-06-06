//
//  EPUBRendition.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 12.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// https://readium.org/webpub-manifest/schema/extensions/epub/metadata.schema.json
public struct EPUBRendition: Equatable {

    /// Hints how the layout of the resource should be presented.
    public enum Layout: String {
        // Fixed layout.
        case fixed
        // Apply dynamic pagination when rendering.
        case reflowable
        
        /// Creates from an EPUB rendition:layout property.
        public init(epub: String, fallback: Layout? = nil) {
            switch epub {
            case "reflowable":
                self = .reflowable
            case "pre-paginated":
                self = .fixed
            default:
                self = fallback ?? .reflowable
            }
        }
    }
    
    /// Suggested orientation for the device when displaying the linked resource.
    public enum Orientation: String {
        // Specifies that the Reading System can determine the orientation to rendered the spine item in.
        case auto
        // Specifies that the given spine item is to be rendered in landscape orientation.
        case landscape
        // Specifies that the given spine item is to be rendered in portrait orientation.
        case portrait
        
        /// Creates from an EPUB rendition:orientation property.
        public init(epub: String, fallback: Orientation? = nil) {
            switch epub {
            case "landscape":
                self = .landscape
            case "portrait":
                self = .portrait
            case "auto":
                self = .auto
            default:
                self = fallback ?? .auto
            }
        }
    }
    
    /// Suggested method for handling overflow while displaying the linked resource.
    public enum Overflow: String {
        // Indicates no preference for overflow content handling by the Author.
        case auto
        // Indicates the Author preference is to dynamically paginate content overflow.
        case paginated
        // Indicates the Author preference is to provide a scrolled view for overflow content, and each spine item with this property is to be rendered as separate scrollable document.
        case scrolled
        // Indicates the Author preference is to provide a scrolled view for overflow content, and that consecutive spine items with this property are to be rendered as a continuous scroll.
        case scrolledContinuous = "scrolled-continuous"
        
        /// Creates from an EPUB rendition:flow property.
        public init(epub: String, fallback: Overflow? = nil) {
            switch epub {
            case "auto":
                self = .auto
            case "paginated":
                self = .paginated
            case "scrolled-doc":
                self = .scrolled
            case "scrolled-continuous":
                self = .scrolledContinuous
            default:
                self = fallback ?? .auto
            }
        }
    }
    
    /// Indicates the condition to be met for the linked resource to be rendered within a synthetic spread.
    public enum Spread: String {
        // Specifies the Reading System can determine when to render a synthetic spread for the readingOrder item.
        case auto
        // Specifies the Reading System should render a synthetic spread for the readingOrder item in both portrait and landscape orientations.
        case both
        // Specifies the Reading System should not render a synthetic spread for the readingOrder item.
        case none
        // Specifies the Reading System should render a synthetic spread for the readingOrder item only when in landscape orientation.
        case landscape
        
        /// Creates from an EPUB rendition:spread property.
        public init(epub: String, fallback: Spread? = nil) {
            switch epub {
            case "none":
                self = .none
            case "auto":
                self = .auto
            case "landscape":
                self = .landscape
            // `portrait` is deprecated and should fallback to `both`.
            // See. https://readium.org/architecture/streamer/parser/metadata#epub-3x-11
            case "both", "portrait":
                self = .both
            default:
                self = fallback ?? .auto
            }
        }
    }
    
    /// Hints how the layout of the resource should be presented.
    public var layout: Layout?
    
    /// Suggested orientation for the device when displaying the linked resource.
    public var orientation: Orientation?
    
    /// Suggested method for handling overflow while displaying the linked resource.
    public var overflow: Overflow?
    
    /// Indicates the condition to be met for the linked resource to be rendered within a synthetic spread.
    public var spread: Spread?
    
    public init(layout: Layout? = nil, orientation: Orientation? = nil, overflow: Overflow? = nil, spread: Spread? = nil) {
        self.layout = layout
        self.orientation = orientation
        self.overflow = overflow
        self.spread = spread
    }
    
    public init?(json: Any?) throws {
        if json == nil {
            return nil
        }
        guard let json = json as? [String: Any] else {
            throw JSONError.parsing(EPUBRendition.self)
        }
        
        self.layout = parseRaw(json["layout"])
        self.orientation = parseRaw(json["orientation"])
        self.overflow = parseRaw(json["overflow"])
        self.spread = parseRaw(json["spread"])
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "layout": encodeRawIfNotNil(layout),
            "orientation": encodeRawIfNotNil(orientation),
            "overflow": encodeRawIfNotNil(overflow),
            "spread": encodeRawIfNotNil(spread)
        ])
    }
    
}
