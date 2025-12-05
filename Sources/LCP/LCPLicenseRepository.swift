//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// The license repository stores registered licenses with their consumed rights (e.g. copy).
public protocol LCPLicenseRepository {
    /// Adds a new `licenseDocument` to the repository, using `licenseDocument.id` as the
    /// primary key.
    ///
    /// ## Implementation notes:
    ///
    /// * When adding a license for the first time, you **must** initialize the consumable user rights with
    /// `licenseDocument.rights`.
    /// * If the license already exists in the repository, it is updated **without overwriting** the existing
    /// consumable user rights.
    func addLicense(_ licenseDocument: LicenseDocument) async throws

    /// Returns the `LicenseDocument` saved with the given `id`.
    func license(for id: LicenseDocument.ID) async throws -> LicenseDocument?

    /// Returns whether the device is already registered for the license with given `id` .
    func isDeviceRegistered(for id: LicenseDocument.ID) async throws -> Bool

    /// Marks the device as registered for the license with given `id`.
    func registerDevice(for id: LicenseDocument.ID) async throws

    /// Returns the consumable user rights for the license with given `id`.
    func userRights(for id: LicenseDocument.ID) async throws -> LCPConsumableUserRights

    /// Updates the consumable user rights for the license with given `id`.
    func updateUserRights(
        for id: LicenseDocument.ID,
        with changes: (inout LCPConsumableUserRights) -> Void
    ) async throws
}

/// Holds the current state of consumable user rights for a license.
public struct LCPConsumableUserRights {
    /// Maximum number of pages left to be printed.
    ///
    /// If `nil`, there is no limit.
    public var print: Int?

    /// Maximum number of characters left to be copied to the clipboard.
    ///
    /// If `nil`, there is no limit.
    public var copy: Int?

    public init(print: Int?, copy: Int?) {
        self.print = print
        self.copy = copy
    }
}
