//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit

protocol PublicationMenuViewControllerDelegate: AnyObject {
    func infosButtonTapped()
    func removeButtonTapped()
    func cancelButtonTapped()
}

class PublicationMenuViewController: UIViewController {
    weak var delegate: PublicationMenuViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func infosButtonTapped(_ sender: Any) {
        delegate?.infosButtonTapped()
    }

    @IBAction func removeButtonTapped(_ sender: Any) {
        delegate?.removeButtonTapped()
    }

    @IBAction func cancelButtonTapped(_ sender: Any) {
        delegate?.cancelButtonTapped()
    }
}
