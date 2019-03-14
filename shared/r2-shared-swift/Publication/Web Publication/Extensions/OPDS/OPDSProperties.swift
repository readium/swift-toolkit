//
//  OPDSProperties.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// OPDS Link Properties Extension
/// https://drafts.opds.io/schema/properties.schema.json
protocol OPDSProperties {
    
    /// Provides a hint about the expected number of items returned.
    var numberOfItems: Int? { get set }
    
    /// The price of a publication is tied to its acquisition link.
    var price: OPDSPrice? { get set }
    
    /// Indirect acquisition provides a hint for the expected media type that will be acquired after additional steps.
    var indirectAcquisition: [OPDSAcquisition] { get set }
    
}


private let numberOfItemsKey = "numberOfItems"
private let priceKey = "price"
private let indirectAcquisitionKey = "indirectAcquisition"

extension Properties: OPDSProperties {
    
    public var numberOfItems: Int? {
        get { return parsePositive(otherProperties[numberOfItemsKey]) }
        set {
            if let numberOfItems = newValue {
                otherProperties[numberOfItemsKey] = numberOfItems
            } else {
                otherProperties.removeValue(forKey: numberOfItemsKey)
            }
        }
    }
    
    public var price: OPDSPrice? {
        get {
            do {
                return try OPDSPrice(json: otherProperties[priceKey])
            } catch {
                log(.warning, error)
                return nil
            }
        }
        set { setProperty(newValue?.json, forKey: priceKey) }
    }
    
    public var indirectAcquisition: [OPDSAcquisition] {
        get { return [OPDSAcquisition](json: otherProperties[indirectAcquisitionKey]) }
        set { setProperty(newValue.json, forKey: indirectAcquisitionKey) }
    }
    
}
