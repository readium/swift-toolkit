//
//  PDFNavigatorViewController.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 05.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import PDFKit
import R2Shared


public protocol PDFNavigatorDelegate: AnyObject {
    
    /// Called when the user tapped the publication, and it didn't trigger any internal action.
    func navigatorDidTap(_ navigator: Navigator)
    
    /// Called when the current position in the publication changed. You should save the locator here to restore the last read page.
    func navigator(_ navigator: Navigator, didGoTo locator: Locator)
    
    /// Called when an error must be reported to the user.
    func navigator(_ navigator: Navigator, presentError error: NavigatorError)
    
    /// Called when the user tapped an external URL. The default implementation opens the URL with the default browser.
    func navigator(_ navigator: Navigator, presentExternalURL url: URL)
    
}


public extension PDFNavigatorDelegate {
    
    func navigator(_ navigator: Navigator, presentExternalURL url: URL) {
        UIApplication.shared.openURL(url)
    }
    
    func navigatorDidTap(_ navigator: Navigator) {
        // Optional
    }
    
}


/// A view controller used to render a PDF `Publication`.
@available(iOS 11.0, *)
open class PDFNavigatorViewController: UIViewController, Loggable {
    
    enum Error: Swift.Error {
        case openPDFFailed
    }
    
    public let publication: Publication
    public weak var delegate: PDFNavigatorDelegate?
    
    public private(set) var pdfView: PDFView!
    private let startLocator: Locator?
    private var currentLink: Link?

    public init(publication: Publication, startLocator: Locator? = nil) {
        self.publication = publication
        self.startLocator = startLocator
        
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
        
        pdfView = PDFView(frame: view.bounds)
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pdfView)
        
        setupPDFView()

        NotificationCenter.default.addObserver(self, selector: #selector(pageDidChange), name: Notification.Name.PDFViewPageChanged, object: pdfView)
        
        let locator = startLocator ?? Locator(href: publication.readingOrder[0].href, type: "application/pdf")
        go(to: locator)
    }
    
    /// Override to customize the PDFView.
    open func setupPDFView() {
        pdfView.displaysAsBook = true
        pdfView.autoScales = true
        pdfView.maxScaleFactor = 4.0
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
    }
    
    @objc private func didTap() {
        delegate?.navigatorDidTap(self)
    }
    
    @objc private func pageDidChange() {
        guard let locator = currentLocator else {
            return
        }
        delegate?.navigator(self, didGoTo: locator)
    }

    func go(to link: Link, pageNumber: Int? = nil) -> Bool {
        if currentLink != link {
            guard let url = publication.url(to: link),
                let document = PDFDocument(url: url) else
            {
                log(.error, "Can't open PDF document at \(link)")
                return false
            }
    
            currentLink = link
            pdfView.document = document
        }
        
        guard let document = pdfView.document else {
            return false
        }
        if let pageNumber = pageNumber {
            let safePageNumber = min(max(0, pageNumber - 1), document.pageCount - 1)
            guard let page = document.page(at: safePageNumber) else {
                return false
            }
            pdfView.go(to: page)
        }
        return true
    }
    
}

@available(iOS 11.0, *)
extension PDFNavigatorViewController: Navigator {
    
    public var currentLocator: Locator? {
        // FIXME: take into account multiple PDF in a LCPDF publication
        guard let link = currentLink,
            let pageNumber = pdfView.currentPage?.pageRef?.pageNumber else
        {
            return nil
        }
        
        return Locator(
            href: link.href,
            type: "application/pdf",
            title: link.title,
            locations: Locations(
                fragment: "page=\(pageNumber)",
                position: pageNumber
            )
        )
    }
    
    public func go(to locator: Locator, animated: Bool, completion: @escaping () -> Void) -> Bool {
        guard let link = publication.readingOrder.first(withHref: locator.href) else {
            return false
        }
        
        let pageNumber: Int? = {
            if let fragment = locator.locations?.fragment {
                // https://tools.ietf.org/rfc/rfc3778
                let optionalPageParam = fragment
                    .components(separatedBy: CharacterSet(charactersIn: "&#"))
                    .map { $0.components(separatedBy: "=") }
                    .first { $0.first == "page" && $0.count == 2 }
                if let pageParam = optionalPageParam, let pageNumber = Int(pageParam[1]) {
                    return pageNumber
                }
            }
            
            // FIXME: take into account multiple PDF in a LCPDF publication
            return locator.locations?.position
        }()
        
        return go(to: link, pageNumber: pageNumber)
    }

}
