//
//  CrlService.swift
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
final class CrlService {
    
    private static let dateKey = "kCRLDate"
    private static let crlKey = "kCRLString"
    
    /// Retrieves the CRL either from the cache, or from EDRLab if the cache is outdated.
    func retrieve(completion: @escaping (Result<String>) -> Void) {
        guard let (crl, date) = readLocal(),
            daysSince(date) < 7
        else {
            fetch(completion: completion)
            return
        }
        
        completion(.success(crl))
    }
    
    /// Fetches the updated Certificate Revocation List from EDRLab.
    private func fetch(completion: @escaping (Result<String>) -> Void) {
        let url = URL(string: "http://crl.edrlab.telesec.de/rl/EDRLab_CA.crl")!
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard (response as? HTTPURLResponse)?.statusCode == 200, let data = data else {
                completion(.failure(.crlFetching))
                return
            }
            
            let crl = "-----BEGIN X509 CRL-----\(data.base64EncodedString())-----END X509 CRL-----";
            self.saveLocal(crl)
            completion(.success(crl))
        }.resume()
    }
    
    /// Reads the local CRL.
    private func readLocal() -> (String, Date)? {
        let defaults = UserDefaults.standard
        guard let crl = defaults.string(forKey: CrlService.crlKey),
            let date = defaults.value(forKey: CrlService.dateKey) as? Date
            else {
                return nil
        }
        
        return (crl, date)
    }
    
    /// Caches the given CRL.
    private func saveLocal(_ crl: String) {
        let defaults = UserDefaults.standard
        defaults.set(crl, forKey: CrlService.crlKey)
        defaults.set(Date(), forKey: CrlService.dateKey)
    }
    
    private func daysSince(_ date: Date) -> Int {
        let calendar = NSCalendar.current
        let updatedCal = calendar.startOfDay(for: date)
        let currentCal = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day], from: updatedCal, to: currentCal)
        return components.day ?? Int.max
    }
    
}
