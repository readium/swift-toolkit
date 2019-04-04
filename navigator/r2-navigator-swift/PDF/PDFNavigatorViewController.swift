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

    private let initialLocation: Locator?
    
    /// Reading order index of the current resource.
    private var currentResourceIndex: Int?
    
    /// Positions list indexed by reading order.
    private let positionListByResourceIndex: [[Locator]]

    fileprivate let editingActions: EditingActionsController

    public init(publication: Publication, license: DRMLicense?, initialLocation: Locator? = nil, editingActions: [EditingAction] = EditingAction.defaultActions) {
        self.publication = publication
        self.initialLocation = initialLocation
        self.editingActions = EditingActionsController(actions: editingActions, license: license)
        
        // FIXME: This should be cached, to avoid opening all the documents of the readingOrder
        positionListByResourceIndex = {
            var lastPositionOfPreviousResource = 0
            return publication.readingOrder.map { link in
                guard let url = publication.url(to: link),
                    let document = PDFDocument(url: url) else
                {
                    PDFNavigatorViewController.log(.warning, "Can't open PDF document at \(link)")
                    return []
                }
                
                let pageCount = max(document.pageCount, 1)  // safe-guard to avoid dividing by 0
                let positionList = (1...pageCount).map { pageNumber in
                    Locator(
                        href: link.href,
                        type: link.type ?? "application/pdf",
                        // FIXME: title by finding the containing TOC item
                        title: nil,
                        locations: Locations(
                            fragment: "page=\(pageNumber)",
                            progression: Double(pageNumber) / Double(pageCount),
                            position: lastPositionOfPreviousResource + pageNumber
                        )
                    )
                }
                lastPositionOfPreviousResource += pageCount
                return positionList
            }
        }()
        positionList = positionListByResourceIndex.flatMap { $0 }

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
        
        if let locator = initialLocation ?? positionList.first {
            go(to: locator)
        }
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
        guard let locator = currentLocation else {
            return
        }
        delegate?.navigator(self, didGoTo: locator)
    }

    private func go(to link: Link, pageNumber: Int? = nil) -> Bool {
        guard let index = publication.readingOrder.firstIndex(of: link) else {
            return false
        }
        
        if currentResourceIndex != index {
            guard let url = publication.url(to: link),
                let document = PDFDocument(url: url) else
            {
                log(.error, "Can't open PDF document at \(link)")
                return false
            }
    
            currentResourceIndex = index
            pdfView.document = document
            updateScaleFactors()
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
    
    private func pageNumber(for locator: Locator, at resourceIndex: Int) -> Int? {
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
        
        if let position = locator.locations?.position,
            let firstPosition = positionListByResourceIndex[resourceIndex].first?.locations?.position {
            return position - firstPosition + 1
        }
        
        return nil
    }
    
    
    // MARK: - Navigator

    public var currentLocation: Locator? {
        guard let currentResourceIndex = self.currentResourceIndex,
            let pageNumber = pdfView.currentPage?.pageRef?.pageNumber else
        {
            return nil
        }
        let positionList = positionListByResourceIndex[currentResourceIndex]
        guard 1...positionList.count ~= pageNumber else {
            return nil
        }
        return positionList[pageNumber - 1]
    }

    public let positionList: [Locator]

    public func go(to locator: Locator, animated: Bool, completion: @escaping () -> Void) -> Bool {
        guard let index = publication.readingOrder.firstIndex(withHref: locator.href) else {
            return false
        }

        return go(
            to: publication.readingOrder[index],
            pageNumber: pageNumber(for: locator, at: index)
        )
    }

}


@available(iOS 11.0, *)
extension PDFNavigatorViewController: EditingActionsControllerDelegate {
    
    func editingActionsDidPreventCopy(_ editingActions: EditingActionsController) {
        delegate?.navigator(self, presentError: .copyForbidden)
    }
    
}
