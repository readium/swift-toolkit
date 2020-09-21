//
//  CGPDFDocument.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 21/09/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit

/// Implementation of `PDFDocument` build with Core Graphics's `CGPDFDocument`.
///
/// For now, we use CGPDFDocument instead of PDFDocument to be the most compatible and efficient
/// possible:
///  - PDFDocument is only available on iOS 11+
///  - CGPDFDocument can use a CGDataProvider to read through the PDF document without keeping all
///    the data in memory.
final class CGPDFDocument: PDFDocument, Loggable {
    
    /// Underlying CoreGraphics's CGPDFDocument.
    private let document: UIKit.CGPDFDocument

    private init(document: UIKit.CGPDFDocument, password: String?) throws {
        if (document.isEncrypted) {
            guard
                let password = password?.cString(using: .utf8),
                document.unlockWithPassword(password) else
            {
                throw PDFDocumentError.invalidPassword
            }
        }
        
        self.document = document
    }
    
    convenience init(url: URL, password: String?) throws {
        guard let document = UIKit.CGPDFDocument(url as CFURL) else {
            throw PDFDocumentError.openFailed
        }
        
        try self.init(document: document, password: password)
    }

    convenience init(resource: Resource, password: String?) throws {
        var callbacks = CGDataProviderSequentialCallbacks(
            version: 0,

            getBytes: { info, buffer, count -> Int in
                guard let context = CGPDFDocument.context(from: info) else {
                    return 0
                }

                let result = context.resource.read(range: context.offset..<UInt64(count))
                switch result {
                case .success(let data):
                    data.copyBytes(to: buffer.assumingMemoryBound(to: UInt8.self), count: data.count)
                    return data.count
                case .failure(let error):
                    CGPDFDocument.log(.error, error)
                    return 0
                }
            },

            skipForward: { info, count -> off_t in
                guard let context = CGPDFDocument.context(from: info) else {
                    return 0
                }

                let current = context.offset
                context.offset = min(context.offset + UInt64(count), context.length - 1)
                return off_t(context.offset - current)
            },

            rewind: { info in
                guard let context = CGPDFDocument.context(from: info) else {
                    return
                }
                context.offset = 0
            },

            releaseInfo: { info in
                CGPDFDocument.context(from: info)?.resource.close()
            }
        )
            
        var context = ResourceContext(resource: resource)
        guard
            let provider = CGDataProvider(sequentialInfo: &context, callbacks: &callbacks),
            let document = UIKit.CGPDFDocument(provider) else
        {
            throw PDFDocumentError.openFailed
        }
                
        try self.init(document: document, password: password)
    }
    
    class ResourceContext {
        let resource: Resource
        var offset: UInt64 = 0
        
        lazy var length: UInt64 = resource.length.getOrNil() ?? 0
        
        init(resource: Resource) {
            self.resource = resource
        }
    }

    /// This can't be a nested func in `init(resource:password:)` because the C-function pointers of
    /// CGDataProvider's callbacks can't capture context.
    private static func context(from info: UnsafeMutableRawPointer?) -> ResourceContext? {
        let context = info?.assumingMemoryBound(to: ResourceContext.self).pointee
        if context == nil {
            log(.error, "Can't get the `ResourceContext` from `CGDataProvider.info`")
        }
        return context
    }

    lazy var identifier: String? = {
        guard
            let identifierArray = document.fileIdentifier,
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
    }()
    
    var pageCount: Int {
        document.numberOfPages
    }
    
    lazy var title: String? =
        string(forKey: "Title", in: document.info)
    
    lazy var author: String? =
        string(forKey: "Author", in: document.info)

    lazy var subject: String? =
        string(forKey: "Subject", in: document.info)

    lazy var keywords: [String] =
        stringList(forKey: "Keywords", in: document.info)

    lazy var cover: UIImage? = {
        guard let page = document.page(at: 1) else {
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
    }()

    lazy var outline: [PDFOutlineNode] = {
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
    }()

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

}
