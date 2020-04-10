//
//  Fixtures.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 11/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

class Fixtures {
    
    let path: String
    
    init(path: String) {
        self.path = path
    }
    
    private lazy var bundle = Bundle(for: type(of: self))
    
    func url(for filepath: String) -> URL {
        return bundle.resourceURL!.appendingPathComponent("Fixtures/\(path)/\(filepath)")
    }
    
}
