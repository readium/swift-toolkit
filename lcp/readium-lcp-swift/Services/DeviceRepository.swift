//
//  DeviceRepository.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 07.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//


import Foundation

protocol DeviceRepository {
    
    func isDeviceRegistered(for license: LicenseDocument) throws -> Bool
    func registerDevice(for license: LicenseDocument) throws

}
