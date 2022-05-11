//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit
import UIKit
import R2Shared


public protocol PDFNavigatorDelegate: VisualNavigatorDelegate, SelectableNavigatorDelegate { }


/// A view controller used to render a PDF `Publication`.
@available(iOS 11.0, *)
open class PDFNavigatorViewController: UIViewController, VisualNavigator, SelectableNavigator, Loggable {
    
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
    
    /// Holds the currently opened PDF Document.
    private let documentHolder = PDFDocumentHolder()
    
    /// Holds a reference to make sure it is not garbage-collected.
    private var tapGestureController: PDFTapGestureController?

    public init(publication: Publication, initialLocation: Locator? = nil, editingActions: [EditingAction] = EditingAction.defaultActions) {
        assert(!publication.isRestricted, "The provided publication is restricted. Check that any DRM was properly unlocked using a Content Protection.")
        
        self.publication = publication
        self.initialLocation = initialLocation
        self.editingActions = EditingActionsController(actions: editingActions, rights: publication.rights)
        
        super.init(nibName: nil, bundle: nil)
        
        self.editingActions.delegate = self
        
        // Wraps the PDF factories of publication services to return the currently opened document
        // held in `documentHolder` when relevant. This prevents opening several times the same
        // document, which is useful in particular with `LCPDFPositionService`.
        for service in publication.findServices(PDFPublicationService.self) {
            service.pdfFactory = CompositePDFDocumentFactory(factories: [
                documentHolder, service.pdfFactory
            ])
        }
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

        editingActions.updateSharedMenuController()

        if let locator = initialLocation {
            go(to: locator, isJump: false)
        } else if let link = publication.readingOrder.first {
            go(to: link, pageNumber: 0, isJump: false)
        } else {
            log(.error, "No initial location and empty reading order")
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

    @discardableResult
    private func go(to locator: Locator, isJump: Bool, completion: @escaping () -> Void = {}) -> Bool {
        guard let index = publication.readingOrder.firstIndex(withHREF: locator.href) else {
            return false
        }

        return go(
            to: publication.readingOrder[index],
            pageNumber: pageNumber(for: locator),
            isJump: isJump,
            completion: completion
        )
    }

    @discardableResult
    private func go(to link: Link, pageNumber: Int?, isJump: Bool, completion: @escaping () -> Void = {}) -> Bool {
        guard let index = publication.readingOrder.firstIndex(of: link) else {
            return false
        }
        
        if currentResourceIndex != index {
            guard let url = link.url(relativeTo: publication.baseURL),
                let document = PDFDocument(url: url) else
            {
                log(.error, "Can't open PDF document at \(link)")
                return false
            }
            
            currentResourceIndex = index
            documentHolder.set(document, at: link.href)
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
        if isJump, let delegate = delegate, let location = currentPosition {
            delegate.navigator(self, didJumpTo: location)
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
        
        guard var position = locator.locations.position else {
            return nil
        }
        
        if
            publication.readingOrder.count > 1,
            let index = publication.readingOrder.firstIndex(withHREF: locator.href),
            let firstPosition = publication.positionsByReadingOrder[index].first?.locations.position
        {
            position = position - firstPosition + 1
        }
        
        return position
    }
    
    /// Returns the position locator of the current page.
    private var currentPosition: Locator? {
        guard let currentResourceIndex = self.currentResourceIndex,
            let pageNumber = pdfView.currentPage?.pageRef?.pageNumber,
            publication.readingOrder.indices.contains(currentResourceIndex) else
        {
            return nil
        }
        let positions = publication.positionsByReadingOrder[currentResourceIndex]
        guard positions.count > 0, 1...positions.count ~= pageNumber else {
            return nil
        }
        
        return positions[pageNumber - 1]
    }
    
    // MARK: – SelectableNavigator

    public var currentSelection: Selection? { editingActions.selection }

    public func clearSelection() {
        pdfView.clearSelection()
    }


    // MARK: - User Selection

    @objc func selectionDidChange(_ note: Notification) {
        guard
            let locator = currentLocation,
            let selection = pdfView.currentSelection,
            let text = selection.string,
            let page = selection.pages.first
        else {
            editingActions.selection = nil
            return
        }
        
        editingActions.selection = Selection(
            locator: locator.copy(text: { $0.highlight = text }),
            frame: pdfView.convert(selection.bounds(for: page), from: page)
                // Makes it slightly bigger to have more room when displaying a popover.
                .insetBy(dx: -8, dy: -8)
        )
    }

    @objc private func shareSelection(_ sender: Any?) {
        guard let shareViewController = editingActions.makeShareViewController(from: pdfView) else {
            return
        }
        present(shareViewController, animated: true)
    }
    
    
    // MARK: - Navigator

    public var readingProgression: ReadingProgression {
        publication.metadata.effectiveReadingProgression
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
        return go(to: locator, isJump: true, completion: completion)
    }
    
    public func go(to link: Link, animated: Bool, completion: @escaping () -> Void) -> Bool {
        return go(to: link, pageNumber: nil, isJump: true, completion: completion)
    }
    
    public func goForward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        if pdfView.canGoToNextPage {
            pdfView.goToNextPage(nil)
            DispatchQueue.main.async(execute: completion)
            return true
        }
        
        let nextIndex = (currentResourceIndex ?? -1) + 1
        guard publication.readingOrder.indices.contains(nextIndex),
            let nextPosition = publication.positionsByReadingOrder[nextIndex].first else
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
            let previousPosition = publication.positionsByReadingOrder[previousIndex].first else
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

    func editingActions(_ editingActions: EditingActionsController, shouldShowMenuForSelection selection: Selection) -> Bool {
        return delegate?.navigator(self, shouldShowMenuForSelection: selection) ?? true
    }

    func editingActions(_ editingActions: EditingActionsController, canPerformAction action: EditingAction, for selection: Selection) -> Bool {
        return delegate?.navigator(self, canPerformAction: action, for: selection) ?? true
    }
}

@available(iOS 11.0, *)
extension PDFNavigatorViewController: UIGestureRecognizerDelegate {

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
}


// MARK: - Deprecated

@available(iOS 11.0, *)
extension PDFNavigatorViewController {
    
    /// This initializer is deprecated.
    /// `license` is not needed anymore.
    @available(*, unavailable, renamed: "init(publication:initialLocation:editingActions:)")
    public convenience init(publication: Publication, license: DRMLicense?, initialLocation: Locator? = nil, editingActions: [EditingAction] = EditingAction.defaultActions) {
        self.init(publication: publication, initialLocation: initialLocation, editingActions: editingActions)
    }
    
}
