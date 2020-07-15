//
//  Streamer.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 14/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

/// Opens a `Publication` using a list of parsers.
public final class Streamer {
    
    /// Default parsers provided by Readium.
    public static let defaultParsers: [PublicationParser] = [
        EpubParser()
    ]
    
    /// `Streamer` is configured to use Readium's default parsers, which you can bypass using
    /// `ignoreDefaultParsers`. However, you can provide additional `parsers` which will take
    /// precedence over the default ones. This can also be used to provide an alternative
    /// configuration of a default parser.
    ///
    /// - Parameters:
    ///   - parsers: Parsers used to open a publication, in addition to the default parsers.
    ///   - ignoreDefaultParsers: When true, only parsers provided in parsers will be used.
    ///   - contentProtections: List of `ContentProtection` used to unlock publications. Each
    ///     `ContentProtection` is tested in the given order.
    ///   - transform: Transformation which will be applied on every parsed Publication
    ///     Components. It can be used to modify the `Manifest`, the root `Fetcher` or the list of
    ///     service factories of a `Publication`.
    ///   - openArchive: Opens an archive (e.g. ZIP, RAR), optionally protected by credentials.
    ///   - openPDF: Parses a PDF document, optionally protected by password.
    ///   - onAskCredentials: Called when a content protection wants to prompt the user for its
    ///     credentials.
    public init(
        parsers: [PublicationParser] = [],
        ignoreDefaultParsers: Bool = false,
        contentProtections: [ContentProtection] = [],
        transform: Publication.Components.Transform? = nil,
        openArchive: @escaping ArchiveFactory = DefaultArchiveFactory,
        onAskCredentials: @escaping OnAskCredentials = { _, callback in callback(nil) }
    ) {
        self.parsers = parsers + (ignoreDefaultParsers ? [] : Self.defaultParsers)
        self.contentProtections = contentProtections
        self.transform = transform
        self.openArchive = openArchive
        self.onAskCredentials = onAskCredentials
    }
    
    private let parsers: [PublicationParser]
    private let contentProtections: [ContentProtection]
    private let transform: Publication.Components.Transform?
    private let openArchive: ArchiveFactory
    private let onAskCredentials: OnAskCredentials
    
    /// Parses a `Publication` from the given file.
    ///
    /// If you are opening the publication to render it in a Navigator, you must set
    /// `allowUserInteraction`to true to prompt the user for its credentials when the publication is
    /// protected. However, set it to false if you just want to import the `Publication` without
    /// reading its content, to avoid prompting the user.
    ///
    /// When using Content Protections, you can use `sender` to provide a free object which can be
    /// used to give some context. For example, it could be the source `UIViewController` which
    /// would be used to present a credentials dialog.
    ///
    /// The `warnings` logger can be used to observe non-fatal parsing warnings, caused by
    /// publication authoring mistakes. This can be useful to warn users of potential rendering
    /// issues.
    ///
    /// - Parameters:
    ///   - file: Path to the publication file.
    ///   - allowUserInteraction: Indicates whether the user can be prompted during opening, for
    ///     example to ask their credentials.    ///
    ///   - fallbackTitle: The Publication's title is mandatory, but some formats might not have a
    ///     way of declaring a title (e.g. CBZ). In which case, `fallbackTitle` will be used.
    ///   - credentials: Credentials that Content Protections can use to attempt to unlock a
    ///     publication, for example a password.
    ///   - sender: Free object that can be used by reading apps to give some UX context when
    ///     presenting dialogs.
    ///   - warnings: Logger used to broadcast non-fatal parsing warnings.
    /// - Returns: Nil if the file was not recognized by any parser, or a `Publication.OpeningError`
    ///   in case of failure.
    public func open(file: File, allowUserInteraction: Bool, fallbackTitle: String? = nil, credentials: String? = nil, sender: Any? = nil, warnings: WarningLogger? = nil, completion: @escaping (Result<Publication, Publication.OpeningError>) -> Void) {
        // FIXME:
        let fallbackTitle = fallbackTitle ?? file.name
        
        return createFetcher(for: file, allowUserInteraction: allowUserInteraction, password: credentials, sender: sender)
            .flatMap { fetcher in
                self.openFile(at: file, with: fetcher, credentials: credentials, allowUserInteraction: allowUserInteraction, sender: sender)
            }
            .flatMap { file in
                self.parsePublication(from: file, fallbackTitle: fallbackTitle, warnings: warnings)
            }
            .resolve(on: .main, completion)
    }
    
    /// Creates the leaf fetcher which will be passed to the content protections and parsers.
    ///
    /// We attempt to open an `ArchiveFetcher`, and fall back on a `FileFetcher` if the file is not
    /// an archive.
    private func createFetcher(for file: File, allowUserInteraction: Bool, password: String?, sender: Any?) -> Deferred<Fetcher, Publication.OpeningError> {
        return deferred(on: .global(qos: .userInitiated)) {
            guard (try? file.url.checkResourceIsReachable()) == true else {
                return .failure(.notFound)
            }
            
            do {
                let fetcher = try ArchiveFetcher(url: file.url, password: password, openArchive: self.openArchive)
                return .success(fetcher)
                
            } catch ArchiveError.invalidPassword where allowUserInteraction == true {
                // Attempts to recover by asking the user for its credentials
                return self.askPassword(sender: sender)
                    .flatMap { self.createFetcher(for: file, allowUserInteraction: allowUserInteraction, password: $0, sender: sender) }

            } catch {
                return .success(FileFetcher(href: "/", path: file.url))
            }
        }
    }
    
    /// Prompts the user for a password.
    private func askPassword(sender: Any?) -> Deferred<String, Publication.OpeningError> {
        return deferred(on: .main) { success, failure in
            self.onAskCredentials(sender) { password in
                if let password = password {
                    success(password)
                } else {
                    failure(.canceled)
                }
            }
        }
    }
    
    private func openFile(at file: File, with fetcher: Fetcher, credentials: String?, allowUserInteraction: Bool, sender: Any?) -> Deferred<PublicationFile, Publication.OpeningError> {
        func unlock(using protections: [ContentProtection]) -> Deferred<ProtectedFile?, Publication.OpeningError> {
            return deferred {
                var protections = protections
                guard let protection = protections.popFirst() else {
                    // No Content Protection applied, this file is probably not protected.
                    return .success(nil)
                }
    
                return protection
                    .open(file: file, fetcher: fetcher, credentials: credentials, allowUserInteraction: allowUserInteraction, sender: sender, onAskCredentials: self.onAskCredentials)
                    .flatMap {
                        if let protectedFile = $0 {
                            return .success(protectedFile)
                        } else {
                            return unlock(using: protections)
                        }
                    }
            }
        }
        
        return unlock(using: contentProtections)
            .map { protectedFile in
                protectedFile ?? PublicationFile(file, fetcher, nil)
            }
    }
    
    private func parsePublication(from file: PublicationFile, fallbackTitle: String, warnings: WarningLogger?) -> Deferred<Publication, Publication.OpeningError> {
        return deferred(on: .global(qos: .userInitiated)) {
            var parsers = self.parsers
            var parsedComponents: Publication.Components?
            while parsedComponents == nil, let parser = parsers.popFirst() {
                do {
                    parsedComponents = try parser.parse(file: file.file, fetcher: file.fetcher, fallbackTitle: fallbackTitle, warnings: warnings)
                } catch {
                    return .failure(.parsingFailed(error))
                }
            }
            
            guard let components = parsedComponents else {
                return .failure(.unsupportedFormat)
            }
            
            let publication = components
                // Transform from the Content Protection.
                .map(file.transform)
                // Transform provided by the reading app.
                .map(self.transform)
                .build()
            
            return .success(publication)
        }
    }

}

private extension ContentProtection {
    
    func open(file: File, fetcher: Fetcher, credentials: String?, allowUserInteraction: Bool, sender: Any?, onAskCredentials: OnAskCredentials?) -> Deferred<ProtectedFile?, Publication.OpeningError> {
        return deferred { completion in
            self.open(file: file, fetcher: fetcher, credentials: credentials, allowUserInteraction: allowUserInteraction, sender: sender, onAskCredentials: onAskCredentials, completion: completion)
        }
    }

}

private typealias PublicationFile = (file: File, fetcher: Fetcher, transform: Publication.Components.Transform?)
