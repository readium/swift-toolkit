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
import PDFKit
import R2Shared


/// A view controller used to render a PDF `Publication`.
@available(iOS 11.0, *)
open class PDFNavigatorViewController: UIViewController, Loggable {
    
    enum Error: Swift.Error {
        case openPDFFailed
    }
    
    public let publication: Publication
    
    public private(set) var pdfView: PDFView!

    public init(publication: Publication) {
        self.publication = publication
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        pdfView = PDFView(frame: view.bounds)
        pdfView.autoScales = true
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pdfView)
        
        if let link = publication.readingOrder.first {
            load(link)
        }
    }
    
    /// Loads `Link` resource into the PDF view.
    func load(_ link: Link) {
        guard let url = publication.uriTo(link: link),
            let document = PDFDocument(url: url) else
        {
            log(.error, "Can't open PDF document at \(link)")
            return
        }
        
        pdfView.document = document
    }
    
}
