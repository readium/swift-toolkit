//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

class Fixtures {
    
    let path: String?
    
    init(path: String? = nil) {
        self.path = path
    }
    
    private lazy var bundle = Bundle(for: type(of: self))
    
    func url(for filepath: String) -> URL {
        return bundle.resourceURL!.appendingPathComponent("Fixtures/\(path ?? "")/\(filepath)")
    }

    func data(at filepath: String) -> Data {
        return try! Data(contentsOf: url(for: filepath))
    }
    
}
