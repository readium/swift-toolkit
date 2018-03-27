//
//  PublicationCell.swift
//  r2-navigator
//
//  Created by Alexandre Camilleri on 6/13/17.
//  Copyright © 2017 European Digital Reading Lab. All rights reserved.
//

import UIKit

class OPDSPublicationCell: OPDSPublicationCellBase {
    var infoView: UIView
    var infoViewController: OPDSPublicationCellInfoViewController

    override init(frame: CGRect) {
        infoViewController = OPDSPublicationCellInfoViewController()
        infoView = infoViewController.view

        super.init(frame: frame)
        imageView = (infoViewController.imageView)!
        frontView = infoView
        infoView.frame = self.bounds
        imageView!.contentMode = .scaleAspectFit
        contentView.addSubview(infoView)
    }
}
