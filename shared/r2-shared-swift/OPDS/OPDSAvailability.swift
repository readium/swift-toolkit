//
//  OPDSAvailability.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 24/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Indicated the availability of a given resource.
/// https://drafts.opds.io/schema/properties.schema.json
public struct OPDSAvailability: Equatable {
    
    let state: State
    
    /// Timestamp for the previous state change.
    let since: Date?
    
    /// Timestamp for the next state change.
    let until: Date?

    public init(state: State, since: Date? = nil, until: Date? = nil) {
        self.state = state
        self.since = since
        self.until = until
    }
    
    public init?(json: Any?) throws {
        if json == nil {
            return nil
        }
        guard let json = json as? [String: Any],
            let state: State = parseRaw(json["state"]) else
        {
            throw JSONError.parsing(OPDSAvailability.self)
        }
        
        self.init(
            state: state,
            since: parseDate(json["since"]),
            until: parseDate(json["until"])
        )
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "state": encodeRawIfNotNil(state),
            "since": encodeIfNotNil(since?.iso8601),
            "until": encodeIfNotNil(until?.iso8601)
        ])
    }
    
    public enum State: String {
        case available, unavailable, reserved, ready
    }
    
}
