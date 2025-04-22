//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit

protocol PublicationMenuViewControllerDelegate: AnyObject {
    func metadataButtonTapped()
    func removeButtonTapped()
    func cancelButtonTapped()
}

class PublicationMenuViewController: UIViewController {
    weak var delegate: PublicationMenuViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func metadataButtonTapped(_ sender: Any) {
        delegate?.metadataButtonTapped()
    }

    @IBAction func removeButtonTapped(_ sender: Any) {
        delegate?.removeButtonTapped()
    }

    @IBAction func cancelButtonTapped(_ sender: Any) {
        delegate?.cancelButtonTapped()
    }
}
