//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

#if LCP
    import R2LCPClient
    import ReadiumAdapterLCPSQLite
    import ReadiumLCP
#endif

enum LCPModuleError: Error {
    case lcpNotEnabled
}

struct LCPPublication {
    let localURL: FileURL
    let suggestedFilename: String
}

protocol LCPModuleAPI {
    init(readium: Readium)
    func fulfill(_ file: FileURL, progress: @escaping (Double) -> Void) async throws -> LCPPublication
}

extension LCPModuleAPI {
    func canFulfill(_ file: FileURL) -> Bool {
        file.pathExtension == .lcpl
    }
}

#if LCP
    final class LCPModule: LCPModuleAPI {
        private let lcpService: LCPService

        init(readium: Readium) {
            lcpService = readium.lcpService
        }

        func fulfill(_ file: FileURL, progress: @escaping (Double) -> Void) async throws -> LCPPublication {
            let pub = try await lcpService.acquirePublication(
                from: .file(file),
                onProgress: { p in
                    switch p {
                    case .indefinite:
                        progress(0)
                    case let .percent(percent):
                        progress(Double(percent))
                    }
                }
            ).get()

            // Removes the license file, but only if it's in the App directory (e.g. Inbox/).
            // Otherwise we might delete something from a shared location (e.g. iCloud).
            if Paths.isAppFile(at: file) {
                try? FileManager.default.removeItem(at: file.url)
            }

            return LCPPublication(
                localURL: pub.localURL,
                suggestedFilename: pub.suggestedFilename
            )
        }
    }

#else

    final class LCPModule: LCPModuleAPI {
        init(readium: Readium) {}

        func fulfill(_ file: FileURL, progress: @escaping (Double) -> Void) async throws -> LCPPublication {
            throw LCPModuleError.lcpNotEnabled
        }
    }
#endif
