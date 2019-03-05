//
//  ReaderModule.swift
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


/// The ReaderModule handles the presentation of publications to be read by the user.
/// It contains sub-modules implementing ReaderFormatModule to handle each format of publication (eg. CBZ, EPUB).
protocol ReaderModuleAPI {
    
    var delegate: ReaderModuleDelegate? { get }
    
    /// Presents the given publication to the user, inside the given navigation controller.
    /// - Parameter completion: Called once the publication is presented, or if an error occured.
    func presentPublication(publication: Publication, in navigationController: UINavigationController, completion: @escaping () -> Void)
    
}

protocol ReaderModuleDelegate: ModuleDelegate {
    
    /// Called when the reader needs to load the R2 DRM object for the given publication.
    func readerLoadDRM(for publication: Publication, completion: @escaping (CancellableResult<DRM?>) -> Void)
    
}


final class ReaderModule: ReaderModuleAPI {
    
    weak var delegate: ReaderModuleDelegate?
    
    /// Sub-modules to handle different publication formats (eg. EPUB, CBZ)
    var formatModules: [ReaderFormatModule] = []
    
    private let factory = ReaderFactory()
    
    init(delegate: ReaderModuleDelegate?) {
        self.delegate = delegate
        
        formatModules = [
            CBZModule(delegate: self),
            EPUBModule(delegate: self),
            PDFModule(delegate: self),
        ]
    }
    
    func presentPublication(publication: Publication, in navigationController: UINavigationController, completion: @escaping () -> Void) {
        guard let delegate = delegate else {
            fatalError("Reader delegate not set")
        }
        
        func present(_ viewController: UIViewController) {
            let backItem = UIBarButtonItem()
            backItem.title = ""
            viewController.navigationItem.backBarButtonItem = backItem
            viewController.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(viewController, animated: true)
        }
        
        delegate.readerLoadDRM(for: publication) { result in
            switch result {
            case .failure(let error):
                delegate.presentError(error, from: navigationController)
                completion()
                
            case .success(let drm):
                // Get publication type
                let publicationType = PublicationType(rawString: publication.internalData["type"])
    
                guard let module = self.formatModules.first(where:{ $0.publicationType.contains(publicationType) }) else {
                    delegate.presentError(AppError.message("Unsupported format"), from: navigationController)
                    completion()
                    return
                }
                
                do {
                    let readerViewController = try module.makeReaderViewController(for: publication, drm: drm)
                    present(readerViewController)
                } catch {
                    delegate.presentError(error, from: navigationController)
                }
                
                completion()
                
            case .cancelled:
                completion()
            }
        }
    }
    
}


extension ReaderModule: ReaderFormatModuleDelegate {

    func presentDRM(_ drm: DRM, from viewController: UIViewController) {
        let drmViewController: DrmManagementTableViewController = factory.make(drm: drm)
        let backItem = UIBarButtonItem()
        backItem.title = ""
        drmViewController.navigationItem.backBarButtonItem = backItem
        viewController.navigationController?.pushViewController(drmViewController, animated: true)
    }
    
    func presentOutline(_ links: [Link], type: PublicationType, delegate: OutlineTableViewControllerDelegate?, from viewController: UIViewController) {
        let outlineTableVC: OutlineTableViewController = factory.make(tableOfContents: links, publicationType: type)
        outlineTableVC.delegate = delegate
        viewController.present(UINavigationController(rootViewController: outlineTableVC), animated: true)
    }
    
    func presentAlert(_ title: String, message: String, from viewController: UIViewController) {
        delegate?.presentAlert(title, message: message, from: viewController)
    }
    
    func presentError(_ error: Error?, from viewController: UIViewController) {
        delegate?.presentError(error, from: viewController)
    }

}
