//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import XCTest

#if !SWIFT_PACKAGE
    extension Bundle {
        static let module = Bundle(for: Fixtures.self)
    }
#endif

class Fixtures {
    func url(for filepath: String) -> FileURL {
        FileURL(url: Bundle.module.resourceURL!.appendingPathComponent("Fixtures/\(filepath)"))!
    }

    func data(at filepath: String) -> Data {
        try! XCTUnwrap(try? Data(contentsOf: url(for: filepath).url))
    }

    func json<T>(at filepath: String) -> T {
        try! XCTUnwrap(JSONSerialization.jsonObject(with: data(at: filepath)) as? T)
    }
}
