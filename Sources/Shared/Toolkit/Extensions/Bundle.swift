//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

#if !SWIFT_PACKAGE
    extension Bundle {
        #if !COCOAPODS
            /// Returns ReadiumShared's bundle by querying an arbitrary type.
            static let module = Bundle(for: Publication.self)
        #else
            /// Returns ReadiumShared's bundle by querying for the cocoapods bundle.
            static let module = Bundle.getCocoaPodsBundle()
            static func getCocoaPodsBundle() -> Bundle {
                let rootBundle = Bundle(for: Publication.self)
                guard let resourceBundleUrl = rootBundle.url(forResource: "ReadiumShared", withExtension: "bundle") else {
                    fatalError("Unable to locate ReadiumShared.bundle")
                }
                guard let bundle = Bundle(url: resourceBundleUrl) else {
                    fatalError("Unable to load ReadiumShared.bundle")
                }

                return bundle
            }
        #endif
    }
#endif
