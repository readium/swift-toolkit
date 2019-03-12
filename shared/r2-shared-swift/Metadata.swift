//
//  Metadata.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 2/16/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

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
    
    public var readingProgression: ReadingProgression {
        didSet {
            if readingProgression == .rtl {
                for lang in languages {
                    let langType = LangType(rawString: lang)
                    if langType != .other {
                        self.primaryLanguage = lang
                        let layout = Metadata.contentlayoutStyle(for: langType, readingProgression: readingProgression)
                        self.primaryContentLayout = layout; break
                    }
                }
                return
            }
            self.primaryLanguage = languages.first // Unknow
            let langType = LangType(rawString: primaryLanguage ?? "")
            let layout = Metadata.contentlayoutStyle(for: langType, readingProgression: readingProgression)
            self.primaryContentLayout = layout
        }
    }
    
    public static func contentlayoutStyle(for lang:LangType, readingProgression:ReadingProgression?) -> ContentLayoutStyle {
        
        switch(lang) {
        case .ar, .fa, .he:
            return .rtl
        case .zh, .ja, .ko:
            return readingProgression == .rtl ? .cjkVertical:.cjkHorizontal
        default:
            return readingProgression == .rtl ? .rtl:.ltr
        }
    }
    
    public private(set) var primaryLanguage: String?
    public private(set) var primaryContentLayout: ContentLayoutStyle?
 
    public var languages = [String]()
    public var identifier: String?
    public var publishers = [Contributor]()
    public var imprints = [Contributor]()
  // Contributors.
  // author, translator, editor, artist, illustrator, letterer, penciler, colorist, inker and narrator.
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
    
    /// https://github.com/readium/webpub-manifest/tree/master/contexts/default#publication-date
    ///
    /// Only accept valid RFC3339 date String with full date. Otherwise, it's nil.
    /// Time part should be full if present, support timezone with full offset. Millisecond not supported.
    public var published: String? {
        set {
            if let theNewValue = newValue {
                if DateFormatter.verifyRFC3339(dateString: theNewValue) {
                    _published = theNewValue
                } else {
                    _published = nil
                }
                
// On iOS 10 and later, this API should be treated withFullTime or withTimeZone for different cases.
// Otherwise it will accept bad format, for exmaple 2018-04-24XXXXXXXXX
// Because it will only test the part you asssigned, date, time, timezone.
// But we should also cover the optional cases. So there is not too much benefit.
//                if #available(iOS 10.0, *) {
//                    let formatter = ISO8601DateFormatter()
//                    formatter.formatOptions = [.withFullDate]
//                    if let _ = formatter.date(from: theNewValue) {
//                        _published = theNewValue
//                    }
//                }
            } else {
                _published = nil
            }
        }
        get {
            return _published
        }
    }
    private var _published: String?
    
    public var description: String?
    
    public var rendition = EPUBRendition()
    public var source: String?
    public var epubType = [String]()
    public var rights: String?
    public var rdfType: String?
    public var otherMetadata = [MetadataItem]()
    
    // TODO: support parsing from OPF.
    public var belongsTo: BelongsTo?
    
    public var duration: Float?
    public var numberOfPages:Int?

    public init() {
        readingProgression = .Default
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
extension Metadata: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case artists
        case authors
        case colorists
        case contributors
        case identifier
        case illustrators
        case imprints
        case inkers
        case editors
        case languages
        case letterers
        case modified
        case narrators
        case pencilers
        case published
        case publishers
        case rendition
        case rights
        case source
        case subjects
        case subtitle
        case title
        case translators
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !artists.isEmpty {
            try container.encode(artists, forKey: .artists)
        }
        if !authors.isEmpty {
            try container.encode(authors, forKey: .authors)
        }
        if !colorists.isEmpty {
            try container.encode(colorists, forKey: .colorists)
        }
        if !contributors.isEmpty {
            try container.encode(contributors, forKey: .contributors)
        }
        try container.encodeIfPresent(identifier, forKey: .identifier)
        if !illustrators.isEmpty {
            try container.encode(illustrators, forKey: .illustrators)
        }
        if !imprints.isEmpty {
            try container.encode(imprints, forKey: .imprints)
        }
        if !inkers.isEmpty {
            try container.encode(inkers, forKey: .inkers)
        }
        if !editors.isEmpty {
            try container.encode(editors, forKey: .editors)
        }
        try container.encode(languages, forKey: .languages)
        if !letterers.isEmpty {
            try container.encode(letterers, forKey: .letterers)
        }
        try container.encodeIfPresent(modified?.iso8601, forKey: .modified)
        if !narrators.isEmpty {
            try container.encode(narrators, forKey: .narrators)
        }
        if !pencilers.isEmpty {
            try container.encode(pencilers, forKey: .pencilers)
        }
        try container.encodeIfPresent(published, forKey: .published)
        if !publishers.isEmpty {
            try container.encode(publishers, forKey: .publishers)
        }
//        if !rendition.isEmpty() {
//            try container.encode(rendition, forKey: .rendition)
//        }
        try container.encodeIfPresent(rights, forKey: .rights)
        try container.encodeIfPresent(source, forKey: .source)
        if !subjects.isEmpty {
            try container.encode(subjects, forKey: .subjects)
        }
        try container.encodeIfPresent(multilangSubtitle, forKey: .subtitle)
        // title is required (https://readium.org/webpub-manifest/schema/extensions/epub/metadata.schema.json)
        if let multilangTitle = multilangTitle {
            try container.encode(multilangTitle, forKey: .title)
        } else {
            try container.encode("", forKey: .title)
        }
        if !translators.isEmpty {
            try container.encode(translators, forKey: .translators)
        }
    }
    
}

public enum ReadingProgression: String {
    case Default = "default"
    case ltr
    case rtl
    
    public init(rawString: String) {
        self = ReadingProgression(rawValue: rawString) ?? .ltr
    }
}

public enum LangType: String {
    case ar
    case fa
    case he
    case zh // Any Chinese: zh-*-*
    case ja
    case ko
    case mn  // "mn", "mn-Cyrl"
    case other = ""
    
    public init(rawString: String) {
        let language: String = { () -> String in
            if let lang = rawString.split(separator: "-").first {
                return String(lang)
            }
            return rawString
        }()
        self = LangType(rawValue: language) ?? .other
    }
}

public enum ContentLayoutStyle: String {
    case rtl = "rtl"
    case ltr = "ltr"
    
    case cjkVertical = "cjk-vertical"
    case cjkHorizontal = "cjk-horizontal"
}

// MARK: - Parsing related methods
extension Metadata {
    
    static public func parse(metadataDict: [String: Any]) throws -> Metadata {
        let m = Metadata()
        for (k, v) in metadataDict {
            switch k {
            case "title":
                m.multilangTitle = MultilangString()
                m.multilangTitle?.singleString = v as? String
            case "identifier":
                m.identifier = v as? String
            case "type", "@type":
                m.rdfType = v as? String
            case "modified":
                if let dateStr = v as? String {
                    m.modified = dateStr.dateFromISO8601
                }
            case "author":
                m.authors.append(contentsOf: try Contributor.parse(contributors: v))
            case "translator":
                m.translators.append(contentsOf: try Contributor.parse(contributors: v))
            case "editor":
                m.editors.append(contentsOf: try Contributor.parse(contributors: v))
            case "artist":
                m.artists.append(contentsOf: try Contributor.parse(contributors: v))
            case "illustrator":
                m.illustrators.append(contentsOf: try Contributor.parse(contributors: v))
            case "letterer":
                m.letterers.append(contentsOf: try Contributor.parse(contributors: v))
            case "penciler":
                m.pencilers.append(contentsOf: try Contributor.parse(contributors: v))
            case "colorist":
                m.colorists.append(contentsOf: try Contributor.parse(contributors: v))
            case "inker":
                m.inkers.append(contentsOf: try Contributor.parse(contributors: v))
            case "narrator":
                m.narrators.append(contentsOf: try Contributor.parse(contributors: v))
            case "contributor":
                m.contributors.append(contentsOf: try Contributor.parse(contributors: v))
            case "publisher":
                m.publishers.append(contentsOf: try Contributor.parse(contributors: v))
            case "imprint":
                m.imprints.append(contentsOf: try Contributor.parse(contributors: v))
            case "published":
                m.published = v as? String
            case "description":
                m.description = v as? String
            case "source":
                m.source = v as? String
            case "rights":
                m.rights = v as? String
            case "subject":
                if let subjects = v as? [[String: Any]] {
                    for subjDict in subjects {
                        let subject = Subject()
                        for (sk, sv) in subjDict {
                            switch sk {
                            case "name":
                                subject.name = sv as? String
                            case "sortAs", "sort_as":
                                subject.sortAs = sv as? String
                            case "scheme":
                                subject.scheme = sv as? String
                            case "code":
                                subject.code = sv as? String
                            case "links":
                                if let dict = sv as? [String: Any] {
                                    subject.links.append(try Link.parse(linkDict: dict))
                                }else if let array = sv as? [[String: Any]] {
                                    for dict in array {
                                        subject.links.append(try Link.parse(linkDict: dict))
                                    }
                                }
                            default:
                                continue
                            }
                        }
                        m.subjects.append(subject)
                    }
                }
            case "belongsTo", "belongs_to":
                if let belongsDict = v as? [String: Any] {
                    let belongs = BelongsTo()
                    for (bk, bv) in belongsDict {
                        switch bk {
                        case "series":
                            switch bv {
                            case let s as String:
                                belongs.series.append(PublicationCollection(name: s))
                            case let cArr as [[String: Any]]:
                                for cDict in cArr {
                                    belongs.series.append(try PublicationCollection.parse(cDict))
                                }
                            case let cDict as [String: Any]:
                                belongs.series.append(try PublicationCollection.parse(cDict))
                            default:
                                continue
                            }
                        case "collection":
                            switch bv {
                            case let s as String:
                                belongs.collection.append(PublicationCollection(name: s))
                            case let cArr as [[String: Any]]:
                                for cDict in cArr {
                                    belongs.collection.append(try PublicationCollection.parse(cDict))
                                }
                            case let cDict as [String: Any]:
                                belongs.collection.append(try PublicationCollection.parse(cDict))
                            default:
                                continue
                            }
                        default:
                            continue
                        }
                    }
                    m.belongsTo = belongs
                }
            case "duration":
                m.duration = v as? Float
            case "numberOfPages":
                m.numberOfPages = v as? Int
            case "language":
                switch v {
                case let s as String:
                    m.languages.append(s)
                case let sArr as [String]:
                    m.languages.append(contentsOf: sArr)
                default:
                    continue
                }
            default:
                continue
            }
        }
        return m
    }
    
}

extension DateFormatter {
    
    static let formatSet = [
        10: "yyyy-MM-dd",
        11: "yyyy-MM-ddZ",
        16: "yyyy-MM-ddZZZZZ",
        19: "yyyy-MM-dd'T'HH:mm:ss",
        20: "yyyy-MM-dd'T'HH:mm:ssZ",
        25: "yyyy-MM-dd'T'HH:mm:ssZZZZZ"]
    
    /// https://developer.apple.com/documentation/foundation/dateformatter
    /// Does't support millsecond or uncompleted part for date, time, timezone offset.
    static func verifyRFC3339(dateString: String) -> Bool {
        
        let rfc3339Formatter = DateFormatter()
        rfc3339Formatter.locale = Locale(identifier: "en_US_POSIX")
        rfc3339Formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        rfc3339Formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let length = dateString.count
        if let format = formatSet[length], format != rfc3339Formatter.dateFormat {
            rfc3339Formatter.dateFormat = format
        }
        
        if let _ = rfc3339Formatter.date(from: dateString) {
            return true
        }
        
        return false
    }
}
