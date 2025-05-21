//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

class BarButtonItem: UIBarButtonItem {
    typealias ActionFunc = (UIBarButtonItem) -> Void

    private var actionFunc: ActionFunc?

    convenience init(title: String?, style: UIBarButtonItem.Style, actionHandler: ActionFunc?) {
        self.init(title: title, style: style, target: nil, action: #selector(handlePress))
        target = self
        actionFunc = actionHandler
    }

    convenience init(image: UIImage?, style: UIBarButtonItem.Style, actionFunc: ActionFunc?) {
        self.init(image: image, style: style, target: nil, action: #selector(handlePress))
        target = self
        self.actionFunc = actionFunc
    }

    convenience init(barButtonSystemItem systemItem: UIBarButtonItem.SystemItem, actionHandler: ActionFunc?) {
        self.init(barButtonSystemItem: systemItem, target: nil, action: #selector(handlePress))
        target = self
        actionFunc = actionHandler
    }

    @objc func handlePress(sender: UIBarButtonItem) {
        actionFunc?(sender)
    }
}
