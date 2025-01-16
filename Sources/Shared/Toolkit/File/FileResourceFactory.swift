//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Creates ``FileResource`` instances granting access to `file://` URLs stored
/// on the file system.
public class FileResourceFactory: ResourceFactory {
    public func make(url: any AbsoluteURL) async -> Result<any Resource, ResourceMakeError> {
        guard let file = url.fileURL else {
            return .failure(.schemeNotSupported(url.scheme))
        }
        return .success(FileResource(file: file))
    }
}
