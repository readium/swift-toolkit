//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Certificate Revocation List
final class CRLService {
    // Number of days before the CRL cache expires.
    private static let expiration = 7

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

        guard let body = response.body?.base64EncodedString() else {
            throw LCPError.crlFetching
        }
        return "-----BEGIN X509 CRL-----\(body)-----END X509 CRL-----"
    }

    /// Reads the local CRL.
    private func readLocal() -> (String, Date)? {
        let defaults = UserDefaults.standard
        guard let crl = defaults.string(forKey: CRLService.crlKey),
              let date = defaults.value(forKey: CRLService.dateKey) as? Date
        else {
            return nil
        }

        return (crl, date)
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
