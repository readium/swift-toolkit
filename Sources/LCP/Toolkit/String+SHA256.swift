//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CryptoKit
import Foundation

extension String {
    func sha256() -> String {
        let digest = SHA256.hash(data: Data(utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
