//
//  LicensesRepository.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 08.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

protocol LicensesRepository {
    
    func addLicense(_ license: LicenseDocument) throws
    
    func copiesLeft(for licenseId: String) throws -> Int?
    func setCopiesLeft(_ quantity: Int, for licenseId: String) throws
    
    func printsLeft(for licenseId: String) throws -> Int?
    func setPrintsLeft(_ quantity: Int, for licenseId: String) throws

}
