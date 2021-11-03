//
//  StringEncoding.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

extension String.Encoding {
    
    /// Converts a string charset to an `Encoding`.
    ///
    /// See https://www.iana.org/assignments/character-sets/character-sets.xhtml
    init?(charset: String?) {
        switch charset?.uppercased() {
        case "US-ASCII":
            self = .ascii
        case "ISO-2022-JP", "ISO-2022-JP-2":
            self = .iso2022JP
        case "ISO-8859-1":
            self = .isoLatin1
        case "ISO-8859-2":
            self = .isoLatin2
        case "EUC-JP":
            self = .japaneseEUC
        case "SHIFT_JIS":
            self = .shiftJIS
        case "UTF-16":
            self = .utf16
        case "UTF-16LE":
            self = .utf16LittleEndian
        case "UTF-16BE":
            self = .utf16BigEndian
        case "UTF-32":
            self = .utf32
        case "UTF-32LE":
            self = .utf32LittleEndian
        case "UTF-32BE":
            self = .utf32BigEndian
        case "UTF-8":
            self = .utf8
        case "WINDOWS-1250":
            self = .windowsCP1250
        case "WINDOWS-1251":
            self = .windowsCP1251
        case "WINDOWS-1252":
            self = .windowsCP1252
        case "WINDOWS-1253":
            self = .windowsCP1253
        case "WINDOWS-1254":
            self = .windowsCP1254
        default:
            return nil
        }
    }
    
}
