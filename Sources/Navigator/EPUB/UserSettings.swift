//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

import ReadiumShared

@available(*, unavailable, message: "Take a look at the migration guide to migrate to the new Preferences API")
public class UserSettings {
    public init(
        hyphens: Bool = false,
        fontSize: Float = 100,
        fontFamily: Int = 0,
        appearance: Int = 0,
        verticalScroll: Bool = false,
        publisherDefaults: Bool = true,
        textAlignment: Int = 0,
        columnCount: Int = 0,
        wordSpacing: Float = 0,
        letterSpacing: Float = 0,
        pageMargins: Float = 1,
        lineHeight: Float = 1.5,
        paragraphMargins: Float? = nil,
        textColor: String? = nil,
        backgroundColor: String? = nil
    ) {}

    public func save() {}
}
