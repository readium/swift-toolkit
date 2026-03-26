//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// OPDS Link Properties Extension
/// https://drafts.opds.io/schema/properties.schema.json
public extension Properties {
    /// Provides a hint about the expected number of items returned.
    var numberOfItems: Int? {
        otherProperties["numberOfItems"]?.nonNegative()
    }

    /// The price of a publication is tied to its acquisition link.
    var price: OPDSPrice? {
        try? otherProperties["price"]?.decode(warnings: self)
    }

    /// Indirect acquisition provides a hint for the expected media type that will be acquired after
    /// additional steps.
    var indirectAcquisitions: [OPDSAcquisition] {
        otherProperties["indirectAcquisition"]?.decode(warnings: self) ?? []
    }

    /// Library-specific features when a specific book is unavailable but provides a hold list.
    var holds: OPDSHolds? {
        try? otherProperties["holds"]?.decode(warnings: self)
    }

    /// Library-specific feature that contains information about the copies that a library has
    /// acquired.
    var copies: OPDSCopies? {
        try? otherProperties["copies"]?.decode(warnings: self)
    }

    /// Indicated the availability of a given resource.
    var availability: OPDSAvailability? {
        try? otherProperties["availability"]?.decode(warnings: self)
    }

    /// Indicates that the linked resource supports authentication with the associated Authentication Document.
    /// See https://drafts.opds.io/authentication-for-opds-1.0.html
    var authenticate: Link? {
        try? otherProperties["authenticate"]?.decode(warnings: self)
    }
}
