//
//  URL.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 12/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import CommonCrypto

extension URL: Loggable {
    
    /// Returns whether the given `url` is `self` or one of its descendants.
    public func isParentOf(_ url: URL) -> Bool {
        let standardizedSelf = standardizedFileURL.path
        let other = url.standardizedFileURL.path
        return standardizedSelf == other || other.hasPrefix(standardizedSelf + "/")
    }
    
    /// Computes the MD5 hash of the file, if the URL is a file URL.
    /// Source: https://stackoverflow.com/a/42935601/1474476
    public func md5() -> String? {
        let bufferSize = 1024 * 1024

        do {
            let file = try FileHandle(forReadingFrom: self)
            defer {
                file.closeFile()
            }

            var context = CC_MD5_CTX()
            CC_MD5_Init(&context)

            // Reads up to `bufferSize` bytes until EOF is reached and updates the MD5 context.
            while autoreleasepool(invoking: {
                let data = file.readData(ofLength: bufferSize)
                if data.count > 0 {
                    data.withUnsafeBytes {
                        _ = CC_MD5_Update(&context, $0.baseAddress, numericCast(data.count))
                    }
                    return true // Continue
                } else {
                    return false // End of file
                }
            }) { }

            // Computes the MD5 digest.
            var digest: [UInt8] = Array(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            _ = CC_MD5_Final(&digest, &context)

            let hexDigest = digest.map { String(format: "%02hhx", $0) }.joined()
            return hexDigest

        } catch {
            log(.error, "Failed to compute MD5 hash of \(path): \(error)")
            return nil
        }
    }
    
    /// Returns the first available URL by appending the given `pathComponent`.
    ///
    /// If `pathComponent` is already taken, then it appends a number to it.
    public func appendingUniquePathComponent(_ pathComponent: String? = nil) -> URL {
        
        /// Returns the first path component matching the given `validation` closure.
        /// Numbers are appended to the path component until a valid candidate is found.
        func uniquify(_ pathComponent: String?, validation: (String) -> Bool) -> String {
            let pathComponent = pathComponent ?? UUID().uuidString
            var ext = (pathComponent as NSString).pathExtension
            if !ext.isEmpty {
                ext = ".\(ext)"
            }
            let pathComponentWithoutExtension = (pathComponent as NSString).deletingPathExtension
            
            var candidate = pathComponent
            var i = 0
            while !validation(candidate) {
                i += 1
                candidate = "\(pathComponentWithoutExtension) \(i)\(ext)"
            }
            return candidate
        }
        
        let pathComponent = uniquify(pathComponent) { candidate in
            let destination = appendingPathComponent(candidate)
            return !((try? destination.checkResourceIsReachable()) ?? false)
        }
        
        return appendingPathComponent(pathComponent)
    }
    
    /// Adds the given `newScheme` to the URL, but only if the URL doesn't already have one.
    public func addingSchemeIfMissing(_ newScheme: String) -> URL {
        guard scheme == nil else {
            return self
        }
        
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        components?.scheme = newScheme
        return components?.url ?? self
    }

}
