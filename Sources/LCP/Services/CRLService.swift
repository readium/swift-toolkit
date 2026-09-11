//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Certificate Revocation List
actor CRLService {
    /// Number of days before the CRL cache expires.
    private static let expiration = 7

    private static let pemHeader = "-----BEGIN X509 CRL-----"
    private static let pemFooter = "-----END X509 CRL-----"

    private static let crlKey = "org.readium.r2-lcp-swift.CRL"
    private static let dateKey = "org.readium.r2-lcp-swift.CRLDate"

    private let httpClient: HTTPClient
    private let defaults: UserDefaults

    /// Refresh currently in flight, if any.
    private var refreshTask: Task<String, Error>?

    /// - Parameter defaultsSuite: Name of the `UserDefaults` suite used to
    ///   cache the CRL, or `nil` for the standard one. A suite name is taken
    ///   rather than a `UserDefaults`, as the latter is not `Sendable` and
    ///   cannot be handed over to an actor.
    init(httpClient: HTTPClient, defaultsSuite: String? = nil) {
        self.httpClient = httpClient
        defaults = defaultsSuite.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    /// Warms the cache so that opening a publication does not have to wait on
    /// the network.
    func preload() {
        guard readLocal()?.isExpired ?? true else {
            return
        }
        _ = refresh()
    }

    /// Retrieves the CRL either from the cache, or from EDRLab if the cache is
    /// missing or invalid.
    ///
    /// An expired cache is returned as is and refreshed in the background, as
    /// waiting on the network would delay the opening of a publication.
    func retrieve() async throws -> String {
        guard let (crl, isExpired) = readLocal() else {
            return try await refresh().value
        }

        if isExpired {
            _ = refresh()
        }
        return crl
    }

    /// Starts a CRL refresh, or returns the one already in flight.
    private func refresh() -> Task<String, Error> {
        if let refreshTask {
            return refreshTask
        }

        let task = Task(priority: .utility) {
            defer { refreshTask = nil }

            let crl = try await fetch()
            saveLocal(crl)
            return crl
        }
        refreshTask = task
        return task
    }

    /// Fetches the updated Certificate Revocation List from EDRLab.
    private func fetch() async throws -> String {
        let url = HTTPURL(string: "http://crl.edrlab.telesec.de/rl/EDRLab_CA.crl")!

        let response = try await httpClient.fetch(HTTPRequest(url: url))
            .mapError { _ in LCPError.crlFetching }
            .get()

        guard CRLService.isX509CRL(response.body) else {
            throw LCPError.crlFetching
        }

        let body = response.body.base64EncodedString()
        return "\(CRLService.pemHeader)\(body)\(CRLService.pemFooter)"
    }

    /// Reads the local CRL.
    private func readLocal() -> (crl: String, isExpired: Bool)? {
        guard let crl = defaults.string(forKey: CRLService.crlKey),
              let date = defaults.value(forKey: CRLService.dateKey) as? Date,
              let der = CRLService.decodePEM(crl),
              CRLService.isX509CRL(der)
        else {
            return nil
        }

        return (crl, isExpired: daysSince(date) >= CRLService.expiration)
    }

    /// Extracts the DER payload of a PEM-encoded CRL cached by ``saveLocal(_:)``.
    private static func decodePEM(_ crl: String) -> Data? {
        guard crl.hasPrefix(pemHeader), crl.hasSuffix(pemFooter) else {
            return nil
        }
        let base64 = crl.dropFirst(pemHeader.count).dropLast(pemFooter.count)
        return Data(base64Encoded: String(base64))
    }

    /// Checks that `data` looks like a DER-encoded X.509 CRL.
    ///
    /// `CertificateList` is a `SEQUENCE` whose first element is the
    /// `tbsCertList` `SEQUENCE`. We don't parse the whole structure: this is
    /// only meant to reject payloads which are not DER at all, such as the HTML
    /// login page of a captive portal, or a truncated download.
    ///
    /// Note that `SEQUENCE { SEQUENCE, ... }` is also the shape of an X.509
    /// *certificate*. Telling them apart would mean walking into the
    /// `tbsCertList` looking for a `UTCTime`/`GeneralizedTime`, which guards a
    /// scenario – this endpoint serving the wrong DER object – with no
    /// realistic trigger.
    static func isX509CRL(_ data: Data) -> Bool {
        let bytes = [UInt8](data)

        // DER `SEQUENCE` tag.
        guard bytes.count >= 2, bytes[0] == 0x30 else {
            return false
        }

        let headerSize: Int
        let length: Int

        if bytes[1] & 0x80 == 0 {
            // Short form: the length fits in the byte itself.
            headerSize = 2
            length = Int(bytes[1])

        } else {
            // Long form: the low bits give the number of length bytes. 0x80 is
            // the indefinite form, illegal in DER, and 0xFF is reserved. We
            // also reject lengths wider than 4 bytes, way beyond any CRL.
            let lengthSize = Int(bytes[1] & 0x7F)
            guard (1 ... 4).contains(lengthSize), bytes.count >= 2 + lengthSize else {
                return false
            }
            headerSize = 2 + lengthSize
            length = bytes[2 ..< headerSize].reduce(0) { $0 << 8 | Int($1) }
        }

        // Rejects both a truncated download and trailing garbage.
        guard headerSize + length == bytes.count else {
            return false
        }

        // `tbsCertList` `SEQUENCE`.
        return bytes.count > headerSize && bytes[headerSize] == 0x30
    }

    /// Caches the given CRL.
    private func saveLocal(_ crl: String) {
        defaults.set(crl, forKey: CRLService.crlKey)
        defaults.set(Date(), forKey: CRLService.dateKey)
    }

    private func daysSince(_ date: Date) -> Int {
        let calendar = NSCalendar.current
        let updatedCal = calendar.startOfDay(for: date)
        let currentCal = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day], from: updatedCal, to: currentCal)
        return components.day ?? Int.max
    }
}
