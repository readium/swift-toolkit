//
//  ContentProtectionService.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 16/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public typealias ContentProtectionServiceFactory = (PublicationServiceContext) -> ContentProtectionService?

/// Provides information about a publication's content protection and manages user rights.
public protocol ContentProtectionService: PublicationService {
    
    /// Indicates whether the `Publication` has a restricted access to its resources, and can't be
    /// rendered in a Navigator.
    var isRestricted: Bool { get }
    
    /// The error raised when trying to unlock the `Publication`, if any.
    ///
    /// This can be used by a Content Protection to return a status error, for example if a
    /// publication is expired or revoked. Reading apps should present this error to the user when
    /// attempting to render a restricted `Publication` with a navigator.
    var error: Error? { get }
    
    /// Credentials used to unlock this `Publication`.
    ///
    /// If provided, reading apps may store the credentials in a secure location, to reuse them the
    /// next time the user opens the publication.
    var credentials: String? { get }
    
    /// Manages consumption of user rights and permissions.
    var rights: UserRights { get }
    
    /// User-facing localized name for this Content Protection, e.g. "Readium LCP".
    ///
    /// It could be used in a sentence such as "Protected by {name}".
    var name: LocalizedString? { get }
    
}

public extension ContentProtectionService {
    
    var credentials: String? { nil }
    
    var rights: UserRights { UnrestrictedUserRights() }
    
    var name: LocalizedString? { nil }
    
}


// MARK: Publication Helpers

public extension Publication {
    
    /// Indicates whether this `Publication` is protected by a Content Protection technology.
    var isProtected: Bool {
        contentProtectionService != nil
    }
    
    /// Indicates whether the `Publication` has a restricted access to its resources, and can't be
    /// rendered in a Navigator.
    var isRestricted: Bool {
        contentProtectionService?.isRestricted == true
    }
    
    /// The error raised when trying to unlock the `Publication`, if any.
    ///
    /// This can be used by a Content Protection to return a status error, for example if a
    /// publication is expired or revoked. Reading apps should present this error to the user when
    /// attempting to render a restricted `Publication` with a navigator.
    var protectionError: Error? {
        contentProtectionService?.error
    }
    
    /// Credentials used to unlock this `Publication`.
    ///
    /// If provided, reading apps may store the credentials in a secure location, to reuse them the
    /// next time the user opens the publication.
    var credentials: String? {
        contentProtectionService?.credentials
    }
    
    /// Manages consumption of user rights and permissions.
    var rights: UserRights {
        contentProtectionService?.rights ?? UnrestrictedUserRights()
    }
    
    /// User-facing localized name for this Content Protection, e.g. "Readium LCP".
    ///
    /// It could be used in a sentence such as "Protected by {name}".
    var protectionLocalizedName: LocalizedString? {
        contentProtectionService?.name
    }
    
    /// User-facing name for this Content Protection, e.g. "Readium LCP".
    ///
    /// It could be used in a sentence such as "Protected by {name}".
    var protectionName: String? {
        contentProtectionService?.name?.string
    }

    private var contentProtectionService: ContentProtectionService? {
        findService(ContentProtectionService.self)
    }
    
}


// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {
    
    mutating func setContentProtectionServiceFactory(_ factory: ContentProtectionServiceFactory?) {
        if let factory = factory {
            set(ContentProtectionService.self, factory)
        } else {
            remove(ContentProtectionService.self)
        }
    }
    
}
