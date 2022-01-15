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


final class ReaderFactory {
    
    final class Storyboards {
        let outline = UIStoryboard(name: "Outline", bundle: nil)
        let drm = UIStoryboard(name: "DRM", bundle: nil)
    }
    
    let storyboards = Storyboards()
}

extension ReaderFactory: OutlineTableViewControllerFactory {
    func make(publication: Publication, bookId: Book.Id, bookmarks: BookmarkRepository, highlights: HighlightRepository) -> OutlineTableViewController {
        let controller = storyboards.outline.instantiateViewController(withIdentifier: "OutlineTableViewController") as! OutlineTableViewController
        controller.publication = publication
        controller.bookId = bookId
        controller.bookmarkRepository = bookmarks
        controller.highlightRepository = highlights
        return controller
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
