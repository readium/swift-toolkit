//
//  IndirectAcquisition.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

public class IndirectAcquisition {
    public var typeAcquisition: String
    public var child = [IndirectAcquisition]()
    
    public init(typeAcquisition: String) {
        self.typeAcquisition = typeAcquisition
    }
}
