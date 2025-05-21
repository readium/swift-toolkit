//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared

extension ReadError: EquatableError {}

protocol EquatableError: Equatable {
    var equatableRepresentation: String { get }
}

extension EquatableError {
    var equatableRepresentation: String {
        var desc = ""
        Swift.dump(self, to: &desc)
        return desc
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.equatableRepresentation == rhs.equatableRepresentation
    }
}
