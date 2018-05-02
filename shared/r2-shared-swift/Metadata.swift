//
//  Metadata.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/16/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

/// The data representation of the <metadata> element of the ".opf" file.
public class Metadata {
    /// The structure used for the serialisation.
    public var multilangTitle: MultilangString?
    /// The title of the publication.
    public var title: String {
        get {
            return multilangTitle?.singleString ?? ""
        }
    }
    
    public var multilangSubtitle: MultilangString?
    /// The subtitle of the the publication
    public var subtitle: String {
        get {
            return multilangSubtitle?.singleString ?? ""
        }
    }
    
    public var direction: PageProgressionDirection {
        didSet {
            if direction == .rtl {
                for lang in languages {
                    let langType = LangType(rawString: lang)
                    if langType != .other {
                        self.primaryLanguage = lang
                        self.primaryContentLayout = Metadata.contentlayoutStyle(for: langType, pageDirection: direction)
                        break
                    }
                } // for
            }
            self.primaryLanguage = languages.first
        }
    }
    
    public enum LangType: String {
        case ar
        case fa
        case he
        case zh
        case ja
        case ko
        case other = ""
        
        public init(rawString: String) {
            self = LangType(rawValue: rawString) ?? .other
        }
    }
    
    public enum ContentLayoutStyle: String {
        case rtl = "rtl"
        case ltr = "ltr"
        
        case cjkVertical = "cjk-vertical"
        case cjkHorizontal = "cjk-horizontal"
    }
    
    public static func contentlayoutStyle(for lang:LangType, pageDirection:PageProgressionDirection) -> ContentLayoutStyle {
        
        switch(lang) {
        case .ar, .fa, .he:
            return .rtl
        case .zh, .ja, .ko:
            return pageDirection == .rtl ? .cjkVertical:.cjkHorizontal
        default:
            return pageDirection == .rtl ? .rtl:.ltr
        }
    }
    
    public private(set) var primaryLanguage: String?
    public private(set) var primaryContentLayout: ContentLayoutStyle?
 
    public var languages = [String]()
    public var identifier: String?
    // Contributors.
    public var publishers = [Contributor]()
    public var imprints = [Contributor]()
    public var contributors = [Contributor]()
    public var authors = [Contributor]()
    public var translators = [Contributor]()
    public var editors = [Contributor]()
    public var artists = [Contributor]()
    public var illustrators = [Contributor]()
    public var letterers = [Contributor]()
    public var pencilers = [Contributor]()
    public var colorists = [Contributor]()
    public var inkers = [Contributor]()
    public var narrators = [Contributor]()

    public var subjects = [Subject]()
    public var modified: Date?
    public var publicationDate: String?
    public var description: String?
    
    public var rendition = Rendition()
    public var source: String?
    public var epubType = [String]()
    public var rights: String?
    public var rdfType: String?
    public var otherMetadata = [MetadataItem]()
    
    // TODO: support parsing from OPF.
    public var belongsTo: BelongsTo?
    
    public var duration: Int?
    
    //belongto duration

    public init() {
        direction = .Default
    }

    required public init?(map: Map) {
        direction = .Default
    }
    
    /// Get the title for the given `lang`, if it exists in the dictionnary.
    ///
    /// - Parameter lang: The string representing the lang e.g. "en", "fr"..
    /// - Returns: The corresponding title String in the `lang`language.
    public func titleForLang(_ lang: String) -> String? {
        return multilangTitle?.multiString[lang]
    }
    
    public func subtitleForLang(_ lang: String) -> String? {
        return multilangSubtitle?.multiString[lang]
    }
}
// JSON Serialisation extension.
extension Metadata: Mappable {
    public func mapping(map: Map) {
        var modified = self.modified?.iso8601

        identifier <- map["identifier", ignoreNil: true]
        // If multiString is not empty, then serialize it.
        if var titlesFromMultistring = multilangTitle?.multiString,
            !titlesFromMultistring.isEmpty {
            titlesFromMultistring <- map["title"]
        } else {
            var titleForSinglestring = multilangTitle?.singleString ?? ""

            titleForSinglestring <- map["title"]
        }
        
        if var subtitlesFromMultistring = multilangTitle?.multiString,
            !subtitlesFromMultistring.isEmpty {
            subtitlesFromMultistring <- map["subtitle"]
        } else {
            var subtitleForSinglestring = multilangTitle?.singleString ?? ""
            subtitleForSinglestring <- map["subtitle"]
        }
        
        languages <- map["languages", ignoreNil: true]
        if !authors.isEmpty {
            authors <- map["authors", ignoreNil: true]
        }
        if !translators.isEmpty {
            translators <- map["translators", ignoreNil: true]
        }
        if !editors.isEmpty {
            editors <- map["editors", ignoreNil: true]
        }
        if !artists.isEmpty {
            artists <- map["artists", ignoreNil: true]
        }
        if !illustrators.isEmpty {
            illustrators <- map["illustrators", ignoreNil: true]
        }
        if !letterers.isEmpty {
            letterers <- map["letterers", ignoreNil: true]
        }
        if !pencilers.isEmpty {
            pencilers <- map["pencilers", ignoreNil: true]
        }
        if !colorists.isEmpty {
            colorists <- map["colorists", ignoreNil: true]
        }
        if !inkers.isEmpty {
            inkers <- map["inkers", ignoreNil: true]
        }
        if !narrators.isEmpty {
            narrators <- map["narrators", ignoreNil: true]
        }
        if !contributors.isEmpty {
            contributors <- map["contributors", ignoreNil: true]
        }
        if !publishers.isEmpty {
            publishers <- map["publishers", ignoreNil: true]
        }
        if !imprints.isEmpty {
            imprints <- map["imprints", ignoreNil: true]
        }
        modified <- map["modified", ignoreNil: true]
        publicationDate <- map["publicationDate", ignoreNil: true]
        if !rendition.isEmpty() {
            rendition <- map["rendition", ignoreNil: true]
        }
        source <- map["source", ignoreNil: true]
        rights <- map["rights", ignoreNil: true]
        if !subjects.isEmpty {
            subjects <- map["subjects", ignoreNil: true]
        }
    }
}

public enum PageProgressionDirection: String {
    case Default = "default"
    case ltr
    case rtl
    
    public init(rawString: String) {
        self = PageProgressionDirection(rawValue: rawString) ?? .ltr
    }
}
