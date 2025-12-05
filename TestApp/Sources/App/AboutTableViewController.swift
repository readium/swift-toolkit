//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit

class AboutTableViewController: UITableViewController {
    @IBOutlet var versionNumberCell: UITableViewCell!
    @IBOutlet var buildNumberCell: UITableViewCell!

    override func viewDidLoad() {
        super.viewDidLoad()

        versionNumberCell.textLabel?.text = NSLocalizedString("app_version_caption", comment: "Caption for the app version in About screen")
        versionNumberCell.detailTextLabel?.text = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

        buildNumberCell.textLabel?.text = NSLocalizedString("build_version_caption", comment: "Caption for the build version in About screen")
        buildNumberCell.detailTextLabel?.text = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var url: URL?

        if indexPath.section == 1 {
            if indexPath.row == 0 {
                url = URL(string: "https://www.edrlab.org/")
            } else {
                url = URL(string: "https://opensource.org/licenses/BSD-3-Clause")
            }
        }

        if let url = url {
            UIApplication.shared.open(url)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}
