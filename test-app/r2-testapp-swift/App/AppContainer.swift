//
//  AppContainer.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 20.02.19.
//
//  Copyright 2019 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared
import R2Streamer

enum AppContainerError: Error {
    case cantStartPublicationServer
}

final class AppContainer {
    
    /// To simplify the refactoring of dependencies, the container is a singleton for now.
    static let shared = try! AppContainer()

    fileprivate let storyboards = Storyboards()
    fileprivate let library: LibraryService
    
    private init() throws {
        guard let server = PublicationServer() else {
            throw AppContainerError.cantStartPublicationServer
        }
        library = LibraryService(publicationServer: server)
    }
    
}

final class Storyboards {
    let main = UIStoryboard(name: "AppMain", bundle: nil)
    let details = UIStoryboard(name: "Details", bundle: nil)
    let settings = UIStoryboard(name: "UserSettings", bundle: nil)
    let opds = UIStoryboard(name: "OPDS", bundle: nil)
    let drm = UIStoryboard(name: "DrmManagement", bundle: nil)
}

extension AppContainer: AppCoordinatorFactory {
    func make() -> AppCoordinator {
        let initial = storyboards.main.instantiateInitialViewController()!
        
        // FIXME: Storyboards make dependency injection more complicated than necessary, use simple XIB instead?
        let libraryViewController: LibraryViewController! = initial.findChildViewController()
        libraryViewController.container = self
        libraryViewController.library = library

        return AppCoordinator(
            library: library,
            initialViewController: initial
        )
    }
}

extension AppContainer: DetailsTableViewControllerFactory {
    func make(publication: Publication) -> DetailsTableViewController {
        let controller = storyboards.details.instantiateViewController(withIdentifier: "DetailsTableViewController") as! DetailsTableViewController
        controller.publication = publication
        return controller
    }
}

extension AppContainer: EpubViewControllerFactory {
    func make(publication: Publication, at index: Int, progression: Double?, drm: DRM?) -> EpubViewController {
        return EpubViewController(container: self, publication: publication, atIndex: index, progression: progression, drm)
    }
}

extension AppContainer: CbzViewControllerFactory {
    func make(publication: Publication) -> CbzViewController {
        return CbzViewController(container: self, publication: publication)
    }
}

extension AppContainer: UserSettingsNavigationControllerFactory {
    func make() -> UserSettingsNavigationController {
        let controller = storyboards.settings.instantiateViewController(withIdentifier: "UserSettingsNavigationController") as! UserSettingsNavigationController
        controller.fontSelectionViewController =
            (storyboards.settings.instantiateViewController(withIdentifier: "FontSelectionViewController") as! FontSelectionViewController)
        controller.advancedSettingsViewController =
            (storyboards.settings.instantiateViewController(withIdentifier: "AdvancedSettingsViewController") as! AdvancedSettingsViewController)
        return controller
    }
}

extension AppContainer: OutlineTableViewControllerFactory {
    func make(tableOfContents: [Link], publicationType: OutlineTableViewController.PublicationType) -> OutlineTableViewController {
        let controller = storyboards.main.instantiateViewController(withIdentifier: "OutlineTableViewController") as! OutlineTableViewController
        controller.publicationType = publicationType
        controller.tableOfContents = tableOfContents
        return controller
    }
}

extension AppContainer: OPDSRootTableViewControllerFactory {
    func make(feedURL: URL, indexPath: IndexPath?) -> OPDSRootTableViewController {
        let controller = storyboards.opds.instantiateViewController(withIdentifier: "opdsRootViewController") as! OPDSRootTableViewController
        controller.container = self
        controller.originalFeedURL = feedURL
        controller.originalFeedIndexPath = nil
        return controller
    }
}

extension AppContainer: OPDSPublicationInfoViewControllerFactory {
    func make(publication: Publication) -> OPDSPublicationInfoViewController {
        let controller = storyboards.opds.instantiateViewController(withIdentifier: "opdsPublicationInfoViewController") as! OPDSPublicationInfoViewController
        controller.publication = publication
        controller.library = library
        return controller
    }
}

extension AppContainer: OPDSFacetViewControllerFactory {
    func make(feed: Feed) -> OPDSFacetViewController {
        let controller = storyboards.opds.instantiateViewController(withIdentifier: "opdsFacetViewController") as! OPDSFacetViewController
        controller.feed = feed
        return controller
    }
}

extension AppContainer: DrmManagementTableViewControllerFactory {
    func make(drm: DRM) -> DrmManagementTableViewController {
        let controller =
            storyboards.drm.instantiateViewController(withIdentifier: "DrmManagementTableViewController") as! DrmManagementTableViewController
        controller.viewModel = DRMViewModel.make(drm: drm)
        return controller
    }
}
