//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Manages consumption of user rights and permissions.
public protocol UserRights {
    /// Returns whether the user is allowed to copy the given text to the pasteboard.
    ///
    /// It may return `false` if the given text exceeds the allowed amount of characters to copy.
    ///
    /// To be used before presenting, for example, a pop-up to share a selected portion of
    /// content.
    func canCopy(text: String) async -> Bool

    /// Consumes the given text with the copy right.
    ///
    /// Returns whether the user is allowed to copy the given text.
    func copy(text: String) async -> Bool

    /// Returns whether the user is allowed to print the given amount of pages.
    ///
    /// It may return `false` if the given `pageCount` exceeds the allowed amount of pages to print.
    ///
    /// To be used before attempting to launch a print job, for example.
    func canPrint(pageCount: Int) async -> Bool

    /// Consumes the given amount of pages with the print right.
    ///
    /// Returns whether the user is allowed to print the given amount of pages.
    func print(pageCount: Int) async -> Bool
}

/// A `UserRights` without any restriction.
public class UnrestrictedUserRights: UserRights {
    public init() {}

    public func canCopy(text: String) async -> Bool { true }
    public func copy(text: String) async -> Bool { true }

    public func canPrint(pageCount: Int) async -> Bool { true }
    public func print(pageCount: Int) async -> Bool { true }
}

/// A `UserRights` which forbids all rights.
public class AllRestrictedUserRights: UserRights {
    public init() {}

    public func canCopy(text: String) async -> Bool { false }
    public func copy(text: String) async -> Bool { false }

    public func canPrint(pageCount: Int) async -> Bool { false }
    public func print(pageCount: Int) async -> Bool { false }
}
