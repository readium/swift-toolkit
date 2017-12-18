//
//  TriptychView.swift
//  r2-navigator-swift
//
//  Created by Winnie Quinn, Alexandre Camilleri on 8/23/17.
//  Copyright © 2017 Readium.
//  This file is covered by the LICENSE file in the root of this project.
//

import UIKit

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

    fileprivate(set) var index: Int

    fileprivate let scrollView: UIScrollView

    public let viewCount: Int

    internal var views: Views?

    fileprivate var clamping: Clamping = .none

    private var isAtAnEdge: Bool {
        return index == 0 || index == viewCount - 1
    }

    public init(frame: CGRect, viewCount: Int, initialIndex: Int) {

        precondition(viewCount >= 1)
        precondition(initialIndex >= 0 && initialIndex < viewCount)

        index = initialIndex
        scrollView = UIScrollView()
        self.viewCount = viewCount

        super.init(frame: frame)

        scrollView.delegate = self
        scrollView.frame = bounds
        scrollView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        scrollView.isPagingEnabled = true
        scrollView.bounces = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
    }

    deinit {
        guard let views = views else {
            return
        }
        for view in views.array {
            if let webview = (view as? WebView) {
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

        for (index, view) in views.array.enumerated() {
            view.frame = CGRect(origin: CGPoint(x: size.width * CGFloat(index), y: 0), size: size)
        }

        let offset = min(1, index)
        scrollView.contentOffset.x = size.width * CGFloat(offset)
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
                indexesToCurrentViews[0] = firstView
                indexesToCurrentViews[1] = secondView
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
            let view = viewForIndex(0, location: .beginning)
            views = Views.one(view: view)
        case 2:
            assert(index < 2)
            if index == 0 {
                let firstView = viewForIndex(0, location: .beginning)
                let secondView = viewForIndex(1, location: .beginning)
                views = Views.two(firstView: firstView, secondView: secondView)
            } else {
                let firstView = viewForIndex(0, location: .end)
                let secondView = viewForIndex(1, location: .beginning)
                views = Views.two(firstView: firstView, secondView: secondView)
            }
        default:
            let currentView = viewForIndex(index, location: .beginning)
            if index == 0 {
                self.views = Views.many(
                    currentView: currentView,
                    otherViews: Disjunction.second(value:
                        viewForIndex(index + 1, location: .beginning)))
            } else if index == viewCount - 1 {
                views = Views.many(
                    currentView: currentView,
                    otherViews: Disjunction.first(value:
                        viewForIndex(index - 1, location: .end)))
            } else {
                views = Views.many(
                    currentView: currentView,
                    otherViews: Disjunction.both(
                        first: viewForIndex(index - 1, location: .end),
                        second: viewForIndex(index + 1, location: .beginning)))
            }
        }

        delegate.viewsDidUpdate(documentIndex: index)
    
        syncSubviews()
        setNeedsLayout()
    }

    private func syncSubviews() {
        scrollView.subviews.forEach({
            if let webview = ($0 as? WebView) {
                webview.removeMessageHandlers()
            }
            $0.removeFromSuperview()
        })

        if let viewArray = views?.array {
            viewArray.forEach({
                if let webview = ($0 as? WebView) {
                    webview.addMessageHandlers()
                }
                self.scrollView.addSubview($0)
            })
        }
    }
}

extension TriptychView {
    /// Move to the given index
    ///
    /// - Parameters:
    ///   - nextIndex: The index to move to.
    internal func moveTo(index nextIndex: Int, id: String? = nil) {
        var cw = currentView as! WebView

        guard index != nextIndex else {
            if let id = id {
                if id == "" {
                    cw.scrollAt(location: .beginning)
                } else {
                    cw.scrollAt(tagId: id)
                }
            }
            return
        }

        var currentRect = scrollView.contentOffset
        let currentFrameSize = scrollView.frame.size

        if index < nextIndex {
            currentRect.x += currentFrameSize.width
            scrollView.scrollRectToVisible(CGRect(origin: currentRect, size: currentFrameSize), animated: false)
            cw.scrollAt(location: .end)
        } else {
            currentRect.x -= currentFrameSize.width
            scrollView.scrollRectToVisible(CGRect(origin: currentRect, size: currentFrameSize), animated: false)
            cw.scrollAt(location: .beginning)
        }

        let previousIndex = index

        index = nextIndex
        clamping = .none
        updateViews(previousIndex: previousIndex)

        // get the new current view after change.
        cw = currentView as! WebView
        if let id = id {
            if id == "" {
                if abs(previousIndex - nextIndex) == 1 {
                    // if the view was adjacent and already loaded
                    cw.scrollAt(location: .beginning)
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

    /// Return the index of the document currently being displayed.
    public func getCurrentDocumentIndex() -> Int {
        return index
    }

    /// Returns the progression in the document currently being displayed.
    public func getCurrentDocumentProgression() -> Double? {
        guard currentView != nil else {
            return nil
        }
        return (currentView as! WebView).progression
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

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {

        clamping = .none

        let previousIndex = index

        let pageOffset = Int(round(scrollView.contentOffset.x / scrollView.frame.width))

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
            scrollView.setContentOffset(
                .init(x: CGFloat(pageOffset) * scrollView.frame.width, y: 0),
                animated: true)
        }
    }
}
