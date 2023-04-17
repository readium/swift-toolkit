//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import R2Shared
import UIKit

protocol DetailsTableViewControllerFactory {
    func make(publication: Publication) -> DetailsTableViewController
}

final class DetailsTableViewController: UITableViewController {
    var publication: Publication!

    // Informations
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var idLabel: UILabel!

    override func viewDidLoad() {
        titleLabel.text = publication?.metadata.title
        idLabel.text = publication?.metadata.identifier
    }
}
