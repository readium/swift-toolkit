 //
//  TriptychView.swift
//  r2-navigator-swift
//
//  Created by Winnie Quinn, Alexandre Camilleri on 8/23/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Shared

protocol TriptychViewDelegate: class {

    func triptychView(
        _ view: TriptychView,
        viewForIndex index: Int,
        location: BinaryLocation)
        -> UIView
    
    func viewsDidUpdate(documentIndex:Int)
}

final class TriptychView: UIView {

    fileprivate enum Clamping {
        case none
        case onlyPrevious
        case onlyNext
    }

    /// The array containing the Views for the current document, and possibly for
    /// the next and previous or other kind of preloading.
    internal enum Views {
        case one(view: UIView)
        case two(firstView: UIView, secondView: UIView)
        case many(currentView: UIView, otherViews: Disjunction<UIView, UIView>)

        var array: [UIView] {
            switch self {
            case .one(let view):
                return [view]
            case .two(let firstView, let secondView):
                return [firstView, secondView]
            case .many(let currentView, let otherViews):
                switch otherViews {
                case .first(let previousView):
                    return [previousView, currentView]
                case .second(let nextView):
                    return [currentView, nextView]
                case .both(let previousView, let nextView):
                    return [previousView, currentView, nextView]
                }
            }
        }

        var count: Int {
            switch self {
            case .one:
                return 1
            case .two:
                return 2
            case .many(_, let otherViews):
                return 1 + otherViews.count
            }
        }
    }

    /// Return the currently presented view from the Views array.
    var currentView: UIView? {
        switch views {
        case nil:
            return nil
        case let .some(.one(a)):
            // [?]
            return a
        case let .some(.two(a, b)):
            // [?, ?]
            return index == 0 ? a : b
        case let .some(.many(a, .first(b))):
            // [?, ?, -, ... -, ?, ?]
            return (index == 0 || index == viewCount - 1) ? a : b
        case let .some(.many(a, .both)):
            // [... , -, ?, a, ?, -, ...]
            return a
        case let .some(.many(a, .second(b))):
            return index == viewCount - 1 ? b : a
        }
    }

    public weak var delegate: TriptychViewDelegate? {
        didSet {
            self.updateViews()
        }
    }

    /// Index of the document currently being displayed.
    fileprivate(set) var index: Int {
        willSet {
            guard let cw = currentView as? DocumentWebView else {
                return
            }
            cw.scrollAt(location: (index < newValue) ? trailing : leading)
        }
    }

    fileprivate let scrollView: UIScrollView

    public let viewCount: Int

    internal var views: Views?
    
    let leading, trailing: BinaryLocation
    let readingProgression: ReadingProgression

    fileprivate var clamping: Clamping = .none

    private var isAtAnEdge: Bool {
        return index == 0 || index == viewCount - 1
    }
    
    public init(frame: CGRect, viewCount: Int, initialIndex: Int, readingProgression: ReadingProgression) {

        precondition(viewCount >= 1)
        precondition(initialIndex >= 0 && initialIndex < viewCount)

        index = initialIndex
        self.viewCount = viewCount
        self.readingProgression = readingProgression
        self.scrollView = UIScrollView()

        if self.readingProgression == .rtl {
            leading = .right; trailing = .left
        } else {
            leading = .left; trailing = .right
        }
        
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
            // Prevents the pages from jumping down when the status bar is toggled
            scrollView.contentInsetAdjustmentBehavior = .never
        }
    }

    deinit {
        guard let views = views else {
            return
        }
        for view in views.array {
            if let webview = (view as? DocumentWebView) {
                webview.removeMessageHandlers()
            }
        }
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        if views == nil {
            updateViews()
        }

        guard let views = self.views else {
            scrollView.contentSize = bounds.size
            return
        }

        let size = frame.size

        scrollView.contentSize = CGSize(width: size.width * CGFloat(views.count), height: size.height)
        
        let viewList:[UIView] = {
            if self.readingProgression == .rtl {
                return views.array.reversed()
            }
            return views.array
        }()
        
        for (index, view) in viewList.enumerated() {
            view.frame = CGRect(origin: CGPoint(x: size.width * CGFloat(index), y: 0), size: size)
        }

        let pageOffset = min(1, index)
        
        let offset:CGFloat = {
            if self.readingProgression == .rtl {
                return scrollView.contentSize.width - CGFloat(pageOffset+1)*scrollView.frame.width
            }
            return size.width * CGFloat(pageOffset)
        } ()
        
        scrollView.contentOffset.x = offset
    }

    fileprivate func updateViews(previousIndex: Int? = nil) {

        if previousIndex == index {
            return
        }

        guard let delegate = delegate else {
            return
        }
        
        func viewForIndex(_ index: Int, location: BinaryLocation) -> UIView {
            guard let views = views, let previousIndex = previousIndex else {
                return delegate.triptychView(self, viewForIndex: index, location: location)
            }

            var indexesToCurrentViews: [Int: UIView] = [:]

            switch views {
            case .one(let view):
                indexesToCurrentViews[0] = view
            case .two(let firstView, let secondView):
                indexesToCurrentViews[0] = firstView // What?
                indexesToCurrentViews[1] = secondView // What?
            case .many(let currentView, let otherViews):
                indexesToCurrentViews[previousIndex] = currentView
                switch otherViews {
                case .first(let view):
                    indexesToCurrentViews[previousIndex - 1] = view
                case .second(let view):
                    indexesToCurrentViews[previousIndex + 1] = view
                case .both(let firstView, let secondView):
                    indexesToCurrentViews[previousIndex - 1] = firstView
                    indexesToCurrentViews[previousIndex + 1] = secondView
                }
            }

            if let view = indexesToCurrentViews[index] {
                return view
            }

            return delegate.triptychView(self, viewForIndex: index, location: location)
        }

        switch viewCount {
        case 1:
            assert(index == 0)
            let view = viewForIndex(0, location: leading)
            views = Views.one(view: view)
        case 2:
            assert(index < 2)
            if index == 0 {
                let firstView = viewForIndex(0, location: leading)
                let secondView = viewForIndex(1, location: leading)
                views = Views.two(firstView: firstView, secondView: secondView)
            } else {
                let firstView = viewForIndex(0, location: trailing)
                let secondView = viewForIndex(1, location: leading)
                views = Views.two(firstView: firstView, secondView: secondView)
            }
        default:
            if index == 0 {
                self.views = Views.many(
                    currentView: viewForIndex(index, location: leading),
                    otherViews: Disjunction.second(value:
                        viewForIndex(index + 1, location: trailing)))
            } else if index == viewCount - 1 {
                views = Views.many(
                    currentView: viewForIndex(index, location: trailing),
                    otherViews: Disjunction.first(value:
                        viewForIndex(index - 1, location: leading)))
            } else {
                views = Views.many(
                    currentView: viewForIndex(index, location: leading),
                    otherViews: Disjunction.both(
                        first: viewForIndex(index - 1, location: trailing),
                        second: viewForIndex(index + 1, location: leading)))
            }
        }

        delegate.viewsDidUpdate(documentIndex: index)
    
        syncSubviews()
        setNeedsLayout()
    }

    private func syncSubviews() {
        let webViewsBefore = scrollView.subviews.compactMap { $0 as? DocumentWebView }
        scrollView.subviews.forEach({
            $0.removeFromSuperview()
        })

        if let viewArray = views?.array {
            viewArray.forEach({
                if let webview = ($0 as? DocumentWebView) {
                    webview.addMessageHandlers()
                }
                self.scrollView.addSubview($0)
            })
        }
        
        webViewsBefore.forEach {
            if $0.superview == nil { $0.removeMessageHandlers() }
        }
    }
}

extension TriptychView {

    /// Wraps a `move` triptych block to animate or not the change.
    /// - Parameter delayedFadeIn: This is used when we want to jump to a specific location in the resource. The rendering is sometimes very slow in this case so we have a generous delay before we show the view again.
    func performTransition(animated: Bool = false, delayed: Bool = false, completion: @escaping () -> (), _ transition: @escaping (TriptychView) -> ()) {
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
            transition(self)
            DispatchQueue.main.asyncAfter(deadline: .now() + (delayed ? 0.5 : 0)) {
                fade(to: 1, completion: completion)
            }
        }
    }
    
    /// Move to the given index
    ///
    /// - Parameters:
    ///   - nextIndex: The index to move to.
    internal func moveTo(index nextIndex: Int, id: String? = nil) {
        var cw = currentView as! DocumentWebView

        guard index != nextIndex else {
            if let id = id {
                if id == "" {
                    cw.scrollAt(location: leading)
                } else {
                    cw.scrollAt(tagId: id)
                }
            }
            return
        }

        var currentRect = scrollView.contentOffset
        let currentFrameSize = scrollView.frame.size
        
        let coefficient = CGFloat(readingProgression == .rtl ? -1:1)

        if index < nextIndex {
            currentRect.x += coefficient*currentFrameSize.width
            scrollView.scrollRectToVisible(CGRect(origin: currentRect, size: currentFrameSize), animated: false)
        } else {
            currentRect.x -= coefficient*currentFrameSize.width
            scrollView.scrollRectToVisible(CGRect(origin: currentRect, size: currentFrameSize), animated: false)
        }

        let previousIndex = index

        index = nextIndex
        clamping = .none
        updateViews(previousIndex: previousIndex)

        // get the new current view after change.
        cw = currentView as! DocumentWebView
        if let id = id {
            if id == "" {
                if abs(previousIndex - nextIndex) == 1 {
                    // if the view was adjacent and already loaded
                    cw.scrollAt(location: leading)
                } else {
                    // In case the view wasn't preloaded
                    cw.progression = 0.0
                }
            } else {
                if abs(previousIndex - nextIndex) == 1 {
                    cw.scrollAt(tagId: id)
                } else {
                    cw.initialId = id
                }
            }
        }
    }

    /// Returns the progression in the document currently being displayed.
    var currentDocumentProgression: Double? {
        guard currentView != nil else {
            return nil
        }
        return (currentView as! DocumentWebView).progression
    }
}

extension TriptychView: UIScrollViewDelegate {

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let views = views else {
            return
        }

        if views.count == 3 {
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
    
    // Set the clamping to .none in scrollViewDidEndScrollingAnimation
    // and scrollViewDidEndDragging with decelerate == false,
    // to prevent the bug introduced by the workaround in
    // scrollViewDidEndDecelerating where the scrollview contentOffset
    // is animated. When animating the contentOffset, scrollViewDidScroll
    // is called without calling scrollViewDidEndDecelerating afterwards.
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        clamping = .none
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate { return }
        clamping = .none
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {

        clamping = .none

        let previousIndex = index
        
        let offset:CGFloat = {
            if self.readingProgression == .rtl {
                return scrollView.contentSize.width - (scrollView.contentOffset.x + scrollView.frame.width)
            }
            return scrollView.contentOffset.x
        } ()
        
        let pageOffset = Int(round(offset / scrollView.frame.width))

        if pageOffset == 0 {
            if index > 0 {
                index -= 1
            }
        } else if pageOffset == 1 {
            if index == 0 {
                index += 1
            }
        } else {
            assert(pageOffset == 2)
            index += 1
        }

        updateViews(previousIndex: previousIndex)
        
        // This works around a very specific case that may be a bug in iOS's scroll
        // view implementation. If the user is on a view of index >= 1, and if the
        // user swipes forward slightly and then, with great force, swipes back and
        // quickly lets go, the scroll view will slam up against the clamped
        // boundary and "bounce" even if bouncing is disabled. The reason for this
        // is unclear! In any case, the following code compensates for this by
        // animating a transition to a content offset on a page boundary if, for any
        // reason (including the above), the scroll view has come rest on an offset
        // that is _not_ a page boundary. The conditional guard here prevents
        // animating if the offset is already correct because otherwise doing so may
        // result in a visual glitch (also for unknown reasons).
        if(fmod(scrollView.contentOffset.x, scrollView.frame.width) != 0.0) {
            
            let adjustedOffset:CGFloat = {
                if self.readingProgression == .rtl {
                    return scrollView.contentSize.width - CGFloat(pageOffset + 1) * scrollView.frame.width
                } else {
                    return CGFloat(pageOffset) * scrollView.frame.width
                }
            } ()
            
            scrollView.setContentOffset(
                .init(x: adjustedOffset, y: 0),
                animated: true)
        }
    }
}
