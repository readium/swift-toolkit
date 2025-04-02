//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftUI

//func view(guide: AccessibilityMetadataDisplayGuide, descriptive: Bool) {
//    for field in guide.fields {
//        if !field.shouldDisplay {
//            continue
//        }
//        
//        Section(title: field.localizedTitle) {
//            StatementList(field.statements, descriptive: descriptive)
//            
//            if let details = field.details {
//                Section(title: details.localizedTitle, isCollapsed: true) {
//                    StatementList(details.statements, descriptive: descriptive)
//                }
//            }
//        }
//    }
//}
//
//func StatementList(_ statements: [AccessibilityDisplayStatement], descriptive: Bool) {
//    for statement in statements {
//        Row(statement.localizedString(descriptive: descriptive))
//    }
//}

public protocol AccessibilityDisplayStatement {
    
    /// A localized representation for this display statement.
    ///
    /// For example:
    /// - compact: Appearance can be modified
    /// - descriptive: For example, "Appearance of the text and page layout can be modified according to the
    /// capabilities of the reading system (font family and font size, spaces between paragraphs, sentences, words, and
    /// letters, as well as color of background and text)
    ///
    /// - Parameter descriptive: When true, will return the long descriptive statement.
    func localizedString(descriptive: Bool) -> String
}

public extension AccessibilityDisplayStatement {
    
    /// A compact localized representation for this display statement.
    ///
    /// For example: "Appearance can be modified"
    var localizedString: String {
        localizedString(descriptive: false)
    }
}

public protocol AccessibilityDisplayStatementGroup {
    var statements: [AccessibilityDisplayStatement] { get }
}

public protocol AccessibilityDisplayField: AccessibilityDisplayStatementGroup {
    /// Localized title for this display field.
    var localizedTitle: String { get }
    
    /// Indicates whether this display field should be rendered in the user interface, because it contains useful
    /// information.
    ///
    /// A field with `shouldDisplay` set to `false` might have for only statement "No information is available".
    var shouldDisplay: Bool { get }

    var statements: [AccessibilityDisplayStatement] { get }
    var details: AccessibilityDisplayFieldDetails? { get }
}

public extension AccessibilityDisplayField {
    var details: (any AccessibilityDisplayFieldDetails)? { nil }
}

public protocol AccessibilityDisplayFieldDetails: AccessibilityDisplayStatementGroup {
    /// Localized title for this display field details section.
    var localizedTitle: String { get }
}

/// When presenting accessibility metadata provided by the publisher, it is suggested that the section is introduced
/// using terms such as "claims" or "declarations" (e.g., "Accessibility Claims").
public struct AccessibilityMetadataDisplayGuide {
    
    /// The ways of reading display field is a banner heading that groups together the following information about how
    /// the content facilitates access.
    public var waysOfReading: WaysOfReading
    
    /// Identifies whether the digital publication claims to meet internationally recognized conformance standards for
    /// accessibility.
    public var conformance: Conformance
    
    public var fields: [AccessibilityDisplayField] {
        [waysOfReading, conformance]
    }
        
    public struct WaysOfReading: AccessibilityDisplayField {
        
        /// Indicates if users can modify the appearance of the text and the page layout according to the possibilities
        /// offered by the reading system.
        public var visualAdjustments: VisualAdjustements
        
        /// Indicates whether all content required for comprehension can be consumed in text and therefore is available
        /// to reading systems with read aloud speech or dynamic braille capabilities.
        public var nonvisualReading: [NonvisualReading]
        
        /// Indicates the presence of prerecorded audio and specifies if this audio is standalone (an audiobook), is an
        /// alternative to the text (synchronized text with audio playback), or is complementary audio (portions of
        /// audio, (e.g., reading of a poem).
        public var prerecordedAudio: PrerecordedAudio

        public var localizedTitle: String { bundleString("ways-of-reading-title") }
        
        /// "Ways of reading" should be rendered even if there is no metadata.
        public let shouldDisplay: Bool = true

        public var statements: [AccessibilityDisplayStatement] {
            [visualAdjustments] + nonvisualReading + [prerecordedAudio]
        }

        public enum VisualAdjustements: String, AccessibilityDisplayStatement {
            /// Appearance can be modified
            case modifiable = "ways-of-reading-visual-adjustments-modifiable"
            
            /// Appearance cannot be modified
            case unmodifiable = "ways-of-reading-visual-adjustments-unmodifiable"
            
            /// No information about appearance modifiability is available
            case unknown = "ways-of-reading-visual-adjustments-unknown"
        }
        
        public enum NonvisualReading: String, AccessibilityDisplayStatement {
            /// Readable in read aloud or dynamic braille
            case readable = "ways-of-reading-nonvisual-reading-readable"
            
            /// Not fully readable in read aloud or dynamic braille
            case notFully = "ways-of-reading-nonvisual-reading-not-fully"
            
            /// Not readable in read aloud or dynamic braille
            case none = "ways-of-reading-nonvisual-reading-none"
            
            /// Has alternative text
            case altText = "ways-of-reading-nonvisual-reading-alt-text"
        }
        
        public enum PrerecordedAudio: String, AccessibilityDisplayStatement {
            /// Prerecorded audio synchronized with text
            case synchronized = "ways-of-reading-prerecorded-audio-synchronized"
            
            /// Prerecorded audio only
            case audioOnly = "ways-of-reading-prerecorded-audio-only"
            
            /// Prerecorded audio clips
            case audioComplementary = "ways-of-reading-prerecorded-audio-complementary"
            
            /// No information about prerecorded audio is available
            case noMetadata = "ways-of-reading-prerecorded-audio-no-metadata"
        }
    }
    
    public struct Conformance: AccessibilityDisplayField {
        
        public struct Version {
            var major: Int
            var minor: Int
        }
        
        public enum WCAGLevel: String {
            case a = "A"
            case aa = "AA"
            case aaa = "AAA"
        }
        
        public var hasConformance: Bool
        
        public var localizedTitle: String { bundleString("conformance-title") }
        
        /// "Conformance" should be rendered even if there is no metadata.
        public let shouldDisplay: Bool = true
        
        /// Detailed conformance information.
        ///
        /// The following detailed information may be too technical for the average reader, which is why it is separated
        /// from the general conformance information. Implementors may opt to include it without distinction from the
        /// general information, but it may be more helpful to users if it is clearly separated, such as by including it
        /// in an expandable display box (see the conformance examples) or adding a heading before it. Implementors may
        /// also choose not to display this information if it is too technical for their target audience
        public var details: Details?
        
        public struct Details: AccessibilityDisplayFieldDetails {
            public var localizedTitle: String { bundleString("conformance-details-title") }
            public var statements: [AccessibilityDisplayStatement] { [] }
        }
        
        public var statements: [AccessibilityDisplayStatement] {
            []
        }
    }
}

extension AccessibilityDisplayStatement where Self: RawRepresentable, RawValue == String {
    public func localizedString(descriptive: Bool) -> String {
        bundleString("\(rawValue)-\(descriptive ? "descriptive" : "compact")")
    }
}

private func bundleString(_ key: String, _ values: CVarArg...) -> String {
    bundleString("ReadiumShared.readium.\(key)", in: Bundle.module, values)
}

/// Returns the localized string in the main bundle, or fallback on the given bundle if not found.
private func bundleString(_ key: String, in bundle: Bundle, _ values: [CVarArg]) -> String {
    let defaultValue = bundle.localizedString(forKey: key, value: nil, table: nil)
    var string = Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
    if !values.isEmpty {
        string = String(format: string, locale: .current, arguments: values)
    }
    return string
}

private func bundleString(_ key: String, in bundleID: String, _ values: [CVarArg]) -> String {
    let defaultValue = Bundle(identifier: bundleID)?.localizedString(forKey: key, value: nil, table: nil)
    var string = Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
    if !values.isEmpty {
        string = String(format: string, locale: Locale.current, arguments: values)
    }
    return string
}
