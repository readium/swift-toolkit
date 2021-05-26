//
//  LCPLibraryService.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 01.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

#if LCP

import Foundation
import UIKit
import R2Shared
import R2LCPClient
import ReadiumLCP


class LCPLibraryService: DRMLibraryService {

    private var lcpService = LCPService(client: LCPClient())
    
    lazy var contentProtection: ContentProtection? = lcpService.contentProtection()
    
    func canFulfill(_ file: URL) -> Bool {
        return file.pathExtension.lowercased() == "lcpl"
    }
    
    func fulfill(_ file: URL) -> Deferred<DRMFulfilledPublication, Error> {
        return deferred { completion in
            self.lcpService.acquirePublication(from: file) { result in
                completion(result
                    .map {
                        DRMFulfilledPublication(
                            localURL: $0.localURL,
                            suggestedFilename: $0.suggestedFilename
                        )
                    }
                    .eraseToAnyError()
                )
            }
        }
    }

}

/// Facade to the private R2LCPClient.framework.
class LCPClient: ReadiumLCP.LCPClient {

    func createContext(jsonLicense: String, hashedPassphrase: String, pemCrl: String) throws -> LCPClientContext {
        return try R2LCPClient.createContext(jsonLicense: jsonLicense, hashedPassphrase: hashedPassphrase, pemCrl: pemCrl)
    }

    func decrypt(data: Data, using context: LCPClientContext) -> Data? {
        return R2LCPClient.decrypt(data: data, using: context as! DRMContext)
    }

    func findOneValidPassphrase(jsonLicense: String, hashedPassphrases: [String]) -> String? {
        return R2LCPClient.findOneValidPassphrase(jsonLicense: jsonLicense, hashedPassphrases: hashedPassphrases)
    }

}

#endif
