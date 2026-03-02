//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A specific location within a publication.
public protocol Location: Hashable, Sendable {
    /// Total progression within the publication, expressed as a percentage
    /// between 0 and 1.
    var progression: Double { get }

    /// ``Locator`` representation for this location.
    var locator: Locator { get }
}

public struct AudioLocation: Location {
    public var progression: Double

    /// Temporal selector in the scope of the whole publication.
    public var temporal: TemporalSelector?

    public var reference: AudioReference

    private let mediaType: MediaType

    init(
        progression: Double,
        temporal: TemporalSelector? = nil,
        reference: AudioReference,
        mediaType: MediaType
    ) {
        self.progression = progression
        self.temporal = temporal
        self.reference = reference
        self.mediaType = mediaType
    }

    public var locator: Locator {
        Locator(
            href: reference.href,
            mediaType: mediaType,
            locations: .init(
                fragments: Array(ofNotNil: reference.temporal?.fragment.rawValue),
                progression: reference.progression,
                totalProgression: progression
            )
        )
    }
}

public struct WebLocation: Location {
    public var progression: Double
    public var position: Int?

    public var reference: WebReference

    private let mediaType: MediaType

    init(
        progression: Double,
        position: Int? = nil,
        reference: WebReference,
        mediaType: MediaType
    ) {
        self.progression = progression
        self.position = position
        self.reference = reference
        self.mediaType = mediaType
    }

    public var locator: Locator {
        var otherLocations: [String: String] = [:]
        if let cssSelector = reference.cssSelector {
            otherLocations["cssSelector"] = cssSelector.cssSelector
        }

        var text = Locator.Text()
        if let textSelector = reference.text {
            switch textSelector {
            case let .position(position):
                text.before = position.before
                text.after = position.before
            case let .quote(quote):
                text.before = quote.before
                text.highlight = quote.start
                text.after = quote.after
            }
        }

        return Locator(
            href: reference.href,
            mediaType: mediaType,
            locations: .init(
                fragments: Array(ofNotNil: reference.cssSelector?.htmlID),
                progression: reference.progression,
                totalProgression: progression,
                position: position,
                otherLocations: otherLocations
            ),
            text: text
        )
    }
}
