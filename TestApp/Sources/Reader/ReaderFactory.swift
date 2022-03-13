//
//  ReaderFactory.swift
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
import SwiftUI
import Combine

typealias OutlineLocatorSubsriber = CustomLocatorSubscriber

final class ReaderFactory {
    
    final class Storyboards {
        let drm = UIStoryboard(name: "DRM", bundle: nil)
    }
    
    let storyboards = Storyboards()
}

extension ReaderFactory: OutlineTableViewControllerFactory {
    func make(publication: Publication, bookId: Book.Id, bookmarks: BookmarkRepository, highlights: HighlightRepository, subscriber: OutlineLocatorSubsriber) -> UIHostingController<OutlineTableView> {
        let view = OutlineTableView(publication: publication, bookId: bookId, bookmarkRepository: bookmarks, highlightRepository: highlights)
        view.goToLocatorPublisher.receive(subscriber: subscriber)
        return UIHostingController(rootView: view)
    }
}

extension ReaderFactory: DRMManagementTableViewControllerFactory {
    func make(publication: Publication, delegate: ReaderModuleDelegate?) -> DRMManagementTableViewController {
        let controller =
            storyboards.drm.instantiateViewController(withIdentifier: "DRMManagementTableViewController") as! DRMManagementTableViewController
        controller.moduleDelegate = delegate
        controller.viewModel = DRMViewModel.make(publication: publication, presentingViewController: controller)
        return controller
    }
}
