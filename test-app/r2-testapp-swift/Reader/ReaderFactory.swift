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
    func make(tableOfContents: [Link], format: Publication.Format) -> OutlineTableViewController {
        let controller = storyboards.outline.instantiateViewController(withIdentifier: "OutlineTableViewController") as! OutlineTableViewController
        controller.publicationFormat = format
        controller.tableOfContents = tableOfContents
        return controller
    }
}

extension ReaderFactory: DrmManagementTableViewControllerFactory {
    func make(drm: DRM) -> DrmManagementTableViewController {
        let controller =
            storyboards.drm.instantiateViewController(withIdentifier: "DrmManagementTableViewController") as! DrmManagementTableViewController
        controller.viewModel = DRMViewModel.make(drm: drm, presentingViewController: controller)
        return controller
    }
}
