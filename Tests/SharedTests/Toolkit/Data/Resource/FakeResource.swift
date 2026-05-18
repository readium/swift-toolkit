//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A `Resource` that returns configurable data for testing.
actor FakeResource: Resource {
    let sourceURL: (any AbsoluteURL)?

    private let _properties: ReadResult<ResourceProperties>
    private let _estimatedLength: ReadResult<UInt64?>

    init(
        sourceURL: (any AbsoluteURL)? = nil,
        properties: ReadResult<ResourceProperties> = .success(ResourceProperties()),
        estimatedLength: ReadResult<UInt64?> = .success(nil)
    ) {
        self.sourceURL = sourceURL
        _properties = properties
        _estimatedLength = estimatedLength
    }

    func estimatedLength() async -> ReadResult<UInt64?> {
        _estimatedLength
    }

    func properties() async -> ReadResult<ResourceProperties> {
        _properties
    }

    func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        consume(Data())
        return .success(())
    }
}
