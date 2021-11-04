//
//  UserRights.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 16/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Manages consumption of user rights and permissions.
public protocol UserRights {
    
    /// Returns whether the user is currently allowed to copy content to the pasteboard.
    ///
    /// Navigators and reading apps can use this to know if the "Copy" action should be greyed
    /// out or not. This should be called every time the "Copy" action will be displayed,
    /// because the value might change during runtime.
    var canCopy: Bool { get }

    /// Returns whether the user is allowed to copy the given text to the pasteboard.
    ///
    /// This is more specific than the `canCopy` property, and can return `false` if the given text
    /// exceeds the allowed amount of characters to copy.
    ///
    /// To be used before presenting, for example, a pop-up to share a selected portion of
    /// content.
    func canCopy(text: String) -> Bool

    /// Consumes the given text with the copy right.
    ///
    /// Returns whether the user is allowed to copy the given text.
    func copy(text: String) -> Bool

    /// Returns whether the user is currently allowed to print the content.
    ///
    /// Navigators and reading apps can use this to know if the "Print" action should be greyed
    /// out or not.
    var canPrint: Bool { get }

    /// Returns whether the user is allowed to print the given amount of pages.
    ///
    /// This is more specific than the `canPrint` property, and can return `false` if the given
    /// `pageCount` exceeds the allowed amount of pages to print.
    ///
    /// To be used before attempting to launch a print job, for example.
    func canPrint(pageCount: Int) -> Bool

    /// Consumes the given amount of pages with the print right.
    ///
    /// Returns whether the user is allowed to print the given amount of pages.
    func print(pageCount: Int) -> Bool
    
}

/// A `UserRights` without any restriction.
public class UnrestrictedUserRights: UserRights {
    
    public init() {}
    
    public var canCopy: Bool { true }
    public func canCopy(text: String) -> Bool { true }
    public func copy(text: String) -> Bool { true }
    
    public var canPrint: Bool { true }
    public func canPrint(pageCount: Int) -> Bool { true }
    public func print(pageCount: Int) -> Bool { true }
    
}

/// A `UserRights` which forbids all rights.
public class AllRestrictedUserRights: UserRights {
    
    public init() {}
    
    public var canCopy: Bool { false }
    public func canCopy(text: String) -> Bool { false }
    public func copy(text: String) -> Bool { false }
    
    public var canPrint: Bool { false }
    public func canPrint(pageCount: Int) -> Bool { false }
    public func print(pageCount: Int) -> Bool { false }
    
}
