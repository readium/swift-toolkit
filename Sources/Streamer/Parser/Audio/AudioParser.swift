//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Parses an audiobook Publication from an unstructured archive format containing audio files,
/// such as ZAB (Zipped Audio Book) or a simple ZIP.
///
/// It can also work for a standalone audio file.
public final class AudioParser: PublicationParser {
    
    public init() {}
    
    public func parse(asset: PublicationAsset, fetcher: Fetcher, warnings: WarningLogger?) throws -> Publication.Builder? {
        guard accepts(asset, fetcher) else {
            return nil
        }
        
        let readingOrder = fetcher.links
            .filter { !ignores($0) && $0.mediaType.isAudio }
            .sorted { $0.href.localizedCaseInsensitiveCompare($1.href) == .orderedAscending }
        
        guard !readingOrder.isEmpty else {
            return nil
        }
        
        return Publication.Builder(
            mediaType: .zab,
            format: .cbz,
            manifest: Manifest(
                metadata: Metadata(
                    conformsTo: [.audiobook],
                    title: fetcher.guessTitle(ignoring: ignores) ?? asset.name
                ),
                readingOrder: readingOrder
            ),
            fetcher: fetcher,
            servicesBuilder: .init(
                locator: AudioLocatorService.makeFactory()
            )
        )
    }
    
    private func accepts(_ asset: PublicationAsset, _ fetcher: Fetcher) -> Bool {
        if asset.mediaType() == .zab {
            return true
        }
        
        // Checks if the fetcher contains only bitmap-based resources.
        return !fetcher.links.isEmpty
            && fetcher.links.allSatisfy { ignores($0) || $0.mediaType.isAudio }
    }
    
    private func ignores(_ link: Link) -> Bool {
        let url = URL(fileURLWithPath: link.href)
        let filename = url.lastPathComponent
        let allowedExtensions = ["asx", "bio", "m3u", "m3u8", "pla", "pls", "smil", "txt", "vlc", "wpl", "xspf", "zpl"]
        
        return allowedExtensions.contains(url.pathExtension.lowercased())
            || filename.hasPrefix(".")
            || filename == "Thumbs.db"
    }
    
    @available(*, unavailable, message: "Not supported for `AudioParser`")
    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        fatalError("Not supported for `AudioParser`")
    }
    
}
