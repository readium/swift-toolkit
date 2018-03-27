//
//  OPDSPublicationCellSimple.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Mar-27-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit

class OPDSPublicationCellSimple: OPDSPublicationCellBase {
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView = UIImageView()
        frontView = imageView
        imageView!.frame = self.bounds
        imageView!.contentMode = .scaleAspectFit
        contentView.addSubview(imageView!)
    }
}
