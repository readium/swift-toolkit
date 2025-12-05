//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs bitmap formats.
public class BitmapFormatSniffer: FormatSniffer {
    public init() {}

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if hints.hasFileExtension("avif", "avifs") || hints.hasMediaType("image/avif") {
            return Format(specifications: .avif, mediaType: .avif, fileExtension: "avif")
        }
        if hints.hasFileExtension("bmp", "dib") || hints.hasMediaType("image/bmp", "image/x-bmp") {
            return Format(specifications: .bmp, mediaType: .bmp, fileExtension: "bmp")
        }
        if hints.hasFileExtension("gif") || hints.hasMediaType("image/gif") {
            return Format(specifications: .gif, mediaType: .gif, fileExtension: "gif")
        }
        if hints.hasFileExtension("jpg", "jpeg", "jpe", "jif", "jfif", "jfi") || hints.hasMediaType("image/jpeg") {
            return Format(specifications: .jpeg, mediaType: .jpeg, fileExtension: "jpg")
        }
        if hints.hasFileExtension("png") || hints.hasMediaType("image/png") {
            return Format(specifications: .png, mediaType: .png, fileExtension: "png")
        }
        if hints.hasFileExtension("tiff", "tif") || hints.hasMediaType("image/tiff", "image/tiff-fx") {
            return Format(specifications: .tiff, mediaType: .tiff, fileExtension: "tiff")
        }
        if hints.hasFileExtension("webp") || hints.hasMediaType("image/webp") {
            return Format(specifications: .webp, mediaType: .webp, fileExtension: "webp")
        }
        return nil
    }
}
