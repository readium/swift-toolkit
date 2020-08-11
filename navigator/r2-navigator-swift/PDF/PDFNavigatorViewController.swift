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


public protocol PDFNavigatorDelegate: VisualNavigatorDelegate { }


/// A view controller used to render a PDF `Publication`.
@available(iOS 11.0, *)
open class PDFNavigatorViewController: UIViewController, VisualNavigator, Loggable {
    
    enum Error: Swift.Error {
        case openPDFFailed
    }
    
    /// Whether the pages is always scaled to fit the screen, unless the user zoomed in.
    public var scalesDocumentToFit = true
    
    public weak var delegate: PDFNavigatorDelegate?
    public private(set) var pdfView: PDFDocumentView!

    private let publication: Publication
    private let initialLocation: Locator?
    private let editingActions: EditingActionsController
    /// Reading order index of the current resource.
    private var currentResourceIndex: Int?
    
    // Holds a reference to make sure it is not garbage-collected.
    private var tapGestureController: PDFTapGestureController?

    public init(publication: Publication, license: DRMLicense? = nil, initialLocation: Locator? = nil, editingActions: [EditingAction] = EditingAction.defaultActions) {
        self.publication = publication
        self.initialLocation = initialLocation
        self.editingActions = EditingActionsController(actions: editingActions, license: license)
        
        super.init(nibName: nil, bundle: nil)
        
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
        
        pdfView = PDFDocumentView(frame: view.bounds, editingActions: editingActions)
        pdfView.delegate = self
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pdfView)
        
        tapGestureController = PDFTapGestureController(pdfView: pdfView, target: self, action: #selector(didTap))

        setupPDFView()

        NotificationCenter.default.addObserver(self, selector: #selector(pageDidChange), name: .PDFViewPageChanged, object: pdfView)
        NotificationCenter.default.addObserver(self, selector: #selector(selectionDidChange), name: .PDFViewSelectionChanged, object: pdfView)
        
        UIMenuController.shared.menuItems = [
            UIMenuItem(
                title: R2NavigatorLocalizedString("EditingAction.share"),
                action: #selector(shareSelection)
            )
        ]
        
        if let locator = initialLocation ?? publication.positions.first {
            go(to: locator)
        }
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Hack to layout properly the first page when opening the PDF.
        if scalesDocumentToFit {
            pdfView.scaleFactor = pdfView.minScaleFactor
            if let page = pdfView.currentPage {
                pdfView.go(to: page.bounds(for: pdfView.displayBox), on: page)
            }
        }
    }

    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if scalesDocumentToFit {
            // Makes sure that the PDF is always properly scaled down when rotating the screen, if the user didn't zoom in.
            let isAtMinScaleFactor = (pdfView.scaleFactor == pdfView.minScaleFactor)
            coordinator.animate(alongsideTransition: { _ in
                self.updateScaleFactors()
                if isAtMinScaleFactor {
                    self.pdfView.scaleFactor = self.pdfView.minScaleFactor
                }
            })
        }
    }

    /// Override to customize the PDFDocumentView.
    open func setupPDFView() {
        pdfView.displaysAsBook = true
        pdfView.autoScales = !scalesDocumentToFit
    }
    
    @objc private func didTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        delegate?.navigator(self, didTapAt: point)
    }
    
    @objc private func pageDidChange() {
        guard let locator = currentPosition else {
            return
        }
        delegate?.navigator(self, locationDidChange: locator)
    }

    private func go(to link: Link, pageNumber: Int? = nil, completion: @escaping () -> Void) -> Bool {
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
        DispatchQueue.main.async(execute: completion)
        return true
    }
    
    private func updateScaleFactors() {
        guard scalesDocumentToFit else {
            return
        }
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.maxScaleFactor = 4.0
    }
    
    private func pageNumber(for locator: Locator) -> Int? {
        for fragment in locator.locations.fragments {
            // https://tools.ietf.org/rfc/rfc3778
            let optionalPageParam = fragment
                .components(separatedBy: CharacterSet(charactersIn: "&#"))
                .map { $0.components(separatedBy: "=") }
                .first { $0.first == "page" && $0.count == 2 }
            if let pageParam = optionalPageParam, let pageNumber = Int(pageParam[1]) {
                return pageNumber
            }
        }
        
        if let position = locator.locations.position,
            let firstPosition = publication.positionsByResource[locator.href]?.first?.locations.position {
            return position - firstPosition + 1
        }
        
        return nil
    }
    
    /// Returns the position locator of the current page.
    private var currentPosition: Locator? {
        guard let currentResourceIndex = self.currentResourceIndex,
            let pageNumber = pdfView.currentPage?.pageRef?.pageNumber,
            publication.readingOrder.indices.contains(currentResourceIndex) else
        {
            return nil
        }
        let href = publication.readingOrder[currentResourceIndex].href
        guard let positionList = publication.positionsByResource[href],
            1...positionList.count ~= pageNumber else
        {
            return nil
        }
        
        return positionList[pageNumber - 1]
    }
    
    
    // MARK: - User Selection

    @objc func selectionDidChange(_ note: Notification) {
        guard let selection = pdfView.currentSelection,
            let text = selection.string,
            let page = selection.pages.first else
        {
            editingActions.selectionDidChange(nil)
            return
        }
        
        let frame = pdfView.convert(selection.bounds(for: page), from: page)
            // Makes it slightly bigger to have more room when displaying a popover.
            .insetBy(dx: -8, dy: -8)
        editingActions.selectionDidChange((text: text, frame: frame))
    }

    @objc private func shareSelection(_ sender: Any?) {
        guard let shareViewController = editingActions.makeShareViewController(from: pdfView) else {
            return
        }
        present(shareViewController, animated: true)
    }
    
    
    // MARK: - Navigator

    public var readingProgression: ReadingProgression {
        return publication.contentLayout.readingProgression
    }
    
    public var currentLocation: Locator? {
        currentPosition?.copy(text: { [weak self] in
            /// Adds some context for bookmarking
            if let page = self?.pdfView.currentPage {
                $0 = .init(highlight: String(page.string?.prefix(280) ?? ""))
            }
        })
    }

    public func go(to locator: Locator, animated: Bool, completion: @escaping () -> Void) -> Bool {
        guard let index = publication.readingOrder.firstIndex(withHref: locator.href) else {
            return false
        }

        return go(
            to: publication.readingOrder[index],
            pageNumber: pageNumber(for: locator),
            completion: completion
        )
    }
    
    public func go(to link: Link, animated: Bool, completion: @escaping () -> Void) -> Bool {
        return go(to: Locator(link: link), animated: animated, completion: completion)
    }
    
    public func goForward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        if pdfView.canGoToNextPage {
            pdfView.goToNextPage(nil)
            DispatchQueue.main.async(execute: completion)
            return true
        }
        
        let nextIndex = (currentResourceIndex ?? -1) + 1
        guard publication.readingOrder.indices.contains(nextIndex),
            let nextPosition = publication.positionsByResource[publication.readingOrder[nextIndex].href]?.first else
        {
            return false
        }
        return go(to: nextPosition, animated: animated, completion: completion)
    }
    
    public func goBackward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        if pdfView.canGoToPreviousPage {
            pdfView.goToPreviousPage(nil)
            DispatchQueue.main.async(execute: completion)
            return true
        }
        
        let previousIndex = (currentResourceIndex ?? 0) - 1
        guard publication.readingOrder.indices.contains(previousIndex),
            let previousPosition = publication.positionsByResource[publication.readingOrder[previousIndex].href]?.first else
        {
            return false
        }
        return go(to: previousPosition, animated: animated, completion: completion)
    }

}

@available(iOS 11.0, *)
extension PDFNavigatorViewController: PDFViewDelegate {
    
    public func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
        log(.debug, "Click URL: \(url)")
        
        let url = url.addingSchemeIfMissing("http")
        delegate?.navigator(self, presentExternalURL: url)
    }
    
    public func pdfViewParentViewController() -> UIViewController {
        return self
    }

}

@available(iOS 11.0, *)
extension PDFNavigatorViewController: EditingActionsControllerDelegate {
    
    func editingActionsDidPreventCopy(_ editingActions: EditingActionsController) {
        delegate?.navigator(self, presentError: .copyForbidden)
    }
    
}
