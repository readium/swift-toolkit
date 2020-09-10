//
//  ContentLayout.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri, Mickaël Menu on 13.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public enum ContentLayout: String {
    case rtl = "rtl"
    case ltr = "ltr"
    case cjkVertical = "cjk-vertical"
    case cjkHorizontal = "cjk-horizontal"

    public init(language: String, readingProgression: ReadingProgression = .auto) {
        let language = language.split(separator: "-").first.map(String.init)
            ?? language
        
        switch language.lowercased() {
        case "ar", "fa", "he":
            self = readingProgression.getContentLayoutOrFallback(fallback: .rtl)
        case "zh", "ja", "ko":
            self = readingProgression.getContentLayoutOrFallback(fallback: .cjkHorizontal, isCJK: true)
        default:
            self = readingProgression.getContentLayoutOrFallback(fallback: .ltr)
        }
    }
    
    public var readingProgression: ReadingProgression {
        switch self {
        case .rtl, .cjkVertical:
            return .rtl
        case .ltr, .cjkHorizontal:
            return .ltr
        }
    }

}

private extension ReadingProgression {
    
    func getContentLayoutOrFallback(fallback: ContentLayout, isCJK: Bool = false) -> ContentLayout {
        switch (self) {
        case .rtl, .btt:
            return isCJK ? .cjkVertical : .rtl
        case .ltr, .ttb:
            return isCJK ? .cjkHorizontal : .ltr
        case .auto:
            return fallback
        }
    }
    
}
