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
open class PDFNavigatorViewController: UIViewController, VisualNavigator, PresentableNavigator, Loggable {
    
    enum Error: Swift.Error {
        case openPDFFailed
    }
    
    public struct Configuration {
        /// Initial presentation settings.
        public var settings: PresentationValues
        /// Default presentation settings.
        public var defaultSettings: PresentationValues
        
        public init(
            settings: PresentationValues = PresentationValues(),
            defaultSettings: PresentationValues = PresentationValues()
        ) {
            self.settings = settings
            self.defaultSettings = defaultSettings
        }
    }
    
    /// Whether the pages is always scaled to fit the screen, unless the user zoomed in.
    public var scalesDocumentToFit = true
    
    public weak var delegate: PDFNavigatorDelegate?
    public private(set) var pdfView: PDFDocumentView?

    private let publication: Publication
    private let initialLocation: Locator?
    private let editingActions: EditingActionsController
    /// Reading order index of the current resource.
    private var currentResourceIndex: Int?
    
    /// Holds the currently opened PDF Document.
    private let documentHolder = PDFDocumentHolder()
    
    /// Holds a reference to make sure it is not garbage-collected.
    private var tapGestureController: PDFTapGestureController?
    
    private let config: Configuration

    public init(publication: Publication, initialLocation: Locator? = nil, editingActions: [EditingAction] = EditingAction.defaultActions, config: Configuration = .init()) {
        assert(!publication.isRestricted, "The provided publication is restricted. Check that any DRM was properly unlocked using a Content Protection.")
        
        self.publication = publication
        self.initialLocation = initialLocation
        self.editingActions = EditingActionsController(actions: editingActions, rights: publication.rights)
        self.config = config
        
        self._presentation = MutableObservableVariable(PDFPresentation(
            publication: publication,
            settings: config.settings,
            defaults: config.defaultSettings,
            fallback: nil
        ))
        
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
        
        resetPDFView(presentation: presentation.get(), at: initialLocation)

        editingActions.updateSharedMenuController()
    }
    
    func resetPDFView(presentation: Presentation, at locator: Locator?) {
        if let pdfView = pdfView {
            pdfView.removeFromSuperview()
            NotificationCenter.default.removeObserver(self)
        }
        
        currentResourceIndex = nil
        let pdfView = PDFDocumentView(frame: view.bounds, editingActions: editingActions)
        self.pdfView = pdfView
        pdfView.delegate = self
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pdfView)
        
        tapGestureController = PDFTapGestureController(pdfView: pdfView, target: self, action: #selector(didTap))

        apply(presentation: presentation)
        setupPDFView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(pageDidChange), name: .PDFViewPageChanged, object: pdfView)
        NotificationCenter.default.addObserver(self, selector: #selector(selectionDidChange), name: .PDFViewSelectionChanged, object: pdfView)

        if let locator = locator {
            go(to: locator)
        } else if let link = publication.readingOrder.first {
            go(to: link)
        } else {
            log(.error, "No initial location and empty reading order")
        }
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Hack to layout properly the first page when opening the PDF.
        if let pdfView = pdfView, scalesDocumentToFit {
            pdfView.scaleFactor = pdfView.minScaleFactor
            if let page = pdfView.currentPage {
                pdfView.go(to: page.bounds(for: pdfView.displayBox), on: page)
            }
        }
    }

    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if let pdfView = pdfView, scalesDocumentToFit {
            // Makes sure that the PDF is always properly scaled down when rotating the screen, if the user didn't zoom in.
            let isAtMinScaleFactor = (pdfView.scaleFactor == pdfView.minScaleFactor)
            coordinator.animate(alongsideTransition: { _ in
                self.updateScaleFactors()
                if isAtMinScaleFactor {
                    pdfView.scaleFactor = pdfView.minScaleFactor
                }
            })
        }
    }

    /// Override to customize the PDFDocumentView.
    open func setupPDFView() {
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
        guard let pdfView = pdfView, let index = publication.readingOrder.firstIndex(of: link) else {
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
            
            pdfView.displaysAsBook = (publication.readingOrder.first?.properties.page == .center)
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
        guard let pdfView = pdfView, scalesDocumentToFit else {
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
        guard
            let pdfView = pdfView,
            let currentResourceIndex = self.currentResourceIndex,
            let pageNumber = pdfView.currentPage?.pageRef?.pageNumber,
            publication.readingOrder.indices.contains(currentResourceIndex)
        else {
            return nil
        }
        let positions = publication.positionsByReadingOrder[currentResourceIndex]
        guard positions.count > 0, 1...positions.count ~= pageNumber else {
            return nil
        }
        
        return positions[pageNumber - 1]
    }
    
    
    // MARK: - User Selection

    @objc func selectionDidChange(_ note: Notification) {
        guard
            let pdfView = pdfView,
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
        guard
            let pdfView = pdfView,
            let shareViewController = editingActions.makeShareViewController(from: pdfView)
        else {
            return
        }
        present(shareViewController, animated: true)
    }
    
    
    // MARK: - Navigator
    
    public var currentLocation: Locator? {
        currentPosition?.copy(text: { [weak self] in
            /// Adds some context for bookmarking
            if let page = self?.pdfView?.currentPage {
                $0 = .init(highlight: String(page.string?.prefix(280) ?? ""))
            }
        })
    }

    public func go(to locator: Locator, animated: Bool, completion: @escaping () -> Void) -> Bool {
        guard let index = publication.readingOrder.firstIndex(withHREF: locator.href) else {
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
        if let pdfView = pdfView, pdfView.canGoToNextPage {
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
        if let pdfView = pdfView, pdfView.canGoToPreviousPage {
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
    
    // MARK: - Visual Navigator

    public var readingProgression: ReadingProgression {
        presentation.get().values.readingProgression ?? .ttb
    }
    
    // MARK: - Presentable Navigator
    
    public var presentation: ObservableVariable<Presentation> { _presentation }
    private let _presentation: MutableObservableVariable<Presentation>
    
    public func apply(presentationSettings settings: PresentationValues, completion: @escaping (Presentation) -> ()) {
        let presentation = _presentation.set { previous in
            PDFPresentation(publication: publication, settings: settings, defaults: config.defaultSettings, fallback: previous)
        }
        resetPDFView(presentation: presentation, at: currentLocation)
        DispatchQueue.main.async { completion(presentation) }
    }
    
    private func apply(presentation: Presentation) {
        guard let pdfView = pdfView else {
            return
        }
        
        let paginated = (presentation.values.overflow == .paginated)
        pdfView.usePageViewController(paginated)
        
        switch presentation.values.readingProgression ?? .ttb {
        case .ltr:
            pdfView.displayDirection = .horizontal
            pdfView.displaysRTL = false
        case .rtl:
            pdfView.displayDirection = .horizontal
            pdfView.displaysRTL = true
        case .btt:
            pdfView.displayDirection = .vertical
            pdfView.displaysRTL = true
        default:
            pdfView.displayDirection = .vertical
            pdfView.displaysRTL = false
        }
        
        pdfView.autoScales = !scalesDocumentToFit
    }
    
    private struct PDFPresentation: Presentation {
        
        private let overflows: [PresentationOverflow] = [ .paginated, .scrolled ]
        private let readingProgressions: [ReadingProgression] = [ .ltr, .rtl, .ttb, .btt ]
        
        let values: PresentationValues
        
        init(publication: Publication, settings: PresentationValues, defaults: PresentationValues, fallback: Presentation?) {
            values = PresentationValues(
                overflow: overflows.firstIn(settings.overflow, fallback?.values.overflow.takeIf { _ in settings.overflow != nil })
                    ?? overflows.firstIn(publication.metadata.presentation.overflow, defaults.overflow)
                    ?? .scrolled,
                readingProgression: readingProgressions.firstIn(settings.readingProgression, fallback?.values.readingProgression.takeIf { _ in settings.readingProgression != nil })
                    ?? readingProgressions.firstIn(publication.metadata.readingProgression, defaults.readingProgression)
                    ?? .ttb
            )
        }
        
        func constraints(for key: PresentationKey) -> PresentationValueConstraints? {
            switch key {
            case .overflow:
                return EnumPresentationValueConstraints(supportedValues: overflows)
            case .readingProgression:
                return EnumPresentationValueConstraints(supportedValues: readingProgressions)
            default:
                return nil
            }
        }
        
        func label(for key: PresentationKey, value: AnyHashable) -> String? {
            return nil
        }
        
        func isActive(_ key: PresentationKey, for values: PresentationValues) -> Bool {
            return true
        }
        
        func activate(_ key: PresentationKey, in values: PresentationValues) throws -> PresentationValues {
            var values = values
            switch key {
            case .readingProgression:
                if [.btt, .rtl].contains(values.readingProgression) {
                    values.overflow = .paginated
                }
            default:
                break
            }
            
            return values
        }
    }
}

private extension Sequence where Element: Equatable {
    
    func firstIn(_ values: Element?...) -> Element? {
        values
            .compactMap { $0 }
            .first { contains($0) }
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
        true
    }

    func editingActions(_ editingActions: EditingActionsController, canPerformAction action: EditingAction, for selection: Selection) -> Bool {
        true
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
