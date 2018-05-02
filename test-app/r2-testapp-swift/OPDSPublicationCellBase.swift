//
//  OPDSPublicationCellBase.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Mar-27-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import Foundation


import UIKit

class OPDSPublicationCellBase: UICollectionViewCell {
    var frontView: UIView?
    var imageView: UIImageView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityHint = "Tap for info."
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Add shadow to the views. To be called when the image has been loaded.
    public func applyShadows() {
//        if (imageView != nil) {
//            configureShadow(for: imageView!, with: 0.3)
//        }
    }

    public func configureShadow(for view: UIView, with opacity: Float) {
        view.layer.shadowColor = UIColor.lightGray.cgColor
        view.layer.shadowOffset = CGSize.init(width: 0, height: 3.0)
        view.layer.shadowOpacity = opacity
        view.layer.masksToBounds = false
        view.layer.shadowPath = UIBezierPath(roundedRect: bounds,
                                             cornerRadius: contentView.layer.cornerRadius).cgPath
    }
}

