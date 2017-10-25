//
//  Decipherer.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/24/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

public protocol Decipherer {
    func decipher(_ data: Data) throws -> Data?
}
