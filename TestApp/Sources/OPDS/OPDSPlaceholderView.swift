//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Kingfisher
import UIKit

// MARK: Placeholder base class

class OPDSPlaceholderView: UITextView {
    convenience init(frame: CGRect, title: String?, author: String?) {
        self.init(frame: frame)

        if let title = title {
            text = title + "\n_________\n"
        }

        if let author = author {
            text = text + author
        }

        text = text + ""

        layer.borderWidth = 5.0
        layer.borderColor = #colorLiteral(red: 0.08269290555, green: 0.2627741129, blue: 0.3623990017, alpha: 1).cgColor
        backgroundColor = #colorLiteral(red: 0.05882352963, green: 0.180392161, blue: 0.2470588237, alpha: 1)
        textColor = #colorLiteral(red: 0.8639426257, green: 0.8639426257, blue: 0.8639426257, alpha: 1)
        font = UIFont.systemFont(ofSize: 9)
    }
}

// MARK: - Placeholder subclass used in a publication screen

class OPDSPlaceholderPublicationView: OPDSPlaceholderView, Placeholder {}

// MARK: - Placeholder subclass used in a list of publications screen

class OPDSPlaceholderListView: OPDSPlaceholderView, Placeholder {}

// MARK: - Placeholder protocol specific to publication screen

extension OPDSPlaceholderPublicationView {
    public func add(to imageView: KFCrossPlatformImageView) {
        imageView.addSubview(self)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: self, attribute: .centerX, relatedBy: .equal, toItem: imageView, attribute: .centerX, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: self, attribute: .centerY, relatedBy: .equal, toItem: imageView, attribute: .centerY, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: imageView, attribute: .height, multiplier: 0.9, constant: 0),
            NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: imageView, attribute: .width, multiplier: 0.5, constant: 0),
        ])
    }
}
