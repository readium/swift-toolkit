//
//  AppCoordinator.swift
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


protocol AppCoordinatorFactory {
    func make () -> AppCoordinator
}

final class AppCoordinator {
    
    private let library: LibraryService
    private let initialViewController: UIViewController
    
    init(library: LibraryService, initialViewController: UIViewController) {
        self.library = library
        self.initialViewController = initialViewController
    }
    
    /// Starts the reader app.
    /// You must provide a closure to present the test app's initial view controller. For example, by setting it as the main window's root view controller.
    func start(present: (UIViewController) -> Void) {
        present(initialViewController)
    }
    
    /// To be called from UIApplicationDelegate(open:options:).
    /// - Returns: Whether the URL was handled.
    func open(url: URL) -> Bool {
        guard url.isFileURL else {
            return false
        }
        return library.addPublicationToLibrary(url: url, needUIUpdate: true)
    }

}

