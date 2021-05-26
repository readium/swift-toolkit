//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

@available(*, unavailable, message: "Format and MediaType got merged together", renamed: "MediaType")
public typealias Format = MediaType
@available(*, unavailable, renamed: "MediaTypeSnifferContext")
public typealias FormatSnifferContext = MediaTypeSnifferContext

public extension MediaType {

    @available(*, unavailable,  message: "Format and MediaType got merged together")
    var mediaType: MediaType { self }

    @available(*, unavailable, renamed: "readiumAudiobook")
    static var audiobook: MediaType { readiumAudiobook }
    @available(*, unavailable, renamed: "readiumAudiobookManifest")
    static var audiobookManifest: MediaType { readiumAudiobookManifest }
    @available(*, unavailable, renamed: "readiumWebPub")
    static var webpub: MediaType { readiumWebPub }
    @available(*, unavailable, renamed: "readiumWebPubManifest")
    static var webpubManifest: MediaType { readiumWebPubManifest }
    @available(*, unavailable, renamed: "lcpLicenseDocument")
    static var lcpLicense: MediaType { lcpLicenseDocument }
    @available(*, unavailable, renamed: "opds1")
    static var opds1Feed: MediaType { opds1 }
    @available(*, unavailable, renamed: "opds2")
    static var opds2Feed: MediaType { opds2 }

}

public extension URLResponse {
    
    @available(*, unavailable, renamed: "mediaType")
    var format: MediaType? { mediaType }
    
    @available(*, unavailable, renamed: "sniffMediaType")
    func sniffFormat(data: (() -> Data)? = nil, mediaTypes: [String] = [], fileExtensions: [String] = [], sniffers: [MediaType.Sniffer] = MediaType.sniffers) -> MediaType? {
        return sniffMediaType(data: data, mediaTypes: mediaTypes, fileExtensions: fileExtensions, sniffers: sniffers)
    }

}
