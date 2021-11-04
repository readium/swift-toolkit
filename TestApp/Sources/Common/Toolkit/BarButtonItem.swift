//
//  BarButtonItem.swift
//  r2-testapp-swift
//
//  Created by Matt McCullough on 28/04/2020.
//
//  Copyright 2020 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit

class BarButtonItem: UIBarButtonItem {
    typealias ActionFunc = (UIBarButtonItem) -> Void

    private var actionFunc: ActionFunc?

    convenience init(title: String?, style: UIBarButtonItem.Style, actionHandler: ActionFunc?) {
        self.init(title: title, style: style, target: nil, action: #selector(handlePress))
        target = self
        self.actionFunc = actionHandler
    }

    convenience init(image: UIImage?, style: UIBarButtonItem.Style, actionFunc: ActionFunc?) {
        self.init(image: image, style: style, target: nil, action: #selector(handlePress))
        target = self
        self.actionFunc = actionFunc
    }

    convenience init(barButtonSystemItem systemItem: UIBarButtonItem.SystemItem, actionHandler: ActionFunc?) {
        self.init(barButtonSystemItem: systemItem, target: nil, action: #selector(handlePress))
        target = self
        self.actionFunc = actionHandler
    }

    @objc func handlePress(sender: UIBarButtonItem) {
        actionFunc?(sender)
    }
}
