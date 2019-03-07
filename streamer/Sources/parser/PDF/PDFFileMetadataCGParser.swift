//
//  PDFFileMetadataCGParser.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 07.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


final class PDFFileMetadataCGParser: PDFFileMetadataParser, Loggable {

    func parse(from stream: SeekableInputStream) throws -> (metadata: PDFFileMetadata, context: Any?) {
        return try withPDFDocument(stream: stream) { document in
            // FIXME: how should we handle PDF encrypted with a password?
            guard !document.isEncrypted else {
                throw PDFParserError.fileEncryptedWithPassword
            }
            
            let info = document.info
            let metadata = PDFFileMetadata(
                identifier: identifier(of: document),
                version: version(of: document),
                title: string(forKey: "Title", in: info),
                author: string(forKey: "Author", in: info),
                subject: string(forKey: "Subject", in: info),
                keywords: stringList(forKey: "Keywords", in: info)
            )
            return (metadata, nil)
        }
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
    
    /// Opens a CGPDFDocument using the fetcher's stream and a CGDataProvider.
    /// For now, the parser uses CGPDFDocument instead of PDFDocument to be the most compatible and efficient possible:
    ///  - PDFDocument is only available on iOS 11+
    ///  - CGPDFDocument can use a CGDataProvider to read through the PDF document without keeping all the data in memory.
    ///
    /// - Parameter block: Code to execute using the CGPDFDocument. The stream is automatically released once the block is executed.
    private func withPDFDocument<T>(stream: SeekableInputStream, _ block: (CGPDFDocument) throws -> T) throws -> T {
        var stream = stream
        stream.open()
        
        return try withUnsafeMutablePointer(to: &stream) { streamPointer in
            var callbacks = CGDataProviderSequentialCallbacks(
                version: 0,
                
                getBytes: { info, buffer, count -> Int in
                    guard let stream = PDFFileMetadataCGParser.streamWithInfo(info) else {
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
                    guard let stream = PDFFileMetadataCGParser.streamWithInfo(info) else {
                        return 0
                    }
                    
                    let current = stream.offset
                    // SeekWhence.currentPosition is not supported at this time
                    do {
                        try stream.seek(offset: Int64(current) + count, whence: .startOfFile)
                    } catch {
                        PDFParser.log(.error, error)
                        return 0
                    }
                    return off_t(stream.offset - current)
                },
                
                rewind: { info in
                    guard let stream = PDFFileMetadataCGParser.streamWithInfo(info) else {
                        return
                    }
                    do {
                        try stream.seek(offset: 0, whence: .startOfFile)
                    } catch {
                        PDFParser.log(.error, error)
                    }
                },
                
                releaseInfo: { info in
                    guard let stream = PDFFileMetadataCGParser.streamWithInfo(info) else {
                        return
                    }
                    // The stream object is released automatically once we leave the `withUnsafeMutablePointer` block.
                    stream.close()
                }
            )
            
            return try withUnsafePointer(to: &callbacks) { callbacksPointer in
                guard let provider = CGDataProvider(sequentialInfo: streamPointer, callbacks: callbacksPointer),
                    let document = CGPDFDocument(provider) else
                {
                    throw PDFParserError.openFailed
                }
                
                return try block(document)
            }
        }
    }
    
    /// This can't be a nested func in `withPDFDocument` because the C-function pointers of CGDataProvider's callbacks can't capture context.
    private static func streamWithInfo(_ info: UnsafeMutableRawPointer?) -> SeekableInputStream? {
        let stream = info?.assumingMemoryBound(to: SeekableInputStream.self).pointee
        if stream == nil {
            log(.error, "Can't get the stream from CGDataProvider.info")
        }
        return stream
    }
    
}
