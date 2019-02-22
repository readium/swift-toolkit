//
//  AppModule.swift
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


/// Base module delegate, that sub-modules' delegate can extend.
/// Provides basic shared functionalities.
protocol ModuleDelegate: AnyObject {
    func presentAlert(_ title: String, message: String, from viewController: UIViewController)
    func presentError(_ error: Error?, from viewController: UIViewController)
}


/// Main application module, it:
/// - owns the sub-modules (library, reader, etc.)
/// - orchestrates the communication between its sub-modules, through the modules' delegates.
final class AppModule {
    
    // App modules
    var library: LibraryModuleAPI! = nil
    var reader: ReaderModuleAPI! = nil
    var opds: OPDSModuleAPI! = nil

    init() throws {
        library = try LibraryModule(delegate: self)
        reader = ReaderModule(delegate: self)
        opds = OPDSModule(delegate: self)
        
        // Set Readium 2's logging minimum level.
        R2EnableLog(withMinimumSeverityLevel: .debug)
    }
    
    private(set) lazy var aboutViewController: UIViewController = {
        let storyboard = UIStoryboard(name: "App", bundle: nil)
        let aboutViewController = storyboard.instantiateViewController(withIdentifier: "AboutTableViewController") as! AboutTableViewController
        return UINavigationController(rootViewController: aboutViewController)
    }()

}


extension AppModule: ModuleDelegate {

    func presentAlert(_ title: String, message: String, from viewController: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: "OK", style: .cancel)
        alert.addAction(dismissButton)
        viewController.present(alert, animated: true)
    }
    
    func presentError(_ error: Error?, from viewController: UIViewController) {
        guard let error = error else { return }
        presentAlert("Error", message: error.localizedDescription, from: viewController)
    }

}


extension AppModule: LibraryModuleDelegate {
    
    func libraryDidSelectPublication(_ publication: Publication, completion: @escaping () -> Void) {
        reader.presentPublication(publication: publication, in: library.rootViewController, completion: completion)
    }

}


extension AppModule: ReaderModuleDelegate {
    
    func readerLoadDRM(for publication: Publication, completion: @escaping (Result<DRM?>) -> Void) {
        library.loadDRM(for: publication, completion: completion)
    }
    
}


extension AppModule: OPDSModuleDelegate {
    
    func opdsDidDownloadPublication(at url: URL, from downloadTask: URLSessionDownloadTask) -> Bool {
        return library.addPublication(at: url, from: downloadTask)
    }
    
}
