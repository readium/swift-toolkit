//
//  WPRendition.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Suggested orientation for the device when displaying the linked resource.
public enum WPOrientation: String {
    case auto
    case landscape
    case portrait
}

/// Indicates how the linked resource should be displayed in a reading environment that displays synthetic spreads.
public enum WPPage: String {
    case left
    case right
    case center
}

public enum WPReadingProgression: String {
    case rtl
    case ltr
    case auto
}


// MARK: - EPUB Extension

/// Hints how the layout of the resource should be presented.
public enum WPLayout: String {
    case fixed
    case reflowable
}

/// Suggested method for handling overflow while displaying the linked resource.
public enum WPOverflow: String {
    case auto
    case paginated
    case scrolled
    case scrolledContinuous = "scrolled-continuous"
}

/// Indicates the condition to be met for the linked resource to be rendered within a synthetic spread.
public enum WPSpread: String {
    case auto
    case both
    case none
    case landscape
}


/// https://readium.org/webpub-manifest/schema/extensions/epub/metadata.schema.json
public struct WPRendition: Equatable {
    
    /// Hints how the layout of the resource should be presented.
    public var layout: WPLayout?
    
    /// Suggested orientation for the device when displaying the linked resource.
    public var orientation: WPOrientation?
    
    /// Suggested method for handling overflow while displaying the linked resource.
    public var overflow: WPOverflow?
    
    /// Indicates the condition to be met for the linked resource to be rendered within a synthetic spread.
    public var spread: WPSpread?
    
    public init(layout: WPLayout? = nil, orientation: WPOrientation? = nil, overflow: WPOverflow? = nil, spread: WPSpread? = nil) {
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
            throw WPParsingError.rendition
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
