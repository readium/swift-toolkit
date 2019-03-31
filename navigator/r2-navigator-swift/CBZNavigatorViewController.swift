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


/// A ViewController with hooks in order to render a CBZ `Publication`.
/// Provides the following hooks:
/// - Properties
///     - <> publication - The publication rendered in the viewController.
///     - pageNumber - The number of the page currently rendered.
///     - totalPageNumber - The number of pages in the publication.
/// - Methods
///     - loadNext() - render the next resource item, if any.
///     - loadPrevious() - render the previous resource item, if any.
///     - load(at index: Int) - render the resource item at index, if any.
///
open class CBZNavigatorViewController: UIViewController {
    public var publication: Publication
    public var pageNumber: Int
    public var totalPageNumber: Int
    public var scrollView: UIScrollView!
    var imageView: UIImageView!

    /// Initialize the renderer.
    ///
    /// - Parameters:
    ///   - publication: The CBZ publication to render.
    ///   - initialIndex: Set to -1 for 0 or last Index read.
    public init(for publication: Publication, initialIndex: Int = 0) {
        self.publication = publication
        pageNumber = initialIndex
        totalPageNumber = publication.readingOrder.count
        super.init(nibName: nil, bundle: nil)
        automaticallyAdjustsScrollViewInsets = false
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func loadView() {
        scrollView = UIScrollView()
        scrollView.backgroundColor = UIColor.black
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view = scrollView
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 2.0
        scrollView.zoomScale = 1.0
        // Imageview.
        imageView = UIImageView(frame: self.scrollView.bounds)
        imageView.backgroundColor = UIColor.black
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(self.imageView)
        // Load content.
        load(self.currentReadingOrderItem())
    }
}

extension CBZNavigatorViewController {

    @objc public func loadNext() {
        load(nextReadingOrderItem())
    }

    @objc public func loadPrevious() {
        load(previousReadingOrderItem())
    }

    /// Load resource at given index.
    ///
    /// - Parameter index: The index of the resource to load.
    public func load(at index: Int) {
        load(readingOrderItem(at: index))
    }

    /// Load `link` resource into the ImageView.
    /// From PublicationRenderingView protocol.
    ///
    /// - Parameter link: The resource to render.
    func load(_ link: Link?) {
        guard let link = link, let url = publication.url(to: link) else {
            return
        }
        getDataFromUrl(url: url) { (data, response, error)  in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async {
                UIView.transition(with: self.imageView,
                                  duration: 0.1618,
                                  options: .transitionCrossDissolve,
                                  animations: {
                                    guard let image = UIImage(data: data) else {
                                        return
                                    }
                                    self.imageView.image = image
                },
                                  completion: nil)
            }
        }
    }


    func getDataFromUrl(url: URL, completion: @escaping (_ data: Data?, _  response: HTTPURLResponse?, _ error: Error?) -> Void) {
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            completion(data, response as? HTTPURLResponse, error)
            }.resume()
    }

    /// Return the current readingOrder item.
    ///
    /// - Returns: The current readingOrder item.
    fileprivate func currentReadingOrderItem() -> Link? {
        return publication.readingOrder[pageNumber]
    }

    /// Return the next readingOrder item, if any, and move the index.
    ///
    /// - Returns: The next readingOrder item regarding current index.
    fileprivate func nextReadingOrderItem(updateIndex: Bool = true) -> Link? {
        let newIndex = pageNumber.advanced(by: 1)

        guard publication.readingOrder.indices.contains(newIndex) else {
            return nil
        }
        if updateIndex {
            pageNumber = newIndex
        }
        return publication.readingOrder[newIndex]
    }

    /// Return the previous readingOrder item, if any, and move the index.
    ///
    /// - Returns: The previous readingOrder item regarding current index.
    fileprivate func previousReadingOrderItem(updateIndex: Bool = true) -> Link? {
        let newIndex = pageNumber.advanced(by: -1)

        guard publication.readingOrder.indices.contains(newIndex) else {
            return nil
        }
        if updateIndex {
            pageNumber = newIndex
        }
        return publication.readingOrder[newIndex]
    }

    /// Safely return the readingOrder at index if any.
    ///
    /// - Parameter index: The index of the desired readingOrder item.
    /// - Returns: The readingOrder item if any.
    fileprivate func readingOrderItem(at index: Int, updateIndex: Bool = true) -> Link? {
        guard publication.readingOrder.indices.contains(index) else {
            return nil
        }
        if updateIndex {
            pageNumber = index
        }
        return publication.readingOrder[index]
    }
}

extension CBZNavigatorViewController: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}


@available(*, deprecated, renamed: "CBZNavigatorViewController")
public typealias CbzNavigatorViewController = CBZNavigatorViewController
