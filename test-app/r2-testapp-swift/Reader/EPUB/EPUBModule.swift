//
//  EPUB.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 22.02.19.
//
//  Copyright 2019 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared


final class EPUBModule: ReaderFormatModule {
    
    weak var delegate: ReaderFormatModuleDelegate?
    
    init(delegate: ReaderFormatModuleDelegate?) {
        self.delegate = delegate
    }

    var publicationType: [PublicationType] {
        return [.epub]
    }
    
    func makeReaderViewController(for publication: Publication, drm: DRM?) throws -> UIViewController {
        guard let publicationIdentifier = publication.metadata.identifier else {
            throw AppError.message("Invalid EPUB file")
        }
        
        // Retrieve last read document/progression in that document.
        let userDefaults = UserDefaults.standard
        let index = userDefaults.integer(forKey: "\(publicationIdentifier)-document")
        let progression = userDefaults.double(forKey: "\(publicationIdentifier)-documentProgression")

        let epubViewController = EpubViewController(publication: publication, atIndex: index, progression: progression, drm)
        epubViewController.moduleDelegate = delegate
        return epubViewController
    }
    
}
