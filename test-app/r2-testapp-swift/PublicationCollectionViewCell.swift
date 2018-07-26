//
//  PublicationCollectionViewCell.swift
//  r2-testapp-swift
//
//  Created by Geoffrey Bugniot on 26/07/2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit

class PublicationCollectionViewCell: UICollectionViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    
}
