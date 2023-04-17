//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

#if LCP

    import Combine
    import Foundation
    import R2LCPClient
    import R2Shared
    import ReadiumLCP
    import UIKit

    class LCPLibraryService: DRMLibraryService {
        private var lcpService = LCPService(client: LCPClient())

        lazy var contentProtection: ContentProtection? = lcpService.contentProtection()

        func canFulfill(_ file: URL) -> Bool {
            file.pathExtension.lowercased() == "lcpl"
        }

        func fulfill(_ file: URL) async throws -> DRMFulfilledPublication? {
            try await withCheckedThrowingContinuation { cont in
                lcpService.acquirePublication(from: file) { result in
                    // Removes the license file, but only if it's in the App directory (e.g. Inbox/).
                    // Otherwise we might delete something from a shared location (e.g. iCloud).
                    if Paths.isAppFile(at: file) {
                        try? FileManager.default.removeItem(at: file)
                    }

                    switch result {
                    case let .success(pub):
                        cont.resume(returning: DRMFulfilledPublication(
                            localURL: pub.localURL,
                            suggestedFilename: pub.suggestedFilename
                        ))
                    case let .failure(error):
                        cont.resume(throwing: error)
                    case .cancelled:
                        cont.resume(returning: nil)
                    }
                }
            }
        }
    }

    /// Facade to the private R2LCPClient.framework.
    class LCPClient: ReadiumLCP.LCPClient {
        func createContext(jsonLicense: String, hashedPassphrase: String, pemCrl: String) throws -> LCPClientContext {
            try R2LCPClient.createContext(jsonLicense: jsonLicense, hashedPassphrase: hashedPassphrase, pemCrl: pemCrl)
        }

        func decrypt(data: Data, using context: LCPClientContext) -> Data? {
            R2LCPClient.decrypt(data: data, using: context as! DRMContext)
        }

        func findOneValidPassphrase(jsonLicense: String, hashedPassphrases: [String]) -> String? {
            R2LCPClient.findOneValidPassphrase(jsonLicense: jsonLicense, hashedPassphrases: hashedPassphrases)
        }
    }

#endif
