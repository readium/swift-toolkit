//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Certificate Revocation List
final class CRLService: Sendable {
    /// Number of days before the CRL cache expires.
    private static let expiration = 7

    private static let pemHeader = "-----BEGIN X509 CRL-----"
    private static let pemFooter = "-----END X509 CRL-----"

    private static let crlKey = "org.readium.r2-lcp-swift.CRL"
    private static let dateKey = "org.readium.r2-lcp-swift.CRLDate"

    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    /// Retrieves the CRL either from the cache, or from EDRLab if the cache is outdated.
    func retrieve() async throws -> String {
        let localCRL = readLocal()
        if let (crl, date) = localCRL, daysSince(date) < CRLService.expiration {
            return crl
        }

        // Short timeout to avoid blocking the License, since we can always fall back on the cached CRL.
        let timeout: TimeInterval? = (localCRL == nil) ? nil : 8

        do {
            let crl = try await fetch(timeout: timeout)
            saveLocal(crl)
            return crl

        } catch {
            // Fallback on the locally cached CRL if available
            guard let (crl, _) = localCRL else {
                throw error
            }
            return crl
        }
    }

    /// Fetches the updated Certificate Revocation List from EDRLab.
    private func fetch(timeout: TimeInterval? = nil) async throws -> String {
        let url = HTTPURL(string: "http://crl.edrlab.telesec.de/rl/EDRLab_CA.crl")!

        let response = try await httpClient.fetch(HTTPRequest(url: url, timeoutInterval: timeout))
            .mapError { _ in LCPError.crlFetching }
            .get()

        guard CRLService.isX509CRL(response.body) else {
            throw LCPError.crlFetching
        }

        let body = response.body.base64EncodedString()
        return "\(CRLService.pemHeader)\(body)\(CRLService.pemFooter)"
    }

    /// Reads the local CRL.
    private func readLocal() -> (String, Date)? {
        let defaults = UserDefaults.standard
        guard let crl = defaults.string(forKey: CRLService.crlKey),
              let date = defaults.value(forKey: CRLService.dateKey) as? Date,
              let der = CRLService.decodePEM(crl),
              CRLService.isX509CRL(der)
        else {
            return nil
        }

        return (crl, date)
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
        let defaults = UserDefaults.standard
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
