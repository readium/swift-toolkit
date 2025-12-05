//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumShared
import SwiftUI
import UIKit

enum OPDSError: Error {
    case invalidURL(String)
}

/// The OPDS module handles the presentation of OPDS catalogs.
protocol OPDSModuleAPI {
    var delegate: OPDSModuleDelegate? { get }

    /// Root navigation controller containing the OPDS catalogs.
    /// Can be used to present the OPDS catalogs to the user.
    var rootViewController: UINavigationController { get }
}

protocol OPDSModuleDelegate: ModuleDelegate {
    /// Called when an OPDS publication needs to be imported.
    func opdsDownloadPublication(
        _ publication: Publication?,
        at link: ReadiumShared.Link,
        sender: UIViewController,
        progress: @escaping (Double) -> Void
    ) async throws -> Book
}

final class OPDSModule: OPDSModuleAPI {
    weak var delegate: OPDSModuleDelegate?

    private let factory = OPDSFactory.shared

    init(delegate: OPDSModuleDelegate?) {
        self.delegate = delegate
        factory.delegate = delegate
    }

    private(set) lazy var rootViewController: UINavigationController = {
        let viewModel = OPDSCatalogsViewModel()

        let catalogViewController = UIHostingController(
            rootView: OPDSCatalogsView(viewModel: viewModel)
        )

        let navigationController = UINavigationController(
            rootViewController: catalogViewController
        )

        viewModel.openCatalog = { [weak navigationController] url, indexPath in
            let viewController = OPDSFactory.shared.make(
                feedURL: url,
                indexPath: indexPath
            )
            navigationController?.pushViewController(viewController, animated: true)
        }

        return navigationController
    }()
}
