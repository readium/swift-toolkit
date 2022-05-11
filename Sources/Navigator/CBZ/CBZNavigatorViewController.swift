//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit
import R2Shared


public protocol CBZNavigatorDelegate: VisualNavigatorDelegate { }


/// A view controller used to render a CBZ `Publication`.
open class CBZNavigatorViewController: UIViewController, VisualNavigator, Loggable {
    
    public weak var delegate: CBZNavigatorDelegate?

    private let publication: Publication
    private let initialIndex: Int

    private let pageViewController: UIPageViewController

    public init(publication: Publication, initialLocation: Locator? = nil) {
        assert(!publication.isRestricted, "The provided publication is restricted. Check that any DRM was properly unlocked using a Content Protection.")
        
        self.publication = publication
        self.initialIndex = {
            guard let initialLocation = initialLocation, let initialIndex = publication.readingOrder.firstIndex(withHREF: initialLocation.href) else {
                return 0
            }
            return initialIndex
        }()
        
        self.pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            publication.positions.indices.contains(imageViewController.index) else
        {
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
                    return (currentResourceIndex < index)
                case .rtl, .btt:
                    return (currentResourceIndex >= index)
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
            let url = publication.readingOrder[index].url(relativeTo: publication.baseURL) else
        {
            return nil
        }
        
        return ImageViewController(index: index, url: url)
    }


    // MARK: - Navigator
    
    public var readingProgression: ReadingProgression {
        publication.metadata.effectiveReadingProgression
    }

    public var currentLocation: Locator? {
        return currentPosition
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
        return goToResourceAtIndex(currentResourceIndex + 1, animated: animated, isJump: false, completion: completion)
    }
    
    public func goBackward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        return goToResourceAtIndex(currentResourceIndex - 1, animated: animated, isJump: false, completion: completion)
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


// MARK: - Deprecated

extension CBZNavigatorViewController {
    
    @available(*, unavailable, renamed: "currentLocation.locations.position")
    public var pageNumber: Int {
        return currentResourceIndex + 1
    }
    
    @available(*, unavailable, message: "Use `publication.readingOrder.count` instead")
    public var totalPageNumber: Int {
        return publication.readingOrder.count
    }

    @available(*, unavailable, renamed: "goForward")
    @objc public func loadNext() {
        goForward(animated: true)
    }
    
    @available(*, unavailable, renamed: "goBackward")
    @objc public func loadPrevious() {
        goBackward(animated: true)
    }
    
    @available(*, unavailable, message: "Use `go(to:)` using the `readingOrder` instead")
    public func load(at index: Int) {}
    
    @available(*, unavailable, message: "Use init(publication:initialLocation:) instead")
    public convenience init(for publication: Publication, initialIndex: Int = 0) {
        var location: Locator? = nil
        if publication.readingOrder.indices.contains(initialIndex) {
            location = publication.locate(publication.readingOrder[initialIndex])
        }
        self.init(publication: publication, initialLocation: location)
    }
    
}

@available(*, unavailable, renamed: "CBZNavigatorViewController")
public typealias CbzNavigatorViewController = CBZNavigatorViewController
