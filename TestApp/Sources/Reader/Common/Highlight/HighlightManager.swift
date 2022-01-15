//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit
import R2Shared

protocol HighlightManager {
    func defaultHighlightColor(for locator: Locator) -> HighlightColor
    func color(for highlightColor: HighlightColor) -> UIColor
    
    func saveHighlight(_ highlight: Highlight)
    func updateHighlight(_ highlightID: UUID, withColor color: HighlightColor)
    func deleteHighlight(_ highlightID: UUID)
}

