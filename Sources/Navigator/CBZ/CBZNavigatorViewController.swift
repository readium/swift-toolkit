//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import R2Shared
import UIKit

public protocol CBZNavigatorDelegate: VisualNavigatorDelegate {}

/// A view controller used to render a CBZ `Publication`.
open class CBZNavigatorViewController: UIViewController, VisualNavigator, Loggable {
    enum Error: Swift.Error {
        /// The provided publication is restricted. Check that any DRM was
        /// properly unlocked using a Content Protection.
        case publicationRestricted
    }

    public weak var delegate: CBZNavigatorDelegate?

    public let publication: Publication
    private let initialIndex: Int

    private let pageViewController: UIPageViewController

    private let server: HTTPServer?
    private let publicationEndpoint: HTTPServerEndpoint?
    private var publicationBaseURL: URL!

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
                failureHandler: { [weak self] request, error in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, let href = request.href else {
                            return
                        }
                        self.delegate?.navigator(self, didFailToLoadResourceAt: href, withError: error)
                    }
                }
            )
        }

        publicationBaseURL = URL(string: publicationBaseURL.absoluteString.addingSuffix("/"))!
    }

    @available(*, deprecated, message: "See the 2.5.0 migration guide to migrate the HTTP server")
    public convenience init(publication: Publication, initialLocation: Locator? = nil) {
        precondition(!publication.isRestricted, "The provided publication is restricted. Check that any DRM was properly unlocked using a Content Protection.")
        guard publication.baseURL != nil else {
            preconditionFailure("No base URL provided for the publication. Add it to the HTTP server.")
        }

        self.init(
            publication: publication,
            initialLocation: initialLocation,
            httpServer: nil,
            publicationEndpoint: nil
        )

        publicationBaseURL = URL(string: publicationBaseURL.absoluteString.addingSuffix("/"))!
    }

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
            guard let initialLocation = initialLocation, let initialIndex = publication.readingOrder.firstIndex(withHREF: initialLocation.href) else {
                return 0
            }
            return initialIndex
        }()

        pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let endpoint = publicationEndpoint {
            server?.remove(at: endpoint)
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

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))

        goToResourceAtIndex(initialIndex, animated: false, isJump: false)
    }

    private var currentResourceIndex: Int {
        guard let imageViewController = pageViewController.viewControllers?.first as? ImageViewController,
              publication.positions.indices.contains(imageViewController.index)
        else {
            return initialIndex
        }
        return imageViewController.index
    }

    public var currentPosition: Locator? {
        guard publication.positions.indices.contains(currentResourceIndex) else {
            return nil
        }
        return publication.positions[currentResourceIndex]
    }

    @discardableResult
    private func goToResourceAtIndex(_ index: Int, animated: Bool, isJump: Bool, completion: @escaping () -> Void = {}) -> Bool {
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
        pageViewController.setViewControllers([imageViewController], direction: direction, animated: animated) { [weak self] _ in
            guard let self = self, let position = self.currentPosition else {
                return
            }
            self.delegate?.navigator(self, locationDidChange: position)
            if isJump {
                self.delegate?.navigator(self, didJumpTo: position)
            }
            completion()
        }
        return true
    }

    @objc private func didTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        delegate?.navigator(self, didTapAt: point)
    }

    private func imageViewController(at index: Int) -> ImageViewController? {
        guard publication.readingOrder.indices.contains(index),
              let url = publication.readingOrder[index].url(relativeTo: publicationBaseURL)
        else {
            return nil
        }

        return ImageViewController(index: index, url: url)
    }

    // MARK: - Navigator

    public var presentation: VisualNavigatorPresentation {
        VisualNavigatorPresentation(
            readingProgression: ReadingProgression(publication.metadata.effectiveReadingProgression) ?? .ltr,
            scroll: false,
            axis: .horizontal
        )
    }

    public var readingProgression: R2Shared.ReadingProgression {
        R2Shared.ReadingProgression(presentation.readingProgression)
    }

    public var currentLocation: Locator? {
        currentPosition
    }

    public func go(to locator: Locator, animated: Bool, completion: @escaping () -> Void) -> Bool {
        guard let index = publication.readingOrder.firstIndex(withHREF: locator.href) else {
            return false
        }
        return goToResourceAtIndex(index, animated: animated, isJump: true, completion: completion)
    }

    public func go(to link: Link, animated: Bool, completion: @escaping () -> Void) -> Bool {
        guard let index = publication.readingOrder.firstIndex(withHREF: link.href) else {
            return false
        }
        return goToResourceAtIndex(index, animated: animated, isJump: true, completion: completion)
    }

    public func goForward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        goToResourceAtIndex(currentResourceIndex + 1, animated: animated, isJump: false, completion: completion)
    }

    public func goBackward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        goToResourceAtIndex(currentResourceIndex - 1, animated: animated, isJump: false, completion: completion)
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
        if completed, let position = currentPosition {
            delegate?.navigator(self, locationDidChange: position)
        }
    }
}
