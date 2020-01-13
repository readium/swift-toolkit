//
//  PDFFileCGParser.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 07.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared


final class PDFFileCGParser: PDFFileParser, Loggable {

    private var stream: SeekableInputStream
    
    init(stream: SeekableInputStream) throws {
        self.stream = stream
    }
    
    func renderCover() throws -> UIImage? {
        guard let document = self.document,
            let page = document.page(at: 1) else
        {
            return nil
        }

        // Properly handles the page crop and rotation defined in the PDF.
        // A good test-case is the first page of Links-to-Images-N-Contents.pdf, provided by Adobe.
        
        let cropRect = page.getBoxRect(.cropBox)
        let rotationAngle = CGFloat(page.rotationAngle) * .pi / 180
        let rotatedCropRect = cropRect
            .applying(CGAffineTransform(rotationAngle: rotationAngle))
        
        guard let context = CGContext(
            data: nil,
            width: Int(rotatedCropRect.width),
            height: Int(rotatedCropRect.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue).union(.byteOrder32Little).rawValue
        )
        else {
            return nil
        }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(context.boundingBoxOfClipPath)
        
        context.translateBy(
            x: rotatedCropRect.width / 2,
            y: rotatedCropRect.height / 2
        )
        context.rotate(by: -rotationAngle)
        context.translateBy(
            x: -cropRect.minX - cropRect.width / 2,
            y: -cropRect.minY - cropRect.height / 2
        )
        
        context.drawPDFPage(page)

        guard let cgImage = context.makeImage() else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    func parseNumberOfPages() throws -> Int {
        guard let document = self.document else {
            throw PDFParserError.openFailed
        }
        return document.numberOfPages
    }

    func parseMetadata() throws -> PDFFileMetadata {
        guard let document = self.document else {
            throw PDFParserError.openFailed
        }
        // FIXME: how should we handle PDF encrypted with a password?
        guard !document.isEncrypted else {
            throw PDFParserError.fileEncryptedWithPassword
        }

        let info = document.info
        return PDFFileMetadata(
            identifier: identifier(of: document),
            version: version(of: document),
            title: string(forKey: "Title", in: info),
            author: string(forKey: "Author", in: info),
            subject: string(forKey: "Subject", in: info),
            keywords: stringList(forKey: "Keywords", in: info),
            outline: outline(of: document)
        )
    }
    
    private func identifier(of document: CGPDFDocument) -> String? {
        guard let identifierArray = document.fileIdentifier,
            CGPDFArrayGetCount(identifierArray) > 0 else
        {
            return nil
        }
        
        var identifierString: CGPDFStringRef?
        CGPDFArrayGetString(identifierArray, 0, &identifierString)
        guard let identifierData = data(from: identifierString) else {
            return nil
        }
        
        // Converts the raw data to a hexadecimal string
        return identifierData.reduce("") { $0 + String(format: "%02x", $1)}
    }
    
    private func version(of document: CGPDFDocument) -> String {
        var major: Int32 = 0
        var minor: Int32 = 0
        document.getVersion(majorVersion: &major, minorVersion: &minor)
        return "\(major).\(minor)"
    }
    
    private func outline(of document: CGPDFDocument) -> [PDFOutlineNode] {
        guard #available(iOS 11.0, *),
            let outline = document.outline as? [String: Any] else
        {
            return []
        }
        
        func node(from dictionary: [String: Any]) -> PDFOutlineNode? {
            guard let pageNumber = dictionary[kCGPDFOutlineDestination as String] as? Int else {
                return nil
            }
            
            return PDFOutlineNode(
                title: dictionary[kCGPDFOutlineTitle as String] as? String,
                pageNumber: pageNumber,
                children: nodes(in: dictionary[kCGPDFOutlineChildren as String] as? [[String: Any]])
            )
        }
        
        func nodes(in children: [[String: Any]]?) -> [PDFOutlineNode] {
            guard let children = children else {
                return []
            }
            
            return children.compactMap { node(from: $0) }
        }
        
        return nodes(in: outline[kCGPDFOutlineChildren as String] as? [[String: Any]])
    }
    
    private func stringList(forKey key: String, in dictionary: CGPDFDictionaryRef?) -> [String] {
        guard let string = string(forKey: key, in: dictionary) else {
            return []
        }
        
        return string
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func string(forKey key: String, in dictionary: CGPDFDictionaryRef?) -> String? {
        guard let dictionary = dictionary else {
            return nil
        }
        var stringRef: CGPDFStringRef?
        CGPDFDictionaryGetString(dictionary, key, &stringRef)
        return string(from: stringRef)
    }
    
    private func string(from stringRef: CGPDFStringRef?) -> String? {
        guard let data = data(from: stringRef),
            let string = String(data: data, encoding: .utf8) else
        {
            return nil
        }
        return string.isEmpty ? nil : string
    }
    
    private func data(from stringRef: CGPDFStringRef?) -> Data? {
        guard let stringRef = stringRef,
            let bytes = CGPDFStringGetBytePtr(stringRef) else
        {
            return nil
        }
        return Data(bytes: bytes, count: CGPDFStringGetLength(stringRef))
    }
    
    /// Opens a CGPDFDocument using the provided stream and a CGDataProvider.
    /// For now, the parser uses CGPDFDocument instead of PDFDocument to be the most compatible and efficient possible:
    ///  - PDFDocument is only available on iOS 11+
    ///  - CGPDFDocument can use a CGDataProvider to read through the PDF document without keeping all the data in memory.
    lazy var document: CGPDFDocument? = {
        stream.open()
        
        var callbacks = CGDataProviderSequentialCallbacks(
            version: 0,

            getBytes: { info, buffer, count -> Int in
                guard let stream = PDFFileCGParser.streamWithInfo(info) else {
                    return 0
                }

                let readBytes = stream.read(buffer.assumingMemoryBound(to: UInt8.self), maxLength: count)
                guard readBytes >= 0 else {
                    PDFParser.log(.error, stream.streamError)
                    return 0
                }
                return readBytes
            },

            skipForward: { info, count -> off_t in
                guard let stream = PDFFileCGParser.streamWithInfo(info) else {
                    return 0
                }

                let current = stream.offset
                do {
                    // SeekWhence.currentPosition is not supported at this time
                    try stream.seek(offset: Int64(current) + count, whence: .startOfFile)
                } catch {
                    PDFParser.log(.error, error)
                    return 0
                }
                return off_t(stream.offset - current)
            },

            rewind: { info in
                guard let stream = PDFFileCGParser.streamWithInfo(info) else {
                    return
                }
                do {
                    try stream.seek(offset: 0, whence: .startOfFile)
                } catch {
                    PDFParser.log(.error, error)
                }
            },

            releaseInfo: { info in
                // The stream is released with `PDFFileCGParser`
            }
        )
            
        guard let provider = CGDataProvider(sequentialInfo: &stream, callbacks: &callbacks),
            let document = CGPDFDocument(provider) else
        {
            return nil
        }
                
        return document
    }()

    /// This can't be a nested func in `document` because the C-function pointers of CGDataProvider's callbacks can't capture context.
    private static func streamWithInfo(_ info: UnsafeMutableRawPointer?) -> SeekableInputStream? {
        let stream = info?.assumingMemoryBound(to: SeekableInputStream.self).pointee
        if stream == nil {
            log(.error, "Can't get the stream from CGDataProvider.info")
        }
        return stream
    }
    
}
