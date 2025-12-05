//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public protocol AssetProtocol: Closeable {
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
        get {
            switch self {
            case let .resource(asset):
                return asset.format
            case let .container(asset):
                return asset.format
            }
        }
        set {
            switch self {
            case var .resource(asset):
                asset.format = newValue
                self = .resource(asset)
            case var .container(asset):
                asset.format = newValue
                self = .container(asset)
            }
        }
    }
}

/// A single resource asset.
public struct ResourceAsset: AssetProtocol {
    public var resource: Resource
    public var format: Format

    public init(resource: Resource, format: Format) {
        self.resource = resource
        self.format = format
    }
}

/// A container asset providing access to several resources.
public struct ContainerAsset: AssetProtocol {
    public var container: Container
    public var format: Format

    public init(container: Container, format: Format) {
        self.container = container
        self.format = format
    }
}
