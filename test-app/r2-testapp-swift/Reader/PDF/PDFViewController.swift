//
//  PDFViewController.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 07.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SafariServices
import UIKit
import R2Navigator
import R2Shared


@available(iOS 11.0, *)
final class PDFViewController: ReaderViewController {
    
    let navigator: PDFNavigatorViewController
    
    override init(publication: Publication, drm: DRM?) {
        navigator = PDFNavigatorViewController(publication: publication)
        super.init(publication: publication, drm: drm)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addChild(navigator)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigator.view)
        navigator.didMove(toParent: self)
    }
    
}


/// FIXME: This should be moved into ReaderViewController once the Navigator interface is generalized for all formats
extension ReaderViewController: PDFNavigatorDelegate {
    
    func navigatorDidTap(_ navigator: Navigator) {
        toggleNavigationBar()
    }
    
    func navigator(_ navigator: Navigator, didGoTo locator: Locator) {
        log(.warning, "did go to \(locator)")
        // FIXME: Save last read location
    }
    
    func navigator(_ navigator: Navigator, presentExternalURL url: URL) {
        present(SFSafariViewController(url: url), animated: true)
    }
    
    func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
        moduleDelegate?.presentError(error, from: self)
    }
    
}
