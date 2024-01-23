//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Transforms a ``Manifest``'s components.
public protocol ManifestTransformer {
    func transform(manifest: inout Manifest)
    func transform(metadata: inout Metadata)
    func transform(link: inout Link)
}

public protocol ManifestTransformable {
    mutating func transform(_ transformer: ManifestTransformer)
}

public extension ManifestTransformer {
    func transform(manifest: inout Manifest) {}
    func transform(metadata: inout Metadata) {}
    func transform(link: inout Link) {}
}

extension Manifest: ManifestTransformable {
    /// Transforms the receiver ``Manifest``, applying the given `transformer`
    /// to each component.
    public mutating func transform(_ transformer: ManifestTransformer) {
        metadata.transform(transformer)
        links.transform(transformer)
        readingOrder.transform(transformer)
        resources.transform(transformer)
        tableOfContents.transform(transformer)
        subcollections.transform(transformer)

        transformer.transform(manifest: &self)
    }
}

extension Metadata: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) {
        subjects.transform(transformer)
        authors.transform(transformer)
        translators.transform(transformer)
        editors.transform(transformer)
        artists.transform(transformer)
        illustrators.transform(transformer)
        letterers.transform(transformer)
        pencilers.transform(transformer)
        colorists.transform(transformer)
        inkers.transform(transformer)
        narrators.transform(transformer)
        contributors.transform(transformer)
        publishers.transform(transformer)
        imprints.transform(transformer)
        belongsTo.transform(transformer)

        transformer.transform(metadata: &self)
    }
}

extension PublicationCollection: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) {
        links.transform(transformer)
        subcollections.transform(transformer)
    }
}

extension Contributor: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) {
        links.transform(transformer)
    }
}

extension Subject: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) {
        links.transform(transformer)
    }
}

extension Link: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) {
        alternates.transform(transformer)
        children.transform(transformer)

        transformer.transform(link: &self)
    }
}

extension Array: ManifestTransformable where Element: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) {
        self = map {
            var copy = $0
            copy.transform(transformer)
            return copy
        }
    }
}

extension Dictionary: ManifestTransformable where Value: ManifestTransformable {
    public mutating func transform(_ transformer: ManifestTransformer) {
        self = mapValues {
            var copy = $0
            copy.transform(transformer)
            return copy
        }
    }
}
