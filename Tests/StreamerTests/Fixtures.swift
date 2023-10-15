//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

#if !SWIFT_PACKAGE
    extension Bundle {
        static let module = Bundle(for: Fixtures.self)
    }
#endif

class Fixtures {
    let path: String?

    init(path: String? = nil) {
        self.path = path
    }

    func url(for filepath: String) -> FileURL {
        FileURL(url: Bundle.module.resourceURL!.appendingPathComponent("Fixtures/\(path ?? "")/\(filepath)"))!
    }

    func data(at filepath: String) -> Data {
        try! Data(contentsOf: url(for: filepath).url)
    }
}
