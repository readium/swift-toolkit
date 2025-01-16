//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Transforms a ``Manifest``'s components.
public protocol ManifestTransformer {
    func transform(manifest: inout Manifest) throws
    func transform(metadata: inout Metadata) throws
    func transform(link: inout Link) throws
}

public protocol ManifestTransformable {
    mutating func transform(_ transformer: ManifestTransformer) throws
}

public extension ManifestTransformer {
    func transform(manifest: inout Manifest) throws {}
    func transform(metadata: inout Metadata) throws {}
    func transform(link: inout Link) throws {}
}

extension Manifest: ManifestTransformable {
    /// Transforms the receiver ``Manifest``, applying the given `transformer`
    /// to each component.
    public mutating func transform(_ transformer: ManifestTransformer) throws {
        try metadata.transform(transformer)
        try links.transform(transformer)
        try readingOrder.transform(transformer)
        try resources.transform(transformer)
        try tableOfContents.transform(transformer)
        try subcollections.transform(transformer)

        try transformer.transform(manifest: &self)
    }
}

extension Metadata: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) throws {
        try subjects.transform(transformer)
        try authors.transform(transformer)
        try translators.transform(transformer)
        try editors.transform(transformer)
        try artists.transform(transformer)
        try illustrators.transform(transformer)
        try letterers.transform(transformer)
        try pencilers.transform(transformer)
        try colorists.transform(transformer)
        try inkers.transform(transformer)
        try narrators.transform(transformer)
        try contributors.transform(transformer)
        try publishers.transform(transformer)
        try imprints.transform(transformer)
        try belongsTo.transform(transformer)

        try transformer.transform(metadata: &self)
    }
}

extension PublicationCollection: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) throws {
        try links.transform(transformer)
        try subcollections.transform(transformer)
    }
}

extension Contributor: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) throws {
        try links.transform(transformer)
    }
}

extension Subject: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) throws {
        try links.transform(transformer)
    }
}

extension Link: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) throws {
        try alternates.transform(transformer)
        try children.transform(transformer)

        try transformer.transform(link: &self)
    }
}

extension Array: ManifestTransformable where Element: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) throws {
        self = try map {
            var copy = $0
            try copy.transform(transformer)
            return copy
        }
    }
}

extension Dictionary: ManifestTransformable where Value: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) throws {
        self = try mapValues {
            var copy = $0
            try copy.transform(transformer)
            return copy
        }
    }
}
