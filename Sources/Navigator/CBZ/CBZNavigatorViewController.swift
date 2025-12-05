//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumInternal
import ReadiumShared
import UIKit

public protocol CBZNavigatorDelegate: VisualNavigatorDelegate {}

/// A view controller used to render a CBZ `Publication`.
open class CBZNavigatorViewController:
    InputObservableViewController,
    VisualNavigator, Loggable
{
    enum Error: Swift.Error {
        /// The provided publication is restricted. Check that any DRM was
        /// properly unlocked using a Content Protection.
        case publicationRestricted
    }

    public weak var delegate: CBZNavigatorDelegate?

    public let publication: Publication
    private let initialIndex: Int
    private var positions: [Locator]?

    private let pageViewController: UIPageViewController

    private let server: HTTPServer?
    private let publicationEndpoint: HTTPServerEndpoint?
    private var publicationBaseURL: HTTPURL!

    public convenience init(
        publication: Publication,
        initialLocation: Locator?,
        editingActions: [EditingAction] = EditingAction.defaultActions,
        httpServer: HTTPServer
    ) throws {
        guard !publication.isRestricted else {
            throw Error.publicationRestricted
        }

        let publicationEndpoint: HTTPServerEndpoint?
        let uuidEndpoint = UUID().uuidString
        if publication.baseURL != nil {
            publicationEndpoint = nil
        } else {
            publicationEndpoint = uuidEndpoint
        }

        self.init(
            publication: publication,
            initialLocation: initialLocation,
            httpServer: httpServer,
            publicationEndpoint: publicationEndpoint
        )

        if let url = publication.baseURL {
            publicationBaseURL = url
        } else {
            publicationBaseURL = try httpServer.serve(
                at: uuidEndpoint,
                publication: publication,
                onFailure: { [weak self] request, error in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, let href = request.href else {
                            return
                        }
                        self.delegate?.navigator(self, didFailToLoadResourceAt: href, withError: error)
                    }
                }
            )
        }
    }

    private let tasks = CancellableTasks()

    private init(
        publication: Publication,
        initialLocation: Locator?,
        httpServer: HTTPServer?,
        publicationEndpoint: HTTPServerEndpoint?
    ) {
        self.publication = publication
        server = httpServer
        self.publicationEndpoint = publicationEndpoint

        initialIndex = {
            guard let initialLocation = initialLocation, let initialIndex = publication.readingOrder.firstIndexWithHREF(initialLocation.href) else {
                return 0
            }
            return initialIndex
        }()

        pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )

        super.init(nibName: nil, bundle: nil)

        setupLegacyInputCallbacks(
            onTap: { [weak self] point in
                guard let self else { return }
                self.delegate?.navigator(self, didTapAt: point)
            },
            onPressKey: { [weak self] event in
                guard let self else { return }
                self.delegate?.navigator(self, didPressKey: event)
            },
            onReleaseKey: { [weak self] event in
                guard let self else { return }
                self.delegate?.navigator(self, didReleaseKey: event)
            }
        )
    }

    private func didLoadPositions(_ positions: [Locator]?) {
        self.positions = positions ?? []
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let endpoint = publicationEndpoint {
            try? server?.remove(at: endpoint)
        }
    }

    override open func viewDidLoad() {
        super.viewDidLoad()

        pageViewController.dataSource = self
        pageViewController.delegate = self

        addChild(pageViewController)
        pageViewController.view.frame = view.bounds
        pageViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)

        view.addGestureRecognizer(InputObservingGestureRecognizerAdapter(observer: inputObservers))

        tasks.add {
            try? await didLoadPositions(publication.positions().get())
            await goToResourceAtIndex(initialIndex, options: NavigatorGoOptions(animated: false), isJump: false)
        }
    }

    private var currentResourceIndex: Int {
        guard
            let positions = positions,
            let imageViewController = pageViewController.viewControllers?.first as? ImageViewController,
            positions.indices.contains(imageViewController.index)
        else {
            return initialIndex
        }
        return imageViewController.index
    }

    @discardableResult
    private func goToResourceAtIndex(_ index: Int, options: NavigatorGoOptions, isJump: Bool) async -> Bool {
        guard let imageViewController = imageViewController(at: index) else {
            return false
        }
        let direction: UIPageViewController.NavigationDirection = {
            let forward: Bool = {
                switch readingProgression {
                case .ltr, .ttb, .auto:
                    return currentResourceIndex < index
                case .rtl, .btt:
                    return currentResourceIndex >= index
                }
            }()
            return forward ? .forward : .reverse
        }()

        await withCheckedContinuation { continuation in
            pageViewController.setViewControllers([imageViewController], direction: direction, animated: options.animated) { [weak self] _ in
                guard let self = self, let position = self.currentLocation else {
                    return
                }
                self.delegate?.navigator(self, locationDidChange: position)
                if isJump {
                    self.delegate?.navigator(self, didJumpTo: position)
                }
                continuation.resume()
            }
        }

        return true
    }

    private func imageViewController(at index: Int) -> ImageViewController? {
        guard publication.readingOrder.indices.contains(index) else {
            return nil
        }
        let url = publication.readingOrder[index].url(relativeTo: publicationBaseURL)
        return ImageViewController(index: index, url: url.url)
    }

    // MARK: - Navigator

    public var presentation: VisualNavigatorPresentation {
        VisualNavigatorPresentation(
            readingProgression: ReadingProgression(publication.metadata.readingProgression) ?? .ltr,
            scroll: false,
            axis: .horizontal
        )
    }

    public var readingProgression: ReadiumShared.ReadingProgression {
        ReadiumShared.ReadingProgression(presentation.readingProgression)
    }

    public var currentLocation: Locator? {
        guard
            let positions = positions,
            positions.indices.contains(currentResourceIndex)
        else {
            return nil
        }
        return positions[currentResourceIndex]
    }

    public func go(to locator: Locator, options: NavigatorGoOptions) async -> Bool {
        let locator = publication.normalizeLocator(locator)

        guard let index = publication.readingOrder.firstIndexWithHREF(locator.href) else {
            return false
        }
        return await goToResourceAtIndex(index, options: options, isJump: true)
    }

    public func go(to link: Link, options: NavigatorGoOptions) async -> Bool {
        guard let index = publication.readingOrder.firstIndexWithHREF(link.url()) else {
            return false
        }
        return await goToResourceAtIndex(index, options: options, isJump: true)
    }

    public func goForward(options: NavigatorGoOptions) async -> Bool {
        await goToResourceAtIndex(currentResourceIndex + 1, options: options, isJump: false)
    }

    public func goBackward(options: NavigatorGoOptions) async -> Bool {
        await goToResourceAtIndex(currentResourceIndex - 1, options: options, isJump: false)
    }
}

extension CBZNavigatorViewController: UIPageViewControllerDataSource {
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let imageVC = viewController as? ImageViewController else {
            return nil
        }
        var index = imageVC.index
        switch readingProgression {
        case .ltr, .ttb, .auto:
            index -= 1
        case .rtl, .btt:
            index += 1
        }
        return imageViewController(at: index)
    }

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let imageVC = viewController as? ImageViewController else {
            return nil
        }
        var index = imageVC.index
        switch readingProgression {
        case .ltr, .ttb, .auto:
            index += 1
        case .rtl, .btt:
            index -= 1
        }
        return imageViewController(at: index)
    }
}

extension CBZNavigatorViewController: UIPageViewControllerDelegate {
    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed, let position = currentLocation {
            delegate?.navigator(self, locationDidChange: position)
        }
    }
}
