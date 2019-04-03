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
import PDFKit
import UIKit
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
open class PDFNavigatorViewController: UIViewController, Navigator, Loggable {
    
    enum Error: Swift.Error {
        case openPDFFailed
    }
    
    public let publication: Publication
    public weak var delegate: PDFNavigatorDelegate?
    public private(set) var pdfView: PDFDocumentView!
    
    private let initialPosition: Locator?
    
    /// Reading order link of the current resource.
    private var currentLink: Link?
    
    /// Currently rendered PDF document.
    private var document: PDFDocument? {
        didSet {
            // FIXME: take into account multiple PDF in a LCPDF publication
            if let pageCount = document?.pageCount, let href = currentLink?.href {
                positionList = (1...pageCount).map {
                    Locator(
                        href: href,
                        type: "application/pdf",
                        // FIXME: title by finding the containing TOC item
                        title: nil,
                        locations: Locations(
                            fragment: "page=\($0)",
                            position: $0
                        )
                    )
                }
            } else {
                positionList = []
            }
            
            pdfView.document = document
            updateScaleFactors()
        }
    }
    
    fileprivate let editingActions: EditingActionsController

    public init(publication: Publication, license: DRMLicense?, initialPosition: Locator? = nil, editingActions: [EditingAction] = EditingAction.defaultActions) {
        self.publication = publication
        self.initialPosition = initialPosition
        self.editingActions = EditingActionsController(actions: editingActions, license: license)
        
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
        self.editingActions.delegate = self
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
        
        pdfView = PDFDocumentView(frame: view.bounds, editingActions: editingActions)
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pdfView)
        
        setupPDFView()

        NotificationCenter.default.addObserver(self, selector: #selector(pageDidChange), name: Notification.Name.PDFViewPageChanged, object: pdfView)
        
        let locator = initialPosition ?? Locator(href: publication.readingOrder[0].href, type: "application/pdf")
        go(to: locator)
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Hack to layout properly the first page when opening the PDF in landscape.
        if let page = pdfView.currentPage {
            pdfView.go(to: page.bounds(for: pdfView.displayBox), on: page)
        }
    }
    
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Makes sure that the PDF is always properly scaled down when rotating the screen, if the user didn't zoom in.
        let isAtMinScaleFactor = (pdfView.scaleFactor == pdfView.minScaleFactor)
        coordinator.animate(alongsideTransition: { _ in
            self.updateScaleFactors()
            if isAtMinScaleFactor {
                self.pdfView.scaleFactor = self.pdfView.minScaleFactor
            }
        })
    }

    /// Override to customize the PDFDocumentView.
    open func setupPDFView() {
        pdfView.displaysAsBook = true
    }
    
    @objc private func didTap() {
        delegate?.navigatorDidTap(self)
    }
    
    @objc private func pageDidChange() {
        guard let locator = currentPosition else {
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
            self.document = document
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
    
    private func updateScaleFactors() {
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.maxScaleFactor = 4.0
    }

    
    // MARK: - Navigator

    public var currentPosition: Locator? {
        // FIXME: take into account multiple PDF in a LCPDF publication
        guard !positionList.isEmpty,
            let pageNumber = pdfView.currentPage?.pageRef?.pageNumber,
            1...positionList.count ~= pageNumber else {
            return nil
        }
        return positionList[pageNumber - 1]
    }
    
    public private(set) var positionList: [Locator] = []

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


@available(iOS 11.0, *)
extension PDFNavigatorViewController: EditingActionsControllerDelegate {
    
    func editingActionsDidPreventCopy(_ editingActions: EditingActionsController) {
        delegate?.navigator(self, presentError: .copyForbidden)
    }
    
}
