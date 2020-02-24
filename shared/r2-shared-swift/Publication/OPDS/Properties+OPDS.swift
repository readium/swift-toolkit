//
//  Properties+OPDS.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

private let numberOfItemsKey = "numberOfItems"
private let priceKey = "price"
private let indirectAcquisitionKey = "indirectAcquisition"

/// OPDS Link Properties Extension
/// https://drafts.opds.io/schema/properties.schema.json
extension Properties {
    
    /// Provides a hint about the expected number of items returned.
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
    
    /// The price of a publication is tied to its acquisition link.
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
    
    /// Indirect acquisition provides a hint for the expected media type that will be acquired after
    /// additional steps.
    public var indirectAcquisitions: [OPDSAcquisition] {
        get { return [OPDSAcquisition](json: otherProperties[indirectAcquisitionKey]) }
        set { setProperty(newValue.json, forKey: indirectAcquisitionKey) }
    }
    
    /// Library-specific features when a specific book is unavailable but provides a hold list.
    public var holds: OPDSHolds? {
        do {
            return try OPDSHolds(json: otherProperties["holds"])
        } catch {
            log(.warning, error)
            return nil
        }
    }
    
    /// Library-specific feature that contains information about the copies that a library has
    /// acquired.
    public var copies: OPDSCopies? {
        do {
            return try OPDSCopies(json: otherProperties["copies"])
        } catch {
            log(.warning, error)
            return nil
        }
    }
    
    /// Indicated the availability of a given resource.
    public var availability: OPDSAvailability? {
        do {
            return try OPDSAvailability(json: otherProperties["availability"])
        } catch {
            log(.warning, error)
            return nil
        }
    }
    
}
