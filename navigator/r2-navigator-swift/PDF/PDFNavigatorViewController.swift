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
import UIKit
import WebKit
import R2Shared


/// A view controller used to render a PDF `Publication`.
open class PDFNavigatorViewController: UIViewController {
    public let publication: Publication
    
    public var webView: WKWebView!
    
    public init(publication: Publication) {
        self.publication = publication
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        
        webView = WKWebView(frame: view.bounds)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
        
        load(publication.readingOrder.first)
    }
    
    /// Loads `Link` resource into the PDF view.
    func load(_ link: Link?) {
        guard let url = publication.uriTo(link: link) else {
            return
        }
        webView.load(URLRequest(url: url))
    }
    
}
