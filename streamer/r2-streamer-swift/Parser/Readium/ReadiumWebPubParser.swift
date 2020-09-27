//
//  ReadiumWebPubParser.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 25.06.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

public enum ReadiumWebPubParserError: Error {
    case parseFailure(url: URL, Error?)
    case missingFile(path: String)
}

/// Parser for a Readium Web Publication (packaged, or as a manifest).
public class ReadiumWebPubParser: PublicationParser, Loggable {
    
    public enum Error: Swift.Error {
        case manifestNotFound
        case invalidManifest
    }
    
    private let pdfFactory: PDFDocumentFactory
    
    public init(pdfFactory: PDFDocumentFactory = DefaultPDFDocumentFactory()) {
        self.pdfFactory = pdfFactory
    }
    
    public func parse(file: File, fetcher: Fetcher, warnings: WarningLogger?) throws -> Publication.Builder? {
        guard let format = file.format, format.mediaType.isReadiumWebPubProfile else {
            return nil
        }
        
        let isPackage = !format.mediaType.isRWPM
        
        // Reads the manifest data from the fetcher.
        guard let manifestData: Data = (
            isPackage
                ? try? fetcher.readData(at: "/manifest.json")
                // For a single manifest file, reads the first (and only) file in the fetcher.
                : try? fetcher.readData(at: fetcher.links.first)
        ) else {
            throw Error.manifestNotFound
        }
        
        let manifest = try Manifest(json: JSONSerialization.jsonObject(with: manifestData), isPackaged: isPackage)
        var fetcher = fetcher
        var positionsFactory: PositionsServiceFactory? = nil
        
        // For a manifest, we discard the `fetcher` provided by the Streamer, because it was only
        // used to read the manifest file. We use an `HTTPFetcher` instead to serve the remote
        // resources.
        if !isPackage {
            fetcher = HTTPFetcher()
        }

        switch format {
        case .lcpProtectedPDF:
            // Checks the requirements from the spec, see. https://readium.org/lcp-specs/drafts/lcpdf
            guard
                !manifest.readingOrder.isEmpty,
                manifest.readingOrder.all(matchMediaType: .pdf) else
            {
                throw Error.invalidManifest
            }
            positionsFactory = LCPDFPositionsService.makeFactory(pdfFactory: pdfFactory)
            
        case .divina, .divinaManifest:
            positionsFactory = PerResourcePositionsService.makeFactory(fallbackMediaType: "image/*")
            
        default:
            break
        }

        return Publication.Builder(
            fileFormat: format,
            publicationFormat: (format == .lcpProtectedPDF ? .pdf : .webpub),
            manifest: manifest,
            fetcher: fetcher,
            servicesBuilder: .init(positions: positionsFactory)
        )
    }

    @available(*, deprecated, message: "Use an instance of `Streamer` to open a `Publication`")
    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        var fetcher = try makeFetcher(for: url)
        var drm: DRM?

        var decryptor: LCPDecryptor?
        let lcpProtected = (try? fetcher.readData(at: "/license.lcpl")) != nil
        if lcpProtected {
            drm = DRM(brand: .lcp)
            decryptor = LCPDecryptor()
            fetcher = TransformingFetcher(fetcher: fetcher, transformer: decryptor!.decrypt(resource:))
        }
        
        let file = File(url: url)
        guard
            let format = file.format,
            let components = try? ReadiumWebPubParser().parse(file: file, fetcher: fetcher) else
        {
            throw ReadiumWebPubParserError.parseFailure(url: url, nil)
        }
        
        let publication = components.build()
        let container = PublicationContainer(
            publication: publication,
            path: url.path,
            mimetype: format.mediaType.string,
            drm: drm
        )

        func didLoadDRM(_ drm: DRM?) throws {
            container.drm = drm
            decryptor?.license = drm?.license
        }

        return ((publication, container), didLoadDRM)
    }

}

@available(*, deprecated, renamed: "ReadiumWebPubParserError")
public typealias WEBPUBParserError = ReadiumWebPubParserError

@available(*, deprecated, renamed: "ReadiumWebPubParser")
public typealias WEBPUBParser = ReadiumWebPubParser
