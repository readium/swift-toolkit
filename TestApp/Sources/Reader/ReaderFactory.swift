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

final class ReaderFactory {
    final class Storyboards {
        let drm = UIStoryboard(name: "DRM", bundle: nil)
    }

    let storyboards = Storyboards()
}

extension ReaderFactory: OutlineTableViewControllerFactory {
    func make(publication: Publication, bookId: Book.Id, bookmarks: BookmarkRepository, highlights: HighlightRepository) -> OutlineTableViewAdapter {
        let view = OutlineTableView(publication: publication, bookId: bookId, bookmarkRepository: bookmarks, highlightRepository: highlights)
        let hostingVC = OutlineHostingController(rootView: view)
        hostingVC.title = publication.metadata.title

        return (hostingVC, view.goToLocatorPublisher)
    }
}

#if LCP

    extension ReaderFactory: LCPManagementTableViewControllerFactory {
        func make(publication: Publication, delegate: ReaderModuleDelegate?) -> LCPManagementTableViewController? {
            guard let license = publication.lcpLicense else {
                return nil
            }

            let controller = storyboards.drm.instantiateViewController(withIdentifier: "DRMManagementTableViewController") as! LCPManagementTableViewController
            controller.moduleDelegate = delegate
            controller.viewModel = LCPViewModel(license: license, presentingViewController: controller)
            return controller
        }
    }

#endif

/// This is a wrapper for the "OutlineTableView" to encapsulate the  "Cancel" button behaviour
class OutlineHostingController: UIHostingController<OutlineTableView> {
    override public init(rootView: OutlineTableView) {
        super.init(rootView: rootView)
        navigationItem.setLeftBarButton(UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed)), animated: true)
    }

    @available(*, unavailable)
    @MainActor @objc dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func cancelButtonPressed(_ sender: UIBarItem) {
        navigationController?.dismiss(animated: true, completion: nil)
    }
}
