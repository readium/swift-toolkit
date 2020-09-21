//
//  CBZModule.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 22.02.19.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared


final class CBZModule: ReaderFormatModule {
    
    weak var delegate: ReaderFormatModuleDelegate?
    
    init(delegate: ReaderFormatModuleDelegate?) {
        self.delegate = delegate
    }
    
    var publicationFormats: [Publication.Format] {
        return [.cbz]
    }
    
    func makeReaderViewController(for publication: Publication, book: Book, resourcesServer: ResourcesServer) throws -> UIViewController {
        let cbzVC = CBZViewController(publication: publication, book: book)
        cbzVC.moduleDelegate = self.delegate
        return cbzVC
    }

}
