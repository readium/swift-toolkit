//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import R2Shared
import UIKit

/// The OPDS module handles the presentation of OPDS catalogs.
protocol OPDSModuleAPI {
    var delegate: OPDSModuleDelegate? { get }

    /// Root navigation controller containing the OPDS catalogs.
    /// Can be used to present the OPDS catalogs to the user.
    var rootViewController: UINavigationController { get }
}

protocol OPDSModuleDelegate: ModuleDelegate {
    /// Called when an OPDS publication needs to be downloaded.
    func opdsDownloadPublication(_ publication: Publication?, at link: Link, sender: UIViewController) async throws -> Book
}

final class OPDSModule: OPDSModuleAPI {
    weak var delegate: OPDSModuleDelegate?

    private let factory = OPDSFactory.shared

    init(delegate: OPDSModuleDelegate?) {
        self.delegate = delegate
        factory.delegate = delegate
    }

    private(set) lazy var rootViewController: UINavigationController = {
        let catalogViewController: OPDSCatalogSelectorViewController = factory.make()
        return UINavigationController(rootViewController: catalogViewController)
    }()
}
