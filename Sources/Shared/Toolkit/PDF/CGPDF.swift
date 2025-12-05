//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

/// Extends Core Graphics's `CGPDFDocument` to conform to `PDFDocument`.
///
/// Compared to using PDFKit, Core Graphics offers several advantages:
///  - PDFKit is only available on iOS 11+
///  - `CGPDFDocument` can use a `CGDataProvider` to read a PDF stream instead of loading the full
///    document in memory.
///
/// Use `CGPDFDocumentFactory` to create a `CGPDFDocument` from a `Resource`.
extension CGPDFDocument: PDFDocument {
    public func identifier() async throws -> String? {
        guard
            let identifierArray = fileIdentifier,
            CGPDFArrayGetCount(identifierArray) > 0
        else {
            return nil
        }

        var identifierString: CGPDFStringRef?
        CGPDFArrayGetString(identifierArray, 0, &identifierString)
        guard let identifierData = data(from: identifierString) else {
            return nil
        }

        // Converts the raw data to a hexadecimal string
        return identifierData.reduce("") { $0 + String(format: "%02x", $1) }
    }

    public func pageCount() async throws -> Int {
        numberOfPages
    }

    /// The reading progression can be derived from the `Direction` Name object under the
    /// `/Catalog/ViewerPreferences` dictionary.
    public func readingProgression() async throws -> ReadingProgression? {
        guard
            let viewerPreferences = dict(forKey: "ViewerPreferences", in: catalog),
            let direction = object(forKey: "Direction", in: viewerPreferences)
            .flatMap({ name(for: $0) })?
            .uppercased()
        else {
            return nil
        }

        switch direction {
        case "L2R", "LTR": return .ltr
        case "R2L", "RTL": return .rtl
        default: return nil
        }
    }

    public func title() async throws -> String? {
        string(forKey: "Title", in: info)
    }

    public func author() async throws -> String? {
        string(forKey: "Author", in: info)
    }

    public func subject() async throws -> String? {
        string(forKey: "Subject", in: info)
    }

    public func keywords() async throws -> [String] {
        stringList(forKey: "Keywords", in: info)
    }

    public func cover() async throws -> UIImage? {
        guard let page = page(at: 1) else {
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

    public func tableOfContents() async throws -> [PDFOutlineNode] {
        guard let outline = outline as? [String: Any] else {
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
        var stringRef: CGPDFStringRef?
        guard
            let dictionary = dictionary,
            CGPDFDictionaryGetString(dictionary, key, &stringRef)
        else {
            return nil
        }
        return string(from: stringRef)
    }

    private func string(from stringRef: CGPDFStringRef?) -> String? {
        guard
            let data = data(from: stringRef),
            let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return string.isEmpty ? nil : string
    }

    private func data(from stringRef: CGPDFStringRef?) -> Data? {
        guard
            let stringRef = stringRef,
            let bytes = CGPDFStringGetBytePtr(stringRef)
        else {
            return nil
        }
        return Data(bytes: bytes, count: CGPDFStringGetLength(stringRef))
    }

    private func dict(forKey key: String, in dictionary: CGPDFDictionaryRef?) -> CGPDFDictionaryRef? {
        var dictRef: CGPDFDictionaryRef?
        guard
            let dictionary = dictionary,
            CGPDFDictionaryGetDictionary(dictionary, key, &dictRef)
        else {
            return nil
        }
        return dictRef
    }

    private func object(forKey key: String, in dictionary: CGPDFDictionaryRef?) -> CGPDFObjectRef? {
        var objectRef: CGPDFObjectRef?
        guard
            let dictionary = dictionary,
            CGPDFDictionaryGetObject(dictionary, key, &objectRef)
        else {
            return nil
        }
        return objectRef
    }

    private func name(for object: CGPDFObjectRef?) -> String? {
        var optBuffer: UnsafePointer<Int8>?
        guard
            let object = object,
            CGPDFObjectGetValue(object, .name, &optBuffer),
            let buffer = optBuffer
        else {
            return nil
        }
        return String(cString: buffer)
    }
}

/// Creates a `PDFDocument` using Core Graphics.
public class CGPDFDocumentFactory: PDFDocumentFactory, Loggable {
    public func open(file: FileURL, password: String?) async throws -> PDFDocument {
        guard let document = CGPDFDocument(file.url as CFURL) else {
            throw PDFDocumentError.openFailed
        }

        return try open(document: document, password: password)
    }

    private class DataHolder {
        var data: Data = .init()
    }

    public func open<HREF: URLConvertible>(resource: Resource, at href: HREF, password: String?) async throws -> PDFDocument {
        if let file = resource.sourceURL?.fileURL {
            return try await open(file: file, password: password)
        }

        var callbacks = CGDataProviderSequentialCallbacks(
            version: 0,

            getBytes: { info, buffer, count -> Int in
                guard let context = CGPDFDocumentFactory.context(from: info) else {
                    return 0
                }

                let end = min(context.offset + UInt64(count), context.length)
                if context.offset >= end {
                    return 0
                }

                let semaphore = DispatchSemaphore(value: 0)
                let holder = DataHolder()
                Task {
                    switch await context.resource.read(range: context.offset ..< end) {
                    case let .success(result):
                        holder.data = result
                    case let .failure(error):
                        CGPDFDocumentFactory.log(.error, error)
                    }
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: .distantFuture)

                let data = holder.data
                if !data.isEmpty {
                    data.copyBytes(to: buffer.assumingMemoryBound(to: UInt8.self), count: data.count)
                    context.offset += UInt64(data.count)
                }
                return data.count
            },

            skipForward: { info, count -> off_t in
                guard let context = CGPDFDocumentFactory.context(from: info) else {
                    return 0
                }

                let current = context.offset
                context.offset = min(context.offset + UInt64(count), context.length)
                return off_t(context.offset - current)
            },

            rewind: { info in
                guard let context = CGPDFDocumentFactory.context(from: info) else {
                    return
                }
                context.offset = 0
            },

            releaseInfo: { info in
                let info = info?.assumingMemoryBound(to: ResourceContext.self)
                info?.deinitialize(count: 1)
                info?.deallocate()
            }
        )

        let context = await ResourceContext(resource: resource)
        let contextRef = UnsafeMutablePointer<ResourceContext>.allocate(capacity: 1)
        contextRef.initialize(to: context)

        guard
            let provider = CGDataProvider(sequentialInfo: contextRef, callbacks: &callbacks),
            let document = UIKit.CGPDFDocument(provider)
        else {
            throw PDFDocumentError.openFailed
        }

        return try open(document: document, password: password)
    }

    private func open(document: CGPDFDocument, password: String?) throws -> PDFDocument {
        if document.isEncrypted, !document.isUnlocked {
            guard
                let password = password?.cString(using: .utf8),
                document.unlockWithPassword(password)
            else {
                throw PDFDocumentError.invalidPassword
            }
        }

        return document
    }

    private class ResourceContext {
        let resource: Resource
        var offset: UInt64 = 0
        let length: UInt64

        init(resource: Resource) async {
            self.resource = resource
            length = await (resource.estimatedLength().getOrNil() ?? 0) ?? 0
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
}
