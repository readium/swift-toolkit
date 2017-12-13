//
//  DrmLicense.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 11/22/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

public protocol DrmLicense {
    func decipher(_ data: Data) throws -> Data?
    func areRightsValid() throws
    func register()
    func renew(endDate: Date?, completion: @escaping (Error?) -> Void)
    func `return`(completion: @escaping (Error?) -> Void)
    // property access.
    func currentStatus() -> String
    func lastUpdate() -> Date
    func issued() -> Date
    func provider() -> URL
    func rightsEnd() -> Date?
    func potentialRightsEnd() -> Date?
    func rightsStart() -> Date?
    func rightsPrints() -> Int?
    func rightsCopies() -> Int?
}
