//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumFuzi
import ReadiumShared

/// Parses EPUB 3 SMIL Media Overlay documents and values into Readium models
/// (e.g. ``GuidedNavigationDocument``).
///
/// https://www.w3.org/TR/epub-mediaoverlays-33/
enum SMILParser {
    /// Parses a SMIL Media Overlay document into a ``GuidedNavigationDocument``.
    ///
    /// - Returns: `nil` if the document is valid but contains no guided
    /// content.
    static func parseGuidedNavigationDocument(
        smilData: Data,
        at url: RelativeURL,
        warnings: WarningLogger? = nil
    ) throws -> GuidedNavigationDocument? {
        let document = try ReadiumFuzi.XMLDocument(data: smilData)
        document.defineNamespaces(.smil, .epub)
        return SMILGuidedNavigationDocumentParsing(
            document: document,
            url: url,
            warnings: warnings
        ).parse()
    }

    /// Parses a SMIL clock value string (e.g. `"0:01:30.5"`, `"90s"`, `"2h"`)
    /// into a duration in seconds.
    ///
    /// https://www.w3.org/TR/SMIL/smil-timing.html#Timing-ClockValueSyntax
    ///
    /// - Returns: `nil` for invalid input.
    static func parseClockValue(_ value: String) -> TimeInterval? {
        let s = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        // Timecount values: Nh, Nmin, Ns, Nms, N
        let timecountPatterns: [(suffix: String, multiplier: Double)] = [
            ("h", 3600),
            ("min", 60),
            ("ms", 0.001),
            ("s", 1),
        ]
        for (suffix, multiplier) in timecountPatterns {
            if s.hasSuffix(suffix) {
                let numStr = String(s.dropLast(suffix.count))
                if let n = Double(numStr) {
                    return n * multiplier
                }
            }
        }

        // Clock values: [[hh:]mm:]ss[.fraction]
        let parts = s.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        switch parts.count {
        case 2:
            // mm:ss[.fraction]
            guard let mm = Double(parts[0]), let ss = Double(parts[1]) else { return nil }
            return mm * 60 + ss
        case 3:
            // hh:mm:ss[.fraction]
            guard let hh = Double(parts[0]), let mm = Double(parts[1]), let ss = Double(parts[2]) else { return nil }
            return hh * 3600 + mm * 60 + ss
        default:
            // Plain number (seconds)
            return Double(s)
        }
    }
}

/// Parses a SMIL Media Overlay document into a ``GuidedNavigationDocument``.
///
/// Holds the per-parse state, avoiding parameter threading through helpers.
private struct SMILGuidedNavigationDocumentParsing {
    let document: ReadiumFuzi.XMLDocument
    let url: RelativeURL
    let warnings: WarningLogger?

    func parse() -> GuidedNavigationDocument? {
        guard let body = document.firstChild(xpath: "//smil:body") else {
            return nil
        }

        let objects = parseObjects(in: body)
        guard !objects.isEmpty else {
            return nil
        }

        return GuidedNavigationDocument(guided: objects)
    }

    private func parseObjects(in element: ReadiumFuzi.XMLElement) -> [GuidedNavigationObject] {
        element.xpath("smil:seq|smil:par")
            .compactMap { child -> GuidedNavigationObject? in
                switch child.tag?.lowercased() {
                case "seq":
                    return parseSeq(child)
                case "par":
                    return parsePar(child)
                default:
                    return nil
                }
            }
    }

    private func parseSeq(_ element: ReadiumFuzi.XMLElement) -> GuidedNavigationObject? {
        let id = element.attr("id")
        let epubType = element.attr("type", namespace: .epub)

        let texttrefAttr = element.attr("textref", namespace: .epub)
        if texttrefAttr == nil {
            warnings?.log("<seq> is missing required epub:textref", model: GuidedNavigationObject.self, source: element, severity: .minor)
        }
        let textref = texttrefAttr.flatMap { resolveURL($0) }

        let children = parseObjects(in: element)

        return GuidedNavigationObject(
            id: id,
            refs: textref.flatMap { GuidedNavigationObject.Refs(text: $0) },
            roles: [.sequence] + roles(for: epubType),
            children: children
        )
    }

    private func parsePar(_ element: ReadiumFuzi.XMLElement) -> GuidedNavigationObject? {
        // A par MUST have a <smil:text> child - skip if absent.
        guard let textElement = element.firstChild(xpath: "smil:text") else {
            return nil
        }

        let id = element.attr("id")
        let epubType = element.attr("type", namespace: .epub)

        let textURL = textElement.attr("src").flatMap { resolveURL($0) }

        let audioRef: AnyURL? = element.firstChild(xpath: "smil:audio")
            .flatMap { audioElement in
                guard let src = audioElement.attr("src") else {
                    return nil
                }
                return audioURL(
                    src: src,
                    clipBegin: audioElement.attr("clipBegin"),
                    clipEnd: audioElement.attr("clipEnd")
                )
            }

        let imgRef: AnyURL? = element.firstChild(xpath: "smil:img")
            .flatMap { $0.attr("src").flatMap { resolveURL($0) } }

        let refs = GuidedNavigationObject.Refs(
            text: textURL,
            img: imgRef,
            audio: audioRef
        )

        return GuidedNavigationObject(
            id: id,
            refs: refs,
            roles: roles(for: epubType)
        )
    }

    /// Resolves a `src` attribute value relative to the SMIL document URL.
    private func resolveURL(_ src: String) -> AnyURL? {
        RelativeURL(epubHREF: src).flatMap { url.resolve($0) }
    }

    /// Builds an audio URL with optional W3C Media Fragment times.
    ///
    /// Format: `audio.mp3#t=begin,end`
    private func audioURL(src: String, clipBegin: String?, clipEnd: String?) -> AnyURL? {
        guard let base = resolveURL(src) else {
            return nil
        }

        let begin = clipBegin.flatMap { SMILParser.parseClockValue($0) }
        let end = clipEnd.flatMap { SMILParser.parseClockValue($0) }

        guard begin != nil || end != nil else {
            return base
        }

        let beginStr = begin.map { formatSeconds($0) } ?? ""
        let endStr = end.map { formatSeconds($0) } ?? ""

        // Append a media fragment to the URL.
        guard var components = URLComponents(url: base.url, resolvingAgainstBaseURL: false) else {
            return base
        }
        components.fragment = "t=\(beginStr),\(endStr)"
        return components.url.flatMap { AnyURL(url: $0) }
    }

    /// Formats a seconds value, stripping the `.0` suffix for integers.
    private func formatSeconds(_ seconds: TimeInterval) -> String {
        if seconds.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(seconds))
        } else {
            return String(seconds)
        }
    }

    /// Maps an `epub:type` attribute (space-separated tokens) to roles.
    private func roles(for epubType: String?) -> [GuidedNavigationObject.Role] {
        guard
            let epubType,
            !epubType.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            return []
        }

        return epubType
            .split(separator: " ")
            .map { role(for: String($0)) }
    }

    private func role(for token: String) -> GuidedNavigationObject.Role {
        Self.epubTypeToRole[token]
            // Fall back to a full EPUB type URI role.
            ?? GuidedNavigationObject.Role("http://www.idpf.org/2007/ops/type#\(token)")
    }

    /// Mapping from EPUB type equivalent to Guided Navigation Roles.
    ///
    /// See https://readium.org/guided-navigation/roles
    private static let epubTypeToRole: [String: GuidedNavigationObject.Role] = [
        // HTML and/or ARIA

        "aside": .aside,
        "table-cell": .cell,
        "glossdef": .definition,
        "figure": .figure,
        "list": .list,
        "list-item": .listItem,
        "table-row": .row,
        "table": .table,
        "glossterm": .term,

        // DPUB ARIA 1.0

        "abstract": .abstract,
        "acknowledgments": .acknowledgments,
        "afterword": .afterword,
        "appendix": .appendix,
        "backlink": .backlink,
        "bibliography": .bibliography,
        "biblioref": .biblioref,
        "chapter": .chapter,
        "colophon": .colophon,
        "conclusion": .conclusion,
        "cover": .cover,
        "credit": .credit,
        "credits": .credits,
        "dedication": .dedication,
        "endnotes": .endnotes,
        "epigraph": .epigraph,
        "epilogue": .epilogue,
        "errata": .errata,
        "example": .example,
        "footnote": .footnote,
        "foreword": .foreword,
        "glossary": .glossary,
        "glossref": .glossref,
        "index": .index,
        "introduction": .introduction,
        "noteref": .noteref,
        "notice": .notice,
        "pagebreak": .pagebreak,
        "page-list": .pagelist,
        "part": .part,
        "preface": .preface,
        "prologue": .prologue,
        "pullquote": .pullquote,
        "qna": .qna,
        "subtitle": .subtitle,
        "tip": .tip,
        "toc": .toc,

        // EPUB 3 Structural Semantics Vocabulary 1.1

        "landmarks": .landmarks,
        "loa": .loa,
        "loi": .loi,
        "lot": .lot,
        "lov": .lov,
    ]
}

/// Warning raised when parsing a model object from its SMIL representation
/// fails.
public struct SMILWarning: Warning {
    /// Type of the model object to be parsed.
    public let modelType: Any.Type
    /// Details about the failure.
    public let reason: String
    /// Source XML element.
    public let source: ReadiumFuzi.XMLElement?
    public let severity: WarningSeverityLevel
    public var tag: String {
        "smil"
    }

    public var message: String {
        "SMIL \(modelType): \(reason)"
    }
}

private extension WarningLogger {
    func log(_ reason: String, model: Any.Type, source: ReadiumFuzi.XMLElement, severity: WarningSeverityLevel = .major) {
        log(SMILWarning(modelType: model, reason: reason, source: source, severity: severity))
    }
}
