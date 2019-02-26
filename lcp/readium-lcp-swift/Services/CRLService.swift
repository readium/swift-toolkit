//
//  CRLService.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 07.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

/// Certificate Revocation List
final class CRLService {
    
    // Number of days before the CRL cache expires.
    private static let expiration = 7
    
    private static let crlKey = "org.readium.r2-lcp-swift.CRL"
    private static let dateKey = "org.readium.r2-lcp-swift.CRLDate"

    private let network: NetworkService
    
    init(network: NetworkService) {
        self.network = network
    }
    
    /// Retrieves the CRL either from the cache, or from EDRLab if the cache is outdated.
    func retrieve() -> Deferred<String> {
        if let (crl, date) = readLocal(), daysSince(date) < CRLService.expiration {
            return .success(crl)
        }
        
        return fetch()
            .map(saveLocal)
            .catch { error in
                // Fallback on the locally cached CRL if available
                guard let (crl, _) = self.readLocal() else {
                    throw error
                }
                return crl
            }
    }
    
    /// Fetches the updated Certificate Revocation List from EDRLab.
    private func fetch() -> Deferred<String> {
        let url = URL(string: "http://crl.edrlab.telesec.de/rl/EDRLab_CA.crl")!
        
        return network.fetch(url)
            .map { status, data in
                guard status == 200 else {
                    throw LCPError.crlFetching
                }
                return "-----BEGIN X509 CRL-----\(data.base64EncodedString())-----END X509 CRL-----";
            }
        
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
    private func saveLocal(_ crl: String) -> String {
        let defaults = UserDefaults.standard
        defaults.set(crl, forKey: CRLService.crlKey)
        defaults.set(Date(), forKey: CRLService.dateKey)
        return crl
    }
    
    private func daysSince(_ date: Date) -> Int {
        let calendar = NSCalendar.current
        let updatedCal = calendar.startOfDay(for: date)
        let currentCal = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day], from: updatedCal, to: currentCal)
        return components.day ?? Int.max
    }
    
}
