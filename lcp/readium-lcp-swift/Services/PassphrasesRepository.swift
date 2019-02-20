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
    
    // FIXME: address "a/ If the user id has been indicated in the license (it is highly recommended but not required), check if one or more passphrase hash associated with licenses from the same user (by origin + user id) have been stored. If one or more values are found, call the r2-lcp-client library (C++) with the json license and the array of passphrase hash as parameters. The lib returns the correct passphrase, if any, or an error if none is correct. If ok jump to 3/."
    func passphrase(forLicenseId licenseId: String) -> String?
    func passphrases(forUserId userId: String) -> [String]
    
    func addPassphrase(_ passphraseHash: String, forLicenseId licenseId: String, provider: String, userId: String?)

}
