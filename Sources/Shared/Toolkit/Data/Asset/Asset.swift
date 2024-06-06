//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public protocol AssetProtocol: AsyncCloseable {

    /// Format of the asset.
    var format: Format { get }
}

/// An asset which is either a single resource or a container that holds
/// multiple resources.
public enum Asset: AssetProtocol {
    case resource(ResourceAsset)
    case container(ContainerAsset)

    /// Format of the asset.
    public var format: Format {
        switch self {
        case .resource(let asset):
            return asset.format
        case .container(let asset):
            return asset.format
        }
    }
    
    public func close() async {
        switch self {
        case .resource(let asset):
            await asset.close()
        case .container(let asset):
            await asset.close()
        }
    }
}

/// A single resource asset.
public struct ResourceAsset: AssetProtocol {
    public let resource: Resource
    public let format: Format
    
    public func close() async {
        await resource.close()
    }
}

/// A container asset providing access to several resources.
public struct ContainerAsset: AssetProtocol {
    public let container: Container
    public let format: Format
    
    public init(container: Container, format: Format) {
        self.container = container
        self.format = format
    }
    
    public func close() async {
        await container.close()
    }
}
