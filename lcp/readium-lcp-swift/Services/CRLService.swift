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

/// Certificate Revocation List
final class CRLService {
    
    // Number of days before the CRL cache expires.
    private static let expiration = 7
    
    private static let dateKey = "kCRLDate"
    private static let crlKey = "kCRLString"

    private let network: NetworkService
    
    init(network: NetworkService) {
        self.network = network
    }
    
    /// Retrieves the CRL either from the cache, or from EDRLab if the cache is outdated.
    func retrieve() -> Deferred<String> {
        guard let (crl, date) = readLocal(), daysSince(date) < CRLService.expiration else {
            return fetch()
        }
        
        return .success(crl)
    }
    
    /// Fetches the updated Certificate Revocation List from EDRLab.
    private func fetch() -> Deferred<String> {
        let url = URL(string: "http://crl.edrlab.telesec.de/rl/EDRLab_CA.crl")!
        
        return network.fetch(url)
            .map { status, data in
                guard status == 200 else {
                    throw LCPError.crlFetching
                }
                
                let crl = "-----BEGIN X509 CRL-----\(data.base64EncodedString())-----END X509 CRL-----";
                self.saveLocal(crl)
                return crl
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
