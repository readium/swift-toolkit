//
//  FetcherEpub.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 4/12/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared
import Fuzi

/// Protocol defining the content filters. They are implemented below and used
/// in the fetcher. They come in different flavors depending of the container
/// data mimetype.
internal protocol ContentFilters: Loggable {
    init()

    func apply(to input: SeekableInputStream,
               of publication: Publication,
               with container: Container,
               at path: String) throws -> SeekableInputStream

    func apply(to input: Data,
               of publication: Publication,
               with container: Container,
               at path: String) throws -> Data
}
// Default implementation. Do nothing.
internal extension ContentFilters {

    func apply(to input: SeekableInputStream,
                        of publication: Publication,
                        with container: Container, at path: String) throws -> SeekableInputStream {
        // Do nothing.
        return input
    }

    func apply(to input: Data,
                        of publication: Publication,
                        with container: Container, at path: String) throws -> Data {
        // Do nothing.
        return input
    }
}

/// Content filter specialization for EPUB/OEBPS.
/// Filters:
///     - Font deobfuscation using the Decoder object.
///     - HTML injections (scripts css/js).
final internal class ContentFiltersEpub: ContentFilters {

    /// Apply the Epub content filters on the content of the `input` stream para-
    /// meter.
    ///
    /// - Parameters:
    ///   - input: The InputStream containing the data to process.
    ///   - publication: The publiaction containing the resource.
    ///   - path: The path of the resource relative to the Publication.
    /// - Returns: The resource after the filters have been applyed.
    internal func apply(to input: SeekableInputStream,
                        of publication: Publication,
                        with container: Container,
                        at path: String) -> SeekableInputStream
    {
        /// Get the link for the resource.
        guard let resourceLink = publication.link(withHref: path) else {
            return input
        }
        var decodedInputStream = DRMDecoder.decoding(input, of: resourceLink, with: container.drm)
        decodedInputStream = FontDecoder.decoding(decodedInputStream,
                                                  of: resourceLink,
                                                  publication.metadata.identifier)
    
        // Inject additional content in the resource if test succeed.
        // if type == "application/xhtml+xml"
        //   if (publication layout is 'reflow' &&  resource is `not specified`)
        //     || resource is 'reflow'
        //       - inject pagination
        if let link = publication.link(withHref: path),
            ["application/xhtml+xml", "text/html"].contains(link.type),
            let baseUrl = publication.baseURL?.deletingLastPathComponent()
        {
            if publication.metadata.rendition?.layout == .reflowable
                && link.properties.layout == nil
                || link.properties.layout == .reflowable
            {
                decodedInputStream = injectReflowableHtml(in: decodedInputStream, for: publication)
            } else {
                decodedInputStream = injectFixedLayoutHtml(in: decodedInputStream, for: baseUrl)
            }
        }
        return decodedInputStream
    }

    /// Apply the epub content filters on the content of the `input` Data.
    ///
    /// - Parameters:
    ///   - input: The Data containing the data to process.
    ///   - publication: The publication containing the resource.
    ///   - path: The path of the resource relative to the Publication.
    /// - Returns: The resource after the filters have been applyed.
    internal func apply(to input: Data,
                        of publication: Publication,
                        with container: Container,
                        at path: String)  -> Data
    {
        let inputStream = DataInputStream(data: input)
        let decodedInputStream = apply(to: inputStream, of: publication, with: container, at: path)
        guard let decodedDataStream = decodedInputStream as? DataInputStream else {
            return Data()
        }
        return decodedDataStream.data
    }

    fileprivate func injectReflowableHtml(in stream: SeekableInputStream, for publication:Publication) -> SeekableInputStream {

        let bufferSize = Int(stream.length)
        var buffer = Array<UInt8>(repeating: 0, count: bufferSize)

        stream.open()
        let numberOfBytesRead = (stream as InputStream).read(&buffer, maxLength: bufferSize)
        let data = Data(bytes: buffer, count: numberOfBytesRead)

        guard var resourceHtml = String.init(data: data, encoding: String.Encoding.utf8),
            let document = try? XMLDocument(string: resourceHtml) else
        {
            return stream
        }
        
        let language = publication.metadata.languages.first ?? document.root?.attr("lang")
        let contentLayout = publication.contentLayout(forLanguage: language)
        let styleSubFolder = contentLayout.rawValue
        
        // User properties injection
        if let htmlContentStart = resourceHtml.endIndex(of: "<html") {
            let style = " style=\" " + buildUserPropertiesString(publication: publication) + "\""
            resourceHtml = resourceHtml.insert(string: style, at: htmlContentStart)
        }
        
        // RTL dir attributes injection
        if case .rtl = contentLayout.readingProgression {
            // We need to add the dir="rtl" attribute on <html> and <body> if not already present.
            // https://readium.org/readium-css/docs/CSS03-injection_and_pagination.html#right-to-left-progression
            func addRTLDir(to tagName: String, in html: String) -> String {
                guard let tagRange = html.range(of: "<\(tagName).*>", options: [.regularExpression, .caseInsensitive]),
                    // Checks if the dir= attribute already exists, in which case we don't add it again otherwise the WebView reports an error.
                    String(html[tagRange]).range(of: "dir=", options: [.regularExpression, .caseInsensitive]) == nil,
                    let tagStart = html.endIndex(of: "<\(tagName)") else
                {
                    return html
                }
                return html.insert(string: " dir=\"rtl\"", at: tagStart)
            }
            
            resourceHtml = addRTLDir(to: "html", in: resourceHtml)
            resourceHtml = addRTLDir(to: "body", in: resourceHtml)
        }
        
        // Inserting at the start of <HEAD>.
        guard let headStart = resourceHtml.endIndex(of: "<head>") else {
            log(.error, "Invalid resource")
            abort()
        }
        
        guard let baseUrl = publication.baseURL?.deletingLastPathComponent() else {
            log(.error, "Invalid host")
            abort()
        }
        

        let primaryContentLayout = publication.contentLayout
        if let preset = userSettingsUIPreset[primaryContentLayout] {
            publication.userSettingsUIPreset = preset
        }
        
        let cssBefore = getHtmlLink(forResource: "\(baseUrl)styles/\(styleSubFolder)/ReadiumCSS-before.css")
        let viewport = "<meta name=\"viewport\" content=\"width=device-width, height=device-height, initial-scale=1.0;\"/>\n"

        resourceHtml = resourceHtml.insert(string: cssBefore, at: headStart)
        resourceHtml = resourceHtml.insert(string: viewport, at: headStart)

        // Inserting at the end of <HEAD>.
        guard let headEnd = resourceHtml.startIndex(of: "</head>") else {
            log(.error, "Invalid resource")
            abort()
        }
        let cssAfter = getHtmlLink(forResource: "\(baseUrl)styles/\(styleSubFolder)/ReadiumCSS-after.css")
        let scriptUtils = getHtmlScript(forResource: "\(baseUrl)scripts/utils.js")
        let fontStyle = getHtmlFontStyle(forResource: "\(baseUrl)fonts/OpenDyslexic-Regular.otf", fontFamily: "OpenDyslexic")

        resourceHtml = resourceHtml.insert(string: cssAfter, at: headEnd)
        resourceHtml = resourceHtml.insert(string: scriptUtils, at: headEnd)
        resourceHtml = resourceHtml.insert(string: fontStyle, at: headEnd)

        let enhancedData = resourceHtml.data(using: String.Encoding.utf8)
        let enhancedStream = DataInputStream(data: enhancedData!)
        
        return enhancedStream
    }

    fileprivate func injectFixedLayoutHtml(in stream: SeekableInputStream, for baseUrl: URL) -> SeekableInputStream {

        let bufferSize = Int(stream.length)
        var buffer = Array<UInt8>(repeating: 0, count: bufferSize)

        stream.open()
        let numberOfBytesRead = (stream as InputStream).read(&buffer, maxLength: bufferSize)
        let data = Data(bytes: buffer, count: numberOfBytesRead)

        guard var resourceHtml = String.init(data: data, encoding: String.Encoding.utf8) else {
            return stream
        }
        guard let endHeadIndex = resourceHtml.startIndex(of: "</head>") else {
            log(.error, "Invalid resource")
            abort()
        }

        var includes = [String]()

        // Misc JS utils.
        includes.append(getHtmlScript(forResource: "\(baseUrl)scripts/utils.js"))

        for element in includes {
            resourceHtml = resourceHtml.insert(string: element, at: endHeadIndex)
        }

        let enhancedData = resourceHtml.data(using: String.Encoding.utf8)
        let enhancedStream = DataInputStream(data: enhancedData!)
        
        return enhancedStream
    }

    fileprivate func getHtmlLink(forResource resourceName: String) -> String {
        let prefix = "<link rel=\"stylesheet\" type=\"text/css\" href=\""
        let suffix = "\"/>\n"

        return prefix + resourceName + suffix
    }

    fileprivate func getHtmlScript(forResource resourceName: String) -> String {
        let prefix = "<script type=\"text/javascript\" src=\""
        let suffix = "\"></script>\n"

        return prefix + resourceName + suffix
    }
    
    fileprivate func getHtmlFontStyle(forResource resourceName: String, fontFamily: String) -> String {
        return "<style type=\"text/css\">@font-face{font-family: \"\(fontFamily)\"; src:url('\(resourceName)') format('opentype');}</style>\n"
    }
    
    fileprivate func buildUserPropertiesString(publication: Publication) -> String {
        var userPropertiesString = ""
        
        for property in publication.userProperties.properties {
            userPropertiesString += property.name + ": " + property.toString() + "; "
        }
        
        return userPropertiesString
    }
    
}

let ltrPreset:[ReadiumCSSName: Bool] = [
    .hyphens: false,
    .ligatures: false]

let rtlPreset:[ReadiumCSSName: Bool] = [.hyphens: false,
                                      .wordSpacing: false,
                                      .letterSpacing: false,
                                      .ligatures: true]

let cjkHorizontalPreset: [ReadiumCSSName: Bool] = [
    .textAlignment: false,
    .hyphens: false,
    .paraIndent: false,
    .wordSpacing: false,
    .letterSpacing: false]

let cjkVerticalPreset: [ReadiumCSSName: Bool] = [
    .scroll: true,
    .columnCount: false,
    .textAlignment: false,
    .hyphens: false,
    .paraIndent: false,
    .wordSpacing: false,
    .letterSpacing: false]

let userSettingsUIPreset:[ContentLayoutStyle: [ReadiumCSSName: Bool]] = [
        .ltr: ltrPreset,
        .rtl: rtlPreset,
        .cjkVertical: cjkVerticalPreset,
        .cjkHorizontal: cjkHorizontalPreset]

/// Content filter specialization for CBZ.
internal class ContentFiltersCbz: ContentFilters {
    required init() {
    }
}

/// Content filter specialization for PDF.
internal class ContentFiltersPDF: ContentFilters {
    required init() {
    }
}
