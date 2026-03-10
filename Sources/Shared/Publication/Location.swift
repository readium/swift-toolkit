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
}

/// A location within a publication with an explicit ``reference`` to a
/// resource.
public protocol ReferenceLocation<Ref>: Location {
    associatedtype Ref: Reference

    var reference: Ref? { get }
}

public struct AudioLocation: ReferenceLocation {
    public var progression: Double

    /// Temporal selector in the scope of the whole publication.
    public var temporal: TemporalSelector?

    public var reference: AudioReference?

    public init(
        progression: Double,
        temporal: TemporalSelector? = nil,
        reference: AudioReference? = nil
    ) {
        self.progression = progression
        self.temporal = temporal
        self.reference = reference
    }
}

public struct WebLocation: ReferenceLocation {
    public var progression: Double
    public var position: Int?
    public var reference: WebReference?

    init(
        progression: Double,
        position: Int? = nil,
        reference: WebReference
    ) {
        self.progression = progression
        self.position = position
        self.reference = reference
    }
}
