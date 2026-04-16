//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumInternal
import Testing

enum URLTests {
    @Suite("addingSchemeWhenMissing") struct AddingSchemeWhenMissing {
        @Test("adds scheme to schemeless URL")
        func addingSchemeWhenMissing() {
            #expect(
                URL(string: "//www.google.com/path")?.addingSchemeWhenMissing("test")
                    == URL(string: "test://www.google.com/path")
            )
            #expect(
                URL(string: "http://www.google.com/path")?.addingSchemeWhenMissing("test")
                    == URL(string: "http://www.google.com/path")
            )
        }
    }
}
