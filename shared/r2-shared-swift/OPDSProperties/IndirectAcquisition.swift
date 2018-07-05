//
//  IndirectAcquisition.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public class IndirectAcquisition {
    public var typeAcquisition: String
    public var child = [IndirectAcquisition]()
    
    public init(typeAcquisition: String) {
        self.typeAcquisition = typeAcquisition
    }
}

// MARK: - Parsing related errors
public enum IndirectAcquisitionError: Error {
    case invalidIndirectAcquisition
    
    var localizedDescription: String {
        switch self {
        case .invalidIndirectAcquisition:
            return "Invalid indirect acquisition"
        }
    }
}

// MARK: - Parsing related methods
extension IndirectAcquisition {
    
    static public func parse(indirectAcquisitionDict: [String: Any]) throws -> IndirectAcquisition {
        guard let iaType = indirectAcquisitionDict["type"] as? String else {
            throw IndirectAcquisitionError.invalidIndirectAcquisition
        }
        let ia = IndirectAcquisition(typeAcquisition: iaType)
        for (k, v) in indirectAcquisitionDict {
            if (k == "child") {
                guard let childArray = v as? [[String: Any]] else {
                    throw IndirectAcquisitionError.invalidIndirectAcquisition
                }
                for childDict in childArray {
                    let child = try parse(indirectAcquisitionDict: childDict)
                    ia.child.append(child)
                }
            }
        }
        return ia
    }
    
}
