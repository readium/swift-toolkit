//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Publications can indicate whether they allow third parties to use their
/// content for text and data mining purposes using the [TDM Rep protocol](https://www.w3.org/community/tdmrep/),
/// as defined in a [W3C Community Group Report](https://www.w3.org/community/reports/tdmrep/CG-FINAL-tdmrep-20240510/).
///
/// https://github.com/readium/webpub-manifest/blob/master/schema/metadata.schema.json
public struct TDM: Hashable, Sendable {
    public struct Reservation: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: RawValue) {
            self.rawValue = rawValue
        }

        /// All TDM rights are reserved. If a TDM Policy is set, TDM Agents MAY
        /// use it to get information on how they can acquire from the
        /// rightsholder an authorization to mine the content.
        public static let all = Reservation(rawValue: "all")

        /// TDM rights are not reserved. TDM agents can mine the content for TDM
        /// purposes without having to contact the rightsholder.
        public static let none = Reservation(rawValue: "none")
    }

    public var reservation: Reservation

    /// URL pointing to a TDM Policy set be the rightsholder.
    public var policy: HTTPURL?

    public init(reservation: Reservation, policy: HTTPURL? = nil) {
        self.reservation = reservation
        self.policy = policy
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        guard
            let json = json as? [String: Any],
            let reservation = (json["reservation"] as? String).flatMap(Reservation.init(rawValue:))
        else {
            warnings?.log("Invalid TDM object", model: Self.self, source: json, severity: .minor)
            throw JSONError.parsing(Self.self)
        }

        self.init(
            reservation: reservation,
            policy: (json["policy"] as? String).flatMap { HTTPURL(string: $0) }
        )
    }

    public var json: [String: Any] {
        makeJSON([
            "reservation": reservation.rawValue,
            "policy": encodeIfNotNil(policy?.string),
        ])
    }
}
