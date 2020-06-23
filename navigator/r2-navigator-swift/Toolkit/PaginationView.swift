//
//  PaginationView.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 17.07.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Shared

enum PageLocation {
    case start
    case end
    case locator(Locator)
    
    init(_ locator: Locator?) {
        self = locator.map { .locator($0) }
            ?? .start
    }
    
    var isStart: Bool {
        switch self {
        case .start:
            return true
        case .locator(let locator) where locator.locations.progression ?? 0 > 0:
            return true
        default:
            return false
        }
    }
    
}

protocol PageView {
    /// Moves the page to the given internal location.
    func go(to location: PageLocation, completion: (() -> Void)?)
    
    /// Return the number of positions (as in `Publication.positionList`) contained in the page.
    var positionCount: Int { get }
}

extension PageView {
    
    func go(to location: PageLocation) {
        go(to: location, completion: nil)
    }
    
}

protocol PaginationViewDelegate: class {
    /// Creates the page view for the page at given index.
    func paginationView(_ paginationView: PaginationView, pageViewAtIndex index: Int) -> (UIView & PageView)?
    
    /// Called when the page views were updated.
    func paginationViewDidUpdateViews(_ paginationView: PaginationView)
}

final class PaginationView: UIView {
    
    weak var delegate: PaginationViewDelegate?

    /// Total number of page views to be paginated.
    private(set) var pageCount: Int = 0
    
    /// Index of the page currently being displayed.
    private(set) var currentIndex: Int = 0

    /// Direction for the reading progression.
    private(set) var readingProgression: ReadingProgression = .ltr
    
    /// Pre-loaded page views, indexed by their position.
    private(set) var loadedViews: [Int: (UIView & PageView)] = [:]
    
    /// Number of positions (as in `Publication.positionList`) to preload before and after the current page.
    private let preloadPreviousPositionCount: Int
    private let preloadNextPositionCount: Int
    
    /// Returns whether the page views are loaded.
    var isEmpty: Bool {
        return loadedViews.isEmpty
    }

    /// Return the currently presented page view from the Views array.
    var currentView: (UIView & PageView)? {
        return loadedViews[currentIndex]
    }
    
    /// Loaded page views in reading order.
    private var orderedViews: [UIView & PageView] {
        var orderedViews = loadedViews
            .sorted { $0.key < $1.key }
            .map { $0.value }
        
        if readingProgression == .rtl {
            orderedViews.reverse()
        }
        
        return orderedViews
    }

    private let scrollView = UIScrollView()
    
    init(frame: CGRect, preloadPreviousPositionCount: Int, preloadNextPositionCount: Int) {
        self.preloadPreviousPositionCount = preloadPreviousPositionCount
        self.preloadNextPositionCount = preloadNextPositionCount
        
        super.init(frame: frame)
        
        scrollView.delegate = self
        scrollView.frame = bounds
        scrollView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        scrollView.isPagingEnabled = true
        scrollView.bounces = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
        
        // Adds an empty view before the scroll view to have a consistent behavior on all iOS versions, regarding to the content inset adjustements. Even if automaticallyAdjustsScrollViewInsets is not set to false on the navigator's parent view controller, the scroll view insets won't be adjusted if the scroll view is not the first child in the subviews hierarchy.
        insertSubview(UIView(frame: .zero), at: 0)
        if #available(iOS 11.0, *) {
            // Prevents the content from jumping down when the status bar is toggled
            scrollView.contentInsetAdjustmentBehavior = .never
        }
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        guard !loadedViews.isEmpty else {
            scrollView.contentSize = bounds.size
            return
        }
        
        let size = scrollView.bounds.size
        scrollView.contentSize = CGSize(width: size.width * CGFloat(pageCount), height: size.height)
        
        for (index, view) in loadedViews {
            view.frame = CGRect(origin: CGPoint(x: size.width * CGFloat(index), y: 0), size: size)
        }
        
        scrollView.contentOffset.x = xOffsetForIndex(currentIndex)
    }
    
    /// Reloads the pagination with the given total number of pages and current index.
    ///
    /// - Parameters:
    ///   - index: Index of the page to be displayed after reloading the pagination.
    ///   - location: Location to be displayed in the page.
    ///   - pageCount: Total number of pages in the pagination view.
    ///   - readingProgression: Direction of reading progression.
    func reloadAtIndex(_ index: Int, location: PageLocation, pageCount: Int, readingProgression: ReadingProgression) {
        precondition(pageCount >= 1)
        precondition(0..<pageCount ~= index)
        
        self.pageCount = pageCount
        self.readingProgression = readingProgression
        
        for (_, view) in loadedViews {
            view.removeFromSuperview()
        }
        loadedViews.removeAll()
        
        setCurrentIndex(index, location: location)
    }
    
    /// Returns the x offset to the page view with given index in the scroll view.
    private func xOffsetForIndex(_ index: Int) -> CGFloat {
        return (readingProgression == .rtl)
            ? scrollView.contentSize.width - (CGFloat(index + 1) * scrollView.bounds.width)
            : scrollView.bounds.width * CGFloat(index)
    }

    /// Updates the current and pre-loaded views.
    private func setCurrentIndex(_ index: Int, location: PageLocation? = nil) {
        guard isEmpty || index != currentIndex else {
            return
        }
        
        currentIndex = index
        
        // To make sure that the views the most likely to be visible are loaded first, we first load the current one, then the next ones and to finish the previous ones.
        loadView(at: index, location: location)
        let lastIndex = loadViews(upToPositionCount: preloadNextPositionCount, from: index, direction: .forward, location: .start)
        let firstIndex = loadViews(upToPositionCount: preloadPreviousPositionCount, from: index, direction: .backward, location: .end)

        for (i, view) in loadedViews {
            // Flushes the views that are not needed anymore.
            guard firstIndex...lastIndex ~= i else {
                view.removeFromSuperview()
                loadedViews.removeValue(forKey: i)
                continue
            }
            
            // Adds newly loaded views to the scroll view.
            if view.superview == nil {
                scrollView.addSubview(view)
            }
        }

        setNeedsLayout()
        delegate?.paginationViewDidUpdateViews(self)
    }

    /// Loads the view at given index if it's not already loaded.
    ///
    /// - Returns: The loaded page view, if any.
    @discardableResult
    private func loadView(at index: Int, location: PageLocation?) -> (UIView & PageView)? {
        if 0..<pageCount ~= index,
            loadedViews[index] == nil,
            let delegate = delegate,
            let view = delegate.paginationView(self, pageViewAtIndex: index)
        {
            loadedViews[index] = view
        }
        
        let view = loadedViews[index]
        if let location = location {
            view?.go(to: location)
        }
        
        return view
    }
    
    /// Loads views until reaching the given number of pre-loaded positions.
    ///
    /// - Parameters:
    ///   - positionCount: Number of positions to pre-load before stopping.
    ///   - sourceIndex: Starting page index from which to pre-load the views.
    ///   - direction: The direction in which to load the views from the sourceIndex.
    /// - Returns: The last page index loaded after reaching the requested number of positions.
    private func loadViews(upToPositionCount positionCount: Int, from sourceIndex: Int, direction: PageIndexDirection, location: PageLocation?) -> Int {
        let index = sourceIndex + direction.rawValue
        guard positionCount > 0,
            let pageView = loadView(at: index, location: location) else
        {
            return sourceIndex
        }
        
        return loadViews(
            upToPositionCount: positionCount - pageView.positionCount,
            from: index,
            direction: direction,
            location: location
        )
    }
    
    private enum PageIndexDirection: Int {
        case forward = 1
        case backward = -1
    }
    
    
    // MARK: - Navigation
    
    /// Go to the page view with given index.
    ///
    /// - Parameters:
    ///   - index: The index to move to.
    ///   - location: The location to move the future current page view to.
    /// - Returns: Whether the move is possible.
    func goToIndex(_ index: Int, location: PageLocation, animated: Bool = false, completion: @escaping () -> ()) -> Bool {
        guard 0..<pageCount ~= index else {
            return false
        }
        
        func fade(to alpha: CGFloat, completion: @escaping () -> ()) {
            if animated {
                UIView.animate(withDuration: 0.15, animations: {
                    self.alpha = alpha
                }) { _ in completion() }
            } else {
                self.alpha = alpha
                completion()
            }
        }
        
        fade(to: 0) {
            self.scrollToView(at: index, location: location)
            
            // The rendering is sometimes very slow. So in case we don't show the first page of the resource, we add a generous delay before showing the view again.
            // FIXME: this should be handled in the PageView directly
            let delayed = !location.isStart
            DispatchQueue.main.asyncAfter(deadline: .now() + (delayed ? 0.5 : 0)) {
                fade(to: 1, completion: completion)
            }
        }
        
        return true
    }
    
    private func scrollToView(at index: Int, location: PageLocation) {
        guard currentIndex != index else {
            currentView?.go(to: location)
            return
        }
        
        scrollView.isScrollEnabled = true
        setCurrentIndex(index, location: location)

        scrollView.scrollRectToVisible(CGRect(
            origin: CGPoint(
                x: xOffsetForIndex(index),
                y: scrollView.contentOffset.y
            ),
            size: scrollView.frame.size
        ), animated: false)
    }
    
}


extension PaginationView: UIScrollViewDelegate {
    
    /// We disable the scroll once the user releases the drag to prevent scrolling through more than 1 resource at a time. Otherwise, because the pagination view's scroll view would have the focus during the scroll gesture, the scrollable content of the resources would be skipped.
    /// Note: using this approach might provide a better experience: https://oleb.net/blog/2014/05/scrollviews-inside-scrollviews/
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        scrollView.isScrollEnabled = false
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollView.isScrollEnabled = true
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollView.isScrollEnabled = true
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollView.isScrollEnabled = true
        
        let currentOffset = (readingProgression == .rtl)
            ? scrollView.contentSize.width - (scrollView.contentOffset.x + scrollView.frame.width)
            : scrollView.contentOffset.x
        
        let newIndex = Int(round(currentOffset / scrollView.frame.width))
        
        setCurrentIndex(newIndex)
    }
    
}
