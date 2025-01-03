//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

#if !SWIFT_PACKAGE
    extension Bundle {
        #if !COCOAPODS
            /// Returns ReadiumNavigator's bundle by querying an arbitrary type.
            static let module = Bundle(for: EPUBNavigatorViewController.self)
        #else
            /// Returns ReadiumNavigator's bundle by querying for the cocoapods bundle.
            static let module = Bundle.getCocoaPodsBundle()
            static func getCocoaPodsBundle() -> Bundle {
                let rootBundle = Bundle(for: EPUBNavigatorViewController.self)
                guard let resourceBundleUrl = rootBundle.url(forResource: "ReadiumNavigator", withExtension: "bundle") else {
                    fatalError("Unable to locate ReadiumNavigator.bundle")
                }
                guard let bundle = Bundle(url: resourceBundleUrl) else {
                    fatalError("Unable to load ReadiumNavigator.bundle")
                }

                return bundle
            }
        #endif
    }
#endif
