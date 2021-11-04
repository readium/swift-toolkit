//
//  BookmarkCell.swift
//  r2-testapp-swift
//
//  Created by Senda Li on 2018/7/19.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit

class BookmarkCell: UITableViewCell {

    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    lazy var timeLabel: UILabel = {
        let label = UILabel()
        self.contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        if let detailLabel = self.detailTextLabel {
            label.textColor = detailLabel.textColor
            label.font = detailLabel.font

            NSLayoutConstraint.activate([
                label.bottomAnchor.constraint(equalTo: detailLabel.bottomAnchor),
                label.heightAnchor.constraint(equalTo: detailLabel.heightAnchor),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
            ])
        }

        return label
    } ()

    var formattedDate: Date? {
        didSet {
            self.timeLabel.text = {
                if let newDate = formattedDate{
                    return dateFormatter.string(from: newDate)
                } else {
                    return ""
                }
            } ()
            self.timeLabel.sizeToFit()
        }
    }
}
