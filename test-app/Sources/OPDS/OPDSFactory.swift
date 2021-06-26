//
//  OPDSFactory.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 22.02.19.
//
//  Copyright 2019 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared

final class OPDSFactory {
    
    /// To simplify the refactoring of dependencies, the factory is a singleton for now.
    static let shared = OPDSFactory()
    
    weak var delegate: OPDSModuleDelegate?
    fileprivate let storyboard = UIStoryboard(name: "OPDS", bundle: nil)
    
}


extension OPDSFactory: OPDSCatalogSelectorViewControllerFactory {
    func make() -> OPDSCatalogSelectorViewController {
        let controller = storyboard.instantiateViewController(withIdentifier: "OPDSCatalogSelectorViewController") as! OPDSCatalogSelectorViewController
        return controller
    }
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


extension OPDSFactory: OPDSFacetViewControllerFactory {
    func make(feed: Feed) -> OPDSFacetViewController {
        let controller = storyboard.instantiateViewController(withIdentifier: "OPDSFacetViewController") as! OPDSFacetViewController
        controller.feed = feed
        return controller
    }
}
