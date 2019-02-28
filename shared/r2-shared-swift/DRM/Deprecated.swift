//
//  Deprecated.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 19.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


@available(*, deprecated, renamed: "DRM")
public typealias Drm = DRM

@available(*, deprecated, renamed: "DRMLicense")
public typealias DrmLicense = DRMLicense


extension DRM {

    @available(*, deprecated, message: "Use `license?.encryptionProfile` instead")
    public var profile: String? {
        return license?.encryptionProfile
    }
    
}


extension DRMLicense {
    
    @available(*, deprecated, message: "Use `LCPLicense.renewLoan` instead")
    public func renew(endDate: Date?, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    @available(*, deprecated, message: "Use `LCPLicense.returnPublication` instead")
    public func `return`(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    @available(*, deprecated, message: "Checking for the rights is handled by r2-lcp-swift now")
    public func areRightsValid() throws {}
    
    @available(*, deprecated, message: "Registering the device is handled by r2-lcp-swift now")
    public func register() {}
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func currentStatus() -> String {
        return ""
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func lastUpdate() -> Date {
        return Date()
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func issued() -> Date {
        return Date()
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func provider() -> URL {
        return URL(fileURLWithPath: "/")
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func rightsEnd() -> Date? {
        return nil
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func potentialRightsEnd() -> Date? {
        return nil
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func rightsStart() -> Date? {
        return nil
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func rightsPrints() -> Int? {
        return nil
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func rightsCopies() -> Int? {
        return nil
    }
    
}
