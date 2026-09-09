//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

package extension CGPDFDocument {
    func identifier() async throws -> String? {
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

    func pageCount() async throws -> Int {
        numberOfPages
    }

    /// The reading progression can be derived from the `Direction` Name object under the
    /// `/Catalog/ViewerPreferences` dictionary.
    func readingProgression() async throws -> ReadingProgression? {
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

    func title() async throws -> String? {
        string(forKey: "Title", in: info)
    }

    func author() async throws -> String? {
        string(forKey: "Author", in: info)
    }

    func subject() async throws -> String? {
        string(forKey: "Subject", in: info)
    }

    func keywords() async throws -> [String] {
        stringList(forKey: "Keywords", in: info)
    }

    func cover() async throws -> UIImage? {
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

    func tableOfContents() async throws -> [PDFOutlineNode] {
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
