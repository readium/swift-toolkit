//
//  PublicationInfoViewController.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Feb-19-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit

class PublicationInfoViewController : UIViewController {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init() {
        super.init(nibName: "PublicationInfoView", bundle: nil)
    }
}
