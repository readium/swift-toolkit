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
        let initialLocation: Locator? = {
            guard let publicationID = publication.metadata.identifier,
                let locatorJSON = UserDefaults.standard.string(forKey: "\(publicationID)-locator") else {
                return nil
            }
            return (try? Locator(jsonString: locatorJSON)) as? Locator
        }()
    
        navigator = PDFNavigatorViewController(publication: publication, license: drm?.license, initialLocation: initialLocation)
        
        super.init(publication: publication, drm: drm)
        
        navigator.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addChild(navigator)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigator.view)
        navigator.didMove(toParent: self)
    }
    
    override var currentBookmark: Bookmark? {
        guard let publicationID = publication.metadata.identifier,
            let locator = navigator.currentLocation,
            let resourceIndex = publication.readingOrder.firstIndex(withHref: locator.href) else
        {
            return nil
        }

        return Bookmark(
            publicationID: publicationID,
            resourceIndex: resourceIndex,
            locator: locator
        )
    }
    
    override func goTo(item: String) {
        // Extracts fragment, eg. /file.pdf#page=10
        let components = item
            .split(separator: "#", maxSplits: 1)
            .map { String($0) }
        let href = components.first ?? item
        let fragment = components.count > 1 ? components[1] : nil
        let locator = Locator(
            href: href,
            type: "application/pdf",
            locations: Locations(fragment: fragment)
        )
        navigator.go(to: locator)
    }
    
    override func goTo(bookmark: Bookmark) {
        navigator.go(to: bookmark.locator)
    }
    
}


/// FIXME: This should be moved into ReaderViewController once the Navigator interface is generalized for all formats
@available(iOS 11.0, *)
extension PDFViewController: PDFNavigatorDelegate {
    
    func navigator(_ navigator: Navigator, didTapAt point: CGPoint, in view: UIView) {
        // Skips to previous/next pages if the tap is on the content edges.
        let thresholdRange = 0...(0.2 * view.bounds.width)
        var moved = false
        if thresholdRange ~= point.x {
            moved = navigator.goBackward(animated: true)
        } else if thresholdRange ~= (view.bounds.maxX - point.x) {
            moved = navigator.goForward(animated: true)
        }
        
        if !moved {
            toggleNavigationBar()
        }
    }
    
    func navigator(_ navigator: Navigator, didGoTo locator: Locator) {
        guard let publicationID = navigator.publication.metadata.identifier else {
            return
        }
        UserDefaults.standard.set(locator.jsonString, forKey: "\(publicationID)-locator")
    }
    
    func navigator(_ navigator: Navigator, presentExternalURL url: URL) {
        present(SFSafariViewController(url: url), animated: true)
    }
    
    func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
        moduleDelegate?.presentError(error, from: self)
    }
    
}
