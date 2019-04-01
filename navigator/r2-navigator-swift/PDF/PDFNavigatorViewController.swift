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

    public init(publication: Publication, startLocator: Locator? = nil) {
        self.publication = publication
        self.startLocator = startLocator
        
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        pdfView = PDFView(frame: view.bounds)
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pdfView)
        
        setupPDFView()
        
        if let link = publication.readingOrder.first {
            load(link)
        }
    }
    
    /// Override to customize the PDFView.
    open func setupPDFView() {
        pdfView.displaysAsBook = true
        pdfView.autoScales = true
        pdfView.maxScaleFactor = 4.0
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
    }

    /// Loads `Link` resource into the PDF view.
    func load(_ link: Link) {
        guard let url = publication.url(to: link),
            let document = PDFDocument(url: url) else
        {
            log(.error, "Can't open PDF document at \(link)")
            return
        }
        
        pdfView.document = document
    }
    
}
