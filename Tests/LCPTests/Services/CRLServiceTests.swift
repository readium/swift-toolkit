//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumLCP
@testable import ReadiumShared
import Testing

enum CRLServiceTests {
    struct IsX509CRL {
        /// Also covers the long form length header, `0x30 0x82 ...`.
        @Test func acceptsTheRealCRL() {
            #expect(CRLService.isX509CRL(realCRL))
        }

        @Test func rejectsACaptivePortalPage() {
            #expect(!CRLService.isX509CRL(captivePortalPage))
        }

        @Test func rejectsEmptyData() {
            #expect(!CRLService.isX509CRL(Data()))
        }

        @Test func rejectsATruncatedCRL() {
            #expect(!CRLService.isX509CRL(realCRL.dropLast(8)))
        }

        @Test func rejectsTrailingBytes() {
            #expect(!CRLService.isX509CRL(realCRL + Data([0x00, 0x01])))
        }

        /// 0x30 is also the ASCII digit `0`, so a text body can pass the tag check.
        @Test func rejectsTextStartingWithAZero() {
            #expect(!CRLService.isX509CRL("0".data(using: .utf8)!))
            #expect(!CRLService.isX509CRL("0 requests served".data(using: .utf8)!))
        }

        /// The indefinite length form is illegal in DER.
        @Test func rejectsIndefiniteLength() {
            #expect(!CRLService.isX509CRL(Data([0x30, 0x80, 0x30, 0x00, 0x00, 0x00])))
        }
    }

    struct Retrieve {
        /// A cache poisoned by a previous version must not be served for the
        /// seven days of its expiration.
        @Test func refetchesAPoisonedCache() async throws {
            let defaults = makeDefaults()
            seedCache(defaults, crl: pem(captivePortalPage), daysAgo: 0)
            let client = MockHTTPClient(body: realCRL)
            let service = CRLService(httpClient: client, defaults: defaults)

            let crl = try await service.retrieve()

            #expect(crl == pem(realCRL))
            #expect(client.requestCount == 1)
        }

        @Test func returnsAFreshCacheWithoutFetching() async throws {
            let defaults = makeDefaults()
            seedCache(defaults, crl: pem(realCRL), daysAgo: 1)
            let client = MockHTTPClient(body: otherCRL)
            let service = CRLService(httpClient: client, defaults: defaults)

            let crl = try await service.retrieve()

            #expect(crl == pem(realCRL))
            #expect(client.requestCount == 0)
        }

        @Test func aCaptivePortalRefreshLeavesTheCacheIntact() async throws {
            let defaults = makeDefaults()
            seedCache(defaults, crl: pem(realCRL), daysAgo: 8)
            let client = MockHTTPClient(body: captivePortalPage)
            let service = CRLService(httpClient: client, defaults: defaults)

            let crl = try await service.retrieve()
            #expect(crl == pem(realCRL))

            // Waits for the background refresh to receive the portal page.
            var responses = client.responses.makeAsyncIterator()
            _ = await responses.next()

            #expect(cachedCRL(in: defaults) == pem(realCRL))
        }
    }
}

// MARK: - Fixtures

/// The real CRL served by EDRLab at
/// http://crl.edrlab.telesec.de/rl/EDRLab_CA.crl, captured on 2026-09-09.
private let realCRL = Data(base64Encoded: """
MIICkTCCAXkCAQEwDQYJKoZIhvcNAQELBQAwQjETMBEGA1UEChMKZWRybGFiLm9yZzEXMBUGA1UE
CxMOZWRybGFiLm9yZyBMQ1AxEjAQBgNVBAMTCUVEUkxhYiBDQRcNMjYwOTA5MTQxNzEyWhcNMjYw
OTE0MTQxNzExWjCB0DAnAgg9/PrnYyy4ABcNMjYwODA1MjAyMTEzWjAMMAoGA1UdFQQDCgEBMCgC
CQCoPyWN9DqSBhcNMjYwNTI1MDc1NTAwWjAMMAoGA1UdFQQDCgEGMCgCCQCwrtK1lYNPKhcNMjYw
ODI4MTcyNzQ1WjAMMAoGA1UdFQQDCgEGMCcCCAD7am95HSWbFw0yNjAzMjMxMjQ1NThaMAwwCgYD
VR0VBAMKAQYwKAIJAKjr9Zx5OfipFw0yNjAyMTIxMDE0MDJaMAwwCgYDVR0VBAMKAQagMDAuMB8G
A1UdIwQYMBaAFNxc/JPkH5/usLrqUgsrylJc4MmHMAsGA1UdFAQEAgIN+jANBgkqhkiG9w0BAQsF
AAOCAQEAVbgTkkd9dCzzEACaKDZMSgMulGJPsR15EXDS6WJ1oGf/rnEeyEfw1EBS50hU9LQkXAY1
XPLzS6Yd+X2BTsEvMcDDZJis5qottJhk6/o58qyhwdXt0wjs3p4l0rHI1qh8CpXpTJ+DaOwoHwU1
sqQECrk6FYtvGshSmNMA3CjqlcsS42UYWzgxKXOZruHkrqkxTTf5t0yo84DZ8dXIIJi2UU4L/Hi8
Y3JAADbQFvX0NTa8oj7BT0Y06wTSZRtYQIMNMgCOOOl4mRaI3YFv5KNG/eBfPVHAGwA0eDvgbyvz
cRCpyRJbvFlQVNsnlNZotD6eWItXNVYCie1FobRNAMPnYw==
""", options: .ignoreUnknownCharacters)!

/// A second payload with the shape of a CRL, to tell a fetched CRL apart from a
/// cached one.
private let otherCRL = Data([0x30, 0x04, 0x30, 0x02, 0x05, 0x00])

private let captivePortalPage = "<!DOCTYPE html><html><body>Please sign in</body></html>"
    .data(using: .utf8)!

// MARK: - Helpers

/// Wraps `der` the way `CRLService` caches a fetched CRL.
private func pem(_ der: Data) -> String {
    "-----BEGIN X509 CRL-----\(der.base64EncodedString())-----END X509 CRL-----"
}

/// Returns defaults isolated from the other tests and from the real ones.
private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "crl-tests-\(UUID().uuidString)")!
}

private func seedCache(_ defaults: UserDefaults, crl: String, daysAgo: Int) {
    defaults.set(crl, forKey: crlKey)
    defaults.set(Date().addingTimeInterval(-Double(daysAgo) * 24 * 60 * 60), forKey: crlDateKey)
}

private func cachedCRL(in defaults: UserDefaults) -> String? {
    defaults.string(forKey: crlKey)
}

private let crlKey = "org.readium.r2-lcp-swift.CRL"
private let crlDateKey = "org.readium.r2-lcp-swift.CRLDate"
