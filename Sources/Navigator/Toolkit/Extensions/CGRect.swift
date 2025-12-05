//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit

extension CGRect {
    /// Parses a `CGRect` from its JSON representation.
    init?(json: Any?) {
        guard let json = json as? [String: Any] else {
            return nil
        }
        self.init(
            x: json["left"] as? CGFloat ?? 0,
            y: json["top"] as? CGFloat ?? 0,
            width: json["width"] as? CGFloat ?? 0,
            height: json["height"] as? CGFloat ?? 0
        )
    }
}
