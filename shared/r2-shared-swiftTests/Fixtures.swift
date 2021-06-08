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
import XCTest

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
    
    func url(for filepath: String) -> URL {
        return try! XCTUnwrap(Bundle.module.resourceURL?.appendingPathComponent("Fixtures/\(path ?? "")/\(filepath)"))
    }
    
    func data(at filepath: String) -> Data {
        return try! XCTUnwrap(try? Data(contentsOf: url(for: filepath)))
    }
    
    func json<T>(at filepath: String) -> T {
        return try! XCTUnwrap(JSONSerialization.jsonObject(with: data(at: filepath)) as? T)
    }
    
}
