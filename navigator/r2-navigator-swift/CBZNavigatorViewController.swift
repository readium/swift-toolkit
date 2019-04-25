//
//  CBZNavigatorViewController.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 8/24/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Shared


public protocol CBZNavigatorDelegate: NavigatorDelegate { }


/// A view controller used to render a CBZ `Publication`.
open class CBZNavigatorViewController: UIViewController, Navigator, Loggable {
    
    public weak var delegate: CBZNavigatorDelegate?
    public private(set) var scrollView: UIScrollView!

    private let publication: Publication
    /// Reading order index of the current resource.
    private var currentResourceIndex: Int = 0
    private let positionList: [Locator]
    
    private var imageView: UIImageView!
    private var isMoving: Bool = false
    
    public init(publication: Publication, initialLocation: Locator? = nil) {
        self.publication = publication
        if let initialLocation = initialLocation, let initialIndex = publication.readingOrder.firstIndex(withHref: initialLocation.href) {
            self.currentResourceIndex = initialIndex
        }
        
        let pageCount = publication.readingOrder.count
        self.positionList = publication.readingOrder.enumerated().map { index, link in
            Locator(
                href: link.href,
                type: link.type ?? "",
                title: link.title,
                locations: Locations(
                    progression: Double(index) / Double(pageCount),
                    position: index + 1
                )
            )
        }

        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func loadView() {
        scrollView = UIScrollView()
        scrollView.backgroundColor = UIColor.clear
        view = scrollView
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0

        imageView = UIImageView(frame: self.scrollView.bounds)
        imageView.backgroundColor = UIColor.black
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(self.imageView)
        
        // Gestures
        for direction in [
            UISwipeGestureRecognizer.Direction.left,
            UISwipeGestureRecognizer.Direction.right
        ] {
            let gesture = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
            gesture.direction = direction
            view.addGestureRecognizer(gesture)
        }
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))

        go(to: publication.readingOrder[currentResourceIndex], animated: false)
    }
    
    @discardableResult
    private func goToResourceAtIndex(_ index: Int, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        guard !isMoving,
            publication.readingOrder.indices.contains(index),
            let url = publication.url(to: publication.readingOrder[index]) else
        {
            return false
        }
        
        isMoving = true
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, let image = UIImage(data: data) else {
                if let error = error {
                    self.log(.error, error)
                } else {
                    self.log(.error, "Can't load resource at index \(index)")
                }
                self.isMoving = false
                completion()
                return
            }
            
            DispatchQueue.main.async {
                UIView.transition(
                    with: self.imageView,
                    duration: (animated ? 0.1618 : 0),
                    options: .transitionCrossDissolve,
                    animations: {
                        self.imageView.image = image
                    },
                    completion: { _ in
                        self.currentResourceIndex = index
                        self.isMoving = false
                        self.delegate?.navigator(self, locationDidChange: self.positionList[index])
                        completion()
                    }
                )
            }
        }.resume()
        
        return true
    }
    
    @objc private func didTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        delegate?.navigator(self, didTapAt: point)
    }
    
    @objc func didSwipe(_ gesture: UISwipeGestureRecognizer) {
        let forward: Bool = {
            switch publication.contentLayout.readingProgression {
            case .ltr, .auto:
                return (.left ~= gesture.direction)
            case .rtl:
                return (.right ~= gesture.direction)
            }
        }()
        
        if forward {
            goForward(animated: true)
        } else {
            goBackward(animated: true)
        }
    }

    
    // MARK: - Navigator
    
    public var currentLocation: Locator? {
        guard positionList.indices.contains(currentResourceIndex) else {
            return nil
        }
        return positionList[currentResourceIndex]
    }
    
    public func go(to locator: Locator, animated: Bool, completion: @escaping () -> Void) -> Bool {
        guard let index = publication.readingOrder.firstIndex(withHref: locator.href) else {
            return false
        }
        return goToResourceAtIndex(index, animated: animated, completion: completion)
    }
    
    public func go(to link: Link, animated: Bool, completion: @escaping () -> Void) -> Bool {
        guard let index = publication.readingOrder.firstIndex(withHref: link.href) else {
            return false
        }
        return goToResourceAtIndex(index, animated: animated, completion: completion)
    }
    
    public func goForward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        return goToResourceAtIndex(currentResourceIndex + 1, animated: animated, completion: completion)
    }
    
    public func goBackward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        return goToResourceAtIndex(currentResourceIndex - 1, animated: animated, completion: completion)
    }

}

extension CBZNavigatorViewController: UIScrollViewDelegate {
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
}


// MARK: - Deprecated

extension CBZNavigatorViewController {
    
    @available(*, deprecated, renamed: "currentLocation.locations.position")
    public var pageNumber: Int {
        return currentResourceIndex + 1
    }
    
    @available(*, deprecated, message: "Use `publication.readingOrder.count` instead")
    public var totalPageNumber: Int {
        return publication.readingOrder.count
    }

    @available(*, deprecated, renamed: "goForward")
    @objc public func loadNext() {
        goForward(animated: true)
    }
    
    @available(*, deprecated, renamed: "goBackward")
    @objc public func loadPrevious() {
        goBackward(animated: true)
    }
    
    @available(*, deprecated, message: "Use `go(to:)` using the `readingOrder` instead")
    public func load(at index: Int) {
        goToResourceAtIndex(index, animated: true)
    }
    
    @available(*, deprecated, message: "Use init(publication:initialLocation:) instead")
    public convenience init(for publication: Publication, initialIndex: Int = 0) {
        var location: Locator? = nil
        if publication.readingOrder.indices.contains(initialIndex) {
            location = publication.readingOrder[initialIndex].locator
        }
        self.init(publication: publication, initialLocation: location)
    }
    
}

@available(*, deprecated, renamed: "CBZNavigatorViewController")
public typealias CbzNavigatorViewController = CBZNavigatorViewController
