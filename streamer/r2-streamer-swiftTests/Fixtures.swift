//
//  Fixtures.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 01/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
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
