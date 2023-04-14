//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

protocol DeviceRepository {
    func isDeviceRegistered(for license: LicenseDocument) throws -> Bool
    func registerDevice(for license: LicenseDocument) throws
}
