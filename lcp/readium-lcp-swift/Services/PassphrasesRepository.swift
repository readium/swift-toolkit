//
//  PassphrasesRepository.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 04.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


protocol PassphrasesRepository {
    
    func all() -> [String]
    func passphrase(forLicenseId licenseId: String) -> String?
    func passphrases(forUserId userId: String) -> [String]
    
    @discardableResult
    func addPassphrase(_ passphraseHash: String, forLicenseId licenseId: String?, provider: String?, userId: String?) -> Bool

}
