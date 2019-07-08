//
//  TriptychView.swift
//  r2-navigator-swift
//
//  Created by Winnie Quinn, Alexandre Camilleri, Mickaël Menu on 8/23/17.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Shared

protocol TriptychResourceView {
    func go(to location: Locations)
}

protocol TriptychViewDelegate: class {
    func triptychView(_ triptychView: TriptychView, viewForIndex index: Int, location: Locations) -> (UIView & TriptychResourceView)?
    func triptychViewDidUpdateViews(_ triptychView: TriptychView)
}

final class TriptychView: UIView {

    weak var delegate: TriptychViewDelegate? {
        didSet {
            setCurrentView(at: currentIndex, location: initialLocation)
        }
    }

    /// Location to load in the initial resource view.
    let initialLocation: Locations
    
    /// Direction for the reading progression.
    let readingProgression: ReadingProgression
    
    /// Total number of resource views to be paginated.
    let viewCount: Int

    /// Pre-loaded resource views, indexed by their position.
    private(set) var loadedViews: [Int: (UIView & TriptychResourceView)] = [:]

    /// Returns whether the resource views are loaded.
    var isEmpty: Bool {
        return loadedViews.isEmpty
    }

    /// Index of the resource view currently being displayed.
    private(set) var currentIndex: Int

    /// Return the currently presented view from the Views array.
    var currentView: (UIView & TriptychResourceView)? {
        return loadedViews[currentIndex]
    }

    /// Loaded resource views in reading order.
    private var orderedViews: [UIView & TriptychResourceView] {
        var orderedViews = loadedViews
            .sorted { $0.key < $1.key }
            .map { $0.value }
        
        if readingProgression == .rtl {
            orderedViews.reverse()
        }
        
        return orderedViews
    }

    // Number of views to preload before and after the current one.
    // Note: For now only 1 is supported. If we add support for several, then this class should probably be renamed (triptych = 3).
    private let preloadPreviousCount = 1
    private let preloadNextCount = 1

    private let scrollView = UIScrollView()

    private var clamping: Clamping = .none
    private enum Clamping {
        case none
        case onlyPrevious
        case onlyNext
    }

    init(frame: CGRect, viewCount: Int, initialIndex: Int, initialLocation: Locations, readingProgression: ReadingProgression) {
        precondition(viewCount >= 1)
        precondition(0..<viewCount ~= initialIndex)

        self.initialLocation = initialLocation
        self.readingProgression = readingProgression
        self.viewCount = viewCount
        self.currentIndex = initialIndex

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

        let views = orderedViews
        
        let size = frame.size
        scrollView.contentSize = CGSize(width: size.width * CGFloat(views.count), height: size.height)

        for (index, view) in views.enumerated() {
            view.frame = CGRect(origin: CGPoint(x: size.width * CGFloat(index), y: 0), size: size)
        }

        let pageOffset = min(1, currentIndex)
        
        scrollView.contentOffset.x = (readingProgression == .rtl)
            ? scrollView.contentSize.width - CGFloat(pageOffset + 1) * scrollView.frame.width
            : size.width * CGFloat(pageOffset)
    }

    /// Updates the current and pre-loaded views.
    private func setCurrentView(at index: Int, location: Locations? = nil) {
        guard isEmpty || index != currentIndex else {
            return
        }

        // Locations in a resource view.
        let beginning = Locations(progression: 0)
        let end = Locations(progression: 1)
        let location = location ?? beginning
        
        // Automatically scrolls the previous document to the beginning or the end, to make sure that it's properly positioned to the consecutive resource when going back to it.
        currentView?.go(to: (currentIndex < index) ? end : beginning)
        
        currentIndex = index
        
        // To make sure that the views the most likely to be visible are loaded first, we first load the current one, then the next ones and to finish the previous ones.
        loadView(at: index, location: location)
        
        for i in 1...preloadNextCount {
            loadView(at: index + i, location: beginning)
        }
        
        for i in 1...preloadPreviousCount {
            loadView(at: index - i, location: end)
        }

        for (i, view) in loadedViews {
            // Flushes the views that are not needed anymore.
            guard index-preloadPreviousCount...index+preloadNextCount ~= i else {
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
        delegate?.triptychViewDidUpdateViews(self)
    }

    /// Loads the view at given index if it's not already loaded.
    ///
    /// - Parameter location: Initial location in the view to be displayed.
    private func loadView(at index: Int, location: Locations) {
        guard 0..<viewCount ~= index,
            loadedViews[index] == nil,
            let delegate = delegate,
            let view = delegate.triptychView(self, viewForIndex: index, location: location) else
        {
            return
        }
        loadedViews[index] = view
    }

    
    // MARK: - Navigation
    
    /// Go to the resource view with given index.
    ///
    /// - Parameters:
    ///   - index: The index to move to.
    ///   - location: The location to move the future current resource view to.
    /// - Returns: Whether the move is possible.
    func goToIndex(_ index: Int, location: Locations? = nil, animated: Bool = false, completion: @escaping () -> ()) -> Bool {
        guard 0..<viewCount ~= index else {
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
            // FIXME: this should be handled in the TriptychResourceView directly
            let delayed = (location != nil && location?.progression != 0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (delayed ? 0.5 : 0)) {
                fade(to: 1, completion: completion)
            }
        }
        
        return true
    }
    
    private func scrollToView(at index: Int, location: Locations? = nil) {
        guard currentIndex != index else {
            if let location = location {
                currentView?.go(to: location)
            }
            return
        }

        var currentRect = scrollView.contentOffset
        let currentFrameSize = scrollView.frame.size
        
        let coefficient = CGFloat(readingProgression == .rtl ? -1:1)

        if currentIndex < index {
            currentRect.x += coefficient * currentFrameSize.width
            scrollView.scrollRectToVisible(CGRect(origin: currentRect, size: currentFrameSize), animated: false)
        } else {
            currentRect.x -= coefficient * currentFrameSize.width
            scrollView.scrollRectToVisible(CGRect(origin: currentRect, size: currentFrameSize), animated: false)
        }

        clamping = .none
        setCurrentView(at: index, location: location)
    }

}

extension TriptychView: UIScrollViewDelegate {

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if loadedViews.count >= 3 {
            let width = frame.size.width
            let xOffset = scrollView.contentOffset.x

            switch clamping {
            case .none:
                if xOffset < width {
                    clamping = .onlyPrevious
                } else if xOffset > width {
                    clamping = .onlyNext
                }
            case .onlyPrevious:
                scrollView.contentOffset.x = min(xOffset, width)
            case .onlyNext:
                scrollView.contentOffset.x = max(xOffset, width)
            }
        }
    }
    
    // Set the clamping to .none in scrollViewDidEndScrollingAnimation and scrollViewDidEndDragging with decelerate == false, to prevent the bug introduced by the workaround in scrollViewDidEndDecelerating where the scrollview contentOffset is animated. When animating the contentOffset, scrollViewDidScroll is called without calling scrollViewDidEndDecelerating afterwards.
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        clamping = .none
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate { return }
        clamping = .none
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        clamping = .none

        let offset:CGFloat = {
            if self.readingProgression == .rtl {
                return scrollView.contentSize.width - (scrollView.contentOffset.x + scrollView.frame.width)
            }
            return scrollView.contentOffset.x
        } ()
        
        let pageOffset = Int(round(offset / scrollView.frame.width))

        var newIndex = currentIndex
        if pageOffset == 0 {
            if newIndex > 0 {
                newIndex -= 1
            }
        } else if pageOffset == 1 {
            if newIndex == 0 {
                newIndex += 1
            }
        } else {
            assert(pageOffset == 2)
            newIndex += 1
        }

        setCurrentView(at: newIndex)

        // This works around a very specific case that may be a bug in iOS's scroll view implementation. If the user is on a view of currentIndex >= 1, and if the user swipes forward slightly and then, with great force, swipes back and quickly lets go, the scroll view will slam up against the clamped boundary and "bounce" even if bouncing is disabled. The reason for this is unclear! In any case, the following code compensates for this by animating a transition to a content offset on a page boundary if, for any reason (including the above), the scroll view has come rest on an offset that is _not_ a page boundary. The conditional guard here prevents animating if the offset is already correct because otherwise doing so may result in a visual glitch (also for unknown reasons).
        if (fmod(scrollView.contentOffset.x, scrollView.frame.width) != 0.0) {
            let adjustedOffset = (self.readingProgression == .rtl)
                ? scrollView.contentSize.width - CGFloat(pageOffset + 1) * scrollView.frame.width
                : CGFloat(pageOffset) * scrollView.frame.width
            
            scrollView.setContentOffset(CGPoint(x: adjustedOffset, y: 0), animated: true)
        }
    }
    
}
