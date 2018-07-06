//
//  FetcherEpub.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/12/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import R2Shared
import Fuzi

/// Protocol defining the content filters. They are implemented below and used
/// in the fetcher. They come in different flavors depending of the container
/// data mimetype.
internal protocol ContentFilters {
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

    internal func apply(to input: SeekableInputStream,
                        of publication: Publication,
                        with container: Container, at path: String) throws -> SeekableInputStream {
        // Do nothing.
        return input
    }

    internal func apply(to input: Data,
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
    // File name for untils.js, using ES5 code for any version older than iOS 10.
    internal let utilsJS:String = {
        if #available(iOS 10, *) {
            return "utils.js"
        } else {
            return "utils-old.js"
        }
    } ()
    
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
        var decodedInputStream = DrmDecoder.decoding(input, of: resourceLink, with: container.drm)
        decodedInputStream = FontDecoder.decoding(decodedInputStream,
                                                  of: resourceLink,
                                                  publication.metadata.identifier)
    
        // Inject additional content in the resource if test succeed.
        // if type == "application/xhtml+xml"
        //   if (publication layout is 'reflow' &&  resource is `not specified`)
        //     || resource is 'reflow'
        //       - inject pagination
        if let link = publication.link(withHref: path),
            link.typeLink == "application/xhtml+xml" || link.typeLink == "text/html",
            let baseUrl = publication.baseUrl?.deletingLastPathComponent()
        {
            if publication.metadata.rendition.layout == .reflowable
                && link.properties.layout == nil
                || link.properties.layout == "reflowable"
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
        /// Get the link for the resource.
        guard let resourceLink = publication.link(withHref: path) else {
            return input
        }
        let inputStream = DataInputStream(data: input)
        let dataInputStream = DrmDecoder.decoding(inputStream, of: resourceLink, with: container.drm)
        var decodedInputStream = FontDecoder.decoding(dataInputStream,
                                                      of: resourceLink,
                                                      publication.metadata.identifier)

        // Inject additional content in the resource if test succeed.
        if let link = publication.link(withHref: path),
            link.typeLink == "application/xhtml+xml" || link.typeLink == "text/html",
            let baseUrl = publication.baseUrl?.deletingLastPathComponent()
        {
            if publication.metadata.rendition.layout == .reflowable
                && link.properties.layout == nil
                || link.properties.layout == "reflowable"
            {
                decodedInputStream = injectReflowableHtml(in: decodedInputStream, for: publication) as! DataInputStream
            } else {
                decodedInputStream = injectFixedLayoutHtml(in: decodedInputStream, for: baseUrl) as! DataInputStream
            }
        }
        //
        guard let decodedDataStream = decodedInputStream as? DataInputStream else {
            return Data()
        }
        return decodedDataStream.data
    }

    ////

    fileprivate func injectReflowableHtml(in stream: SeekableInputStream, for publication:Publication) -> SeekableInputStream {

        let bufferSize = Int(stream.length)
        var buffer = Array<UInt8>(repeating: 0, count: bufferSize)

        stream.open()
        let numberOfBytesRead = (stream as InputStream).read(&buffer, maxLength: bufferSize)
        let data = Data(bytes: buffer, count: numberOfBytesRead)

        guard var resourceHtml = String.init(data: data, encoding: String.Encoding.utf8) else {
            return stream
        }
        
        // Inserting in <HTML>
        guard let htmlContentStart = resourceHtml.endIndex(of: "<html") else {
            print("Invalid resource")
            abort()
        }
        
        // User properties injection
        let style = " style=\" " + buildUserPropertiesString(publication: publication) + "\""
        
        resourceHtml = resourceHtml.insert(string: style, at: htmlContentStart)
        
        // Inserting at the start of <HEAD>.
        guard let headStart = resourceHtml.endIndex(of: "<head>") else {
            print("Invalid resource")
            abort()
        }
        
        guard let baseUrl = publication.baseUrl?.deletingLastPathComponent() else {
            print("Invalid host")
            abort()
        }
        
        //publication.metadata.primaryContentLayout
        guard let document = try? XMLDocument(string: resourceHtml) else {return stream}
        
        let langAttribute = document.root?.attr("lang")
        let langType = LangType(rawString: langAttribute ?? "")
        
        let pageDirection = publication.metadata.direction
        let contentLayoutStyle = Metadata.contentlayoutStyle(for: langType, pageDirection: pageDirection)
        
        let styleSubFolder = contentLayoutStyle.rawValue
        
        if let primaryContentLayout = publication.metadata.primaryContentLayout {
            if let preset = userSettingsUIPreset[primaryContentLayout] {
                    publication.userSettingsUIPreset = preset
            }
        }
        
        let cssBefore = getHtmlLink(forResource: "\(baseUrl)styles/\(styleSubFolder)/ReadiumCSS-before.css")
        let viewport = "<meta name=\"viewport\" content=\"width=device-width, height=device-height, initial-scale=1.0;\"/>\n"

        resourceHtml = resourceHtml.insert(string: cssBefore, at: headStart)
        resourceHtml = resourceHtml.insert(string: viewport, at: headStart)

        // Inserting at the end of <HEAD>.
        guard let headEnd = resourceHtml.startIndex(of: "</head>") else {
            print("Invalid resource")
            abort()
        }
        let cssAfter = getHtmlLink(forResource: "\(baseUrl)styles/\(styleSubFolder)/ReadiumCSS-after.css")
        let scriptTouchHandling = getHtmlScript(forResource: "\(baseUrl)scripts/touchHandling.js")
        
        let scriptUtils = getHtmlScript(forResource: "\(baseUrl)scripts/\(utilsJS)")
        
        let fontStyle = getHtmlFontStyle(forResource: "\(baseUrl)fonts/OpenDyslexic-Regular.otf", fontFamily: "OpenDyslexic")

        resourceHtml = resourceHtml.insert(string: cssAfter, at: headEnd)
        resourceHtml = resourceHtml.insert(string: scriptTouchHandling, at: headEnd)
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
            print("Invalid resource")
            abort()
        }

        var includes = [String]()

        includes.append("<meta name=\"viewport\" content=\"width=1024; height=768; left=50%; top=50%; bottom=auto; right=auto; transform=translate(-50%, -50%);\"/>\n")
        /// Readium CSS -- Pagination.
        /// Readium JS.
        // Touch event bubbling.
        includes.append(getHtmlScript(forResource: "\(baseUrl)scripts/touchHandling.js"))
        // Misc JS utils.
        includes.append(getHtmlScript(forResource: "\(baseUrl)scripts/\(utilsJS)"))

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
