//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public struct Content: Equatable {
    public let locator: Locator
    public let data: Data

    public var extras: [String: Any] {
        get { extrasJSON.json }
        set { extrasJSON = JSONDictionary(newValue) ?? JSONDictionary() }
    }
    // Trick to keep the struct equatable despite [String: Any]
    private var extrasJSON: JSONDictionary

    public init(locator: Locator, data: Data, extras: [String: Any] = [:]) {
        self.locator = locator
        self.data = data
        self.extrasJSON = JSONDictionary(extras) ?? JSONDictionary()
    }

    public enum Data: Equatable {
        case audio(target: Link)
        case image(target: Link, description: String?)
        case text(spans: [TextSpan], style: TextStyle)
    }

    public enum TextStyle: Equatable {
        case heading(level: Int)
        case body
        case callout
        case caption
        case footnote
        case quote
        case listItem
    }

    public struct TextSpan: Equatable {
        public let locator: Locator
        public let language: Language?
        public let text: String

        public init(locator: Locator, language: Language?, text: String) {
            self.locator = locator
            self.language = language
            self.text = text
        }
    }
}

public protocol ContentIterator: AnyObject {
    func close()
    func previous() throws -> Content?
    func next() throws -> Content?
}