//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

protocol LicensesRepository {
    func addLicense(_ license: LicenseDocument) throws

    func copiesLeft(for licenseId: String) throws -> Int?
    func setCopiesLeft(_ quantity: Int, for licenseId: String) throws

    func printsLeft(for licenseId: String) throws -> Int?
    func setPrintsLeft(_ quantity: Int, for licenseId: String) throws
}
