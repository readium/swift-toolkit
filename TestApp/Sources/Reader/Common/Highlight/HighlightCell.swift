//
//  HighlightCell.swift
//  r2-testapp-swift
//
//  Copyright 2021 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit

class HighlightCell: UITableViewCell {
    lazy var colorLabel: UILabel = {
        let label = UILabel()
        self.textLabel!.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.leftAnchor.constraint(equalTo: self.textLabel!.leftAnchor, constant: -4),
            label.heightAnchor.constraint(equalTo: self.textLabel!.heightAnchor),
            label.widthAnchor.constraint(equalToConstant: 3)
        ])

        return label
    } ()
}
