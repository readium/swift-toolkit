//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import SwiftUI
import UIKit

final class OPDSFactory {
    /// To simplify the refactoring of dependencies, the factory is a singleton for now.
    static let shared = OPDSFactory()

    weak var delegate: OPDSModuleDelegate?
    private let storyboard = UIStoryboard(name: "OPDS", bundle: nil)
}

extension OPDSFactory: OPDSRootTableViewControllerFactory {
    func make(feedURL: URL, indexPath: IndexPath?) -> OPDSRootTableViewController {
        let controller = storyboard.instantiateViewController(withIdentifier: "OPDSRootTableViewController") as! OPDSRootTableViewController
        controller.factory = self
        controller.originalFeedURL = feedURL
        controller.originalFeedIndexPath = nil
        return controller
    }
}

extension OPDSFactory: OPDSPublicationInfoViewControllerFactory {
    func make(publication: Publication) -> OPDSPublicationInfoViewController {
        let controller = storyboard.instantiateViewController(withIdentifier: "OPDSPublicationInfoViewController") as! OPDSPublicationInfoViewController
        controller.publication = publication
        controller.moduleDelegate = delegate
        return controller
    }
}
