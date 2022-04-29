//
//  TargetAction.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 31/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit

/// Represents a couple (`target`, `action`) which can be invoked from a `sender`.
final class TargetAction {
    
    private weak var target: AnyObject?
    private let action: Selector
    
    init(target: AnyObject, action: Selector) {
        self.target = target
        self.action = action
    }
    
    func invoke(from sender: Any?) {
        if let target = target {
            UIApplication.shared.sendAction(action, to: target, from: sender, for: nil)
        }
    }
    
}
