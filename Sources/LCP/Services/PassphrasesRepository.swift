//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

protocol PassphrasesRepository {
    func all() -> [String]
    func passphrase(forLicenseId licenseId: String) -> String?
    func passphrases(forUserId userId: String) -> [String]

    @discardableResult
    func addPassphrase(_ passphraseHash: String, forLicenseId licenseId: String?, provider: String?, userId: String?) -> Bool
}
