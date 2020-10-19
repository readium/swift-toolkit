//
//  OPDSModule.swift
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


/// The OPDS module handles the presentation of OPDS catalogs.
protocol OPDSModuleAPI {
    
    var delegate: OPDSModuleDelegate? { get }
    
    /// Root navigation controller containing the OPDS catalogs.
    /// Can be used to present the OPDS catalogs to the user.
    var rootViewController: UINavigationController { get }
    
}

protocol OPDSModuleDelegate: ModuleDelegate {
    
    /// Called when an OPDS publication needs to be downloaded.
    func opdsDownloadPublication(_ publication: Publication?, at link: Link, sender: UIViewController, completion: @escaping (CancellableResult<Book, Error>) -> Void)

}


final class OPDSModule: OPDSModuleAPI {
    
    weak var delegate: OPDSModuleDelegate?
    
    private let factory = OPDSFactory.shared
    
    init(delegate: OPDSModuleDelegate?) {
        self.delegate = delegate
        factory.delegate = delegate
    }
    
    private(set) lazy var rootViewController: UINavigationController = {
        let catalogViewController: OPDSCatalogSelectorViewController = factory.make()
        return UINavigationController(rootViewController: catalogViewController)
    }()
    
}
