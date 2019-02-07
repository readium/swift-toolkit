//
//  LicenseValidation.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 07.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2LCPClient

func scheduleOnMainThreadIfNeeded(_ block: @escaping () -> Void) {
    if (Thread.isMainThread) {
        block()
    } else {
        DispatchQueue.main.async(execute: block)
    }
}


final class LicenseValidation {
    
    typealias Completion = (Result<ValidatedLicense>) -> Void
    typealias ValidatedLicense = (LicenseDocument, StatusDocument?, DRMContext)
    
    fileprivate let supportedProfiles: [String]
    fileprivate let passphrases: PassphrasesService
    fileprivate let device: DeviceService
    fileprivate let crl: CrlService
    fileprivate var completion: ((Result<ValidatedLicense>) -> Void)?
    
    // Already validated license used as a fallback when the newly fetched one fails to validate.
    fileprivate var fallbackLicense: ValidatedLicense?
    
    // Current state in the validation steps.
    fileprivate var state: State = .start {
        didSet {
            print("* State \(state)")
            handle(state)
        }
    }

    init(supportedProfiles: [String], passphrases: PassphrasesService, device: DeviceService, crl: CrlService) {
        self.supportedProfiles = supportedProfiles
        self.passphrases = passphrases
        self.device = device
        self.crl = crl
    }
    
    func validate(_ licenseData: Data) -> AsyncResult<ValidatedLicense> {
        return .init { completion in
            guard case .start = self.state else {
                completion(.failure(.cancelled))  // FIXME: better error?
                return
            }
            
            self.completion = completion
            self.raise(.retrievedLicenseData(licenseData))
        }
    }
    
}

/// Implementation of the License Validation statechart, as described here: https://github.com/readium/architecture/tree/master/other/lcp
/// More information about statecharts: https://statecharts.github.io
extension LicenseValidation {

    fileprivate enum State {
        case start
        
        // validation steps
        case validateLicense(Data, StatusDocument?)
        case requestPassphrase(LicenseDocument, StatusDocument?)
        case validateIntegrity(LicenseDocument, StatusDocument?, passphrase: String)
        case fetchStatus(LicenseDocument, DRMContext)
        case checkStatus(LicenseDocument, StatusDocument, DRMContext)
        case registerDevice(LicenseDocument, StatusDocument, DRMContext)
        case fetchLicense(StatusDocument)

        // final states
        case valid(LicenseDocument, StatusDocument?, DRMContext)
        case failure(LcpError)
    }
    
    fileprivate enum Event {
        case retrievedLicenseData(Data)  // either from a local container, or from LCP server
        case validatedLicense(LicenseDocument)
        case retrievedPassphrase(String)
        case validatedIntegrity(DRMContext)
        case retrievedStatus(StatusDocument)
        case checkedStatus
        case registeredDevice(skipped: Bool)
        case failed(LcpError)
    }

    /// Statechart's transitions
    /// This is where the decisions are taken: what to do next, should we go back to a previous state, etc.
    /// You should be able to draw the chart just by looking at the state and their possible transitions (event).
    fileprivate func raise(_ event: Event) {
        scheduleOnMainThreadIfNeeded {
            do {
                self.state = try {
                    print(" -> on \(event)")
                    switch (self.state, event) {
    
                    case let (.start, .retrievedLicenseData(data)):
                        return .validateLicense(data, nil)
    
                    // 1/ Validate the license structure and check its profile identifier
                    case let (.validateLicense(_, status), .validatedLicense(license)):
                        return .requestPassphrase(license, status)
                    case let (.validateLicense(_, _), .failed(error)):
                        return .failure(error)
    
                    // 2/ Get the passphrase associated with the license
                    case let (.requestPassphrase(license, status), .retrievedPassphrase(passphrase)):
                        return .validateIntegrity(license, status, passphrase: passphrase)
                    case let (.requestPassphrase(_, _), .failed(error)):
                        return .failure(error)
    
                    // 3/ Validate the license integrity
                    case let (.validateIntegrity(license, status, _), .validatedIntegrity(context)):
                        // If we already have a Status Document, we skip the re-fetching to avoid any risk of infinite loop
                        if let status = status {
                            return .registerDevice(license, status, context)
                        } else {
                            return .fetchStatus(license, context)
                        }
                    case let (.validateIntegrity(_, _, _), .failed(error)):
                        return .failure(error)
    
                    // 4/ Check the license status
    
                    // 4.1/ Fetch the status document + 4.2/ Validate the structure of the status document
                    case let (.fetchStatus(license, context), .retrievedStatus(status)):
                        return .checkStatus(license, status, context)
                    case let (.fetchStatus(license, context), .failed(_)):
                        // We ignore any error while fetching the Status Document, as it is optional
                        return .valid(license, nil, context)
    
                    // 4.3/ Check that the status is "ready" or "active".
                    case let (.checkStatus(license, status, context), .checkedStatus):
                        return .registerDevice(license, status, context)
                    case let (.checkStatus(_, _, _), .failed(error)):
                        return .failure(error)
    
                    // 5/ Register the device / license
                    case let (.registerDevice(license, status, context), .registeredDevice(_)):
                        // Fetches the License Document if it was updated
                        if let updateDate = status.updated?.license,
                            license.dateOfLastUpdate() < updateDate {
                            // Saves the now-validated license, as a fallback in case the updated license fails validation.
                            self.fallbackLicense = (license, status, context)
                            return .fetchLicense(status)
                        } else {
                            return .valid(license, status, context)
                        }
    
                    // 6/ Get an updated license if needed
                    case let (.fetchLicense(status), .retrievedLicenseData(data)):
                        return .validateLicense(data, status)
                    case let (.fetchLicense(_), .failed(error)):
                        return .failure(error)
    
                    default:
                        print("Ignoring unexpected event \(event) for state \(self.state)")
                        throw NSError.cancelledError()
                    }
                }()
            } catch {}
        }
    }
    
}


/// State's handlers
extension LicenseValidation {

    private func validateLicense(data: Data) {
        guard let license = try? LicenseDocument(with: data) else {
            return raise(.failed(.invalidLcpl))
        }

        // 1.a/ Validate the license structure
        // TODO: The app checks that the license is valid (EDRLab provides a JSON schema for LCP licenses in the EDRLab github, lcp-testing-tools). It the license is invalid, the user gets a notification like "This Readium LCP license is invalid, the publication cannot be processed".

        // 1.b/ Check its profile identifier
        let profile = license.encryption.profile.absoluteString
        guard supportedProfiles.contains(profile) else {
            return raise(.failed(.profileNotSupported))
        }
        
        raise(.validatedLicense(license))
    }
    
    private func requestPassphrase(for license: LicenseDocument) {
        passphrases.request(for: license) { [weak self] result in
            switch result {
            case let .success(passphrase):
                self?.raise(.retrievedPassphrase(passphrase))
            case let .failure(error):
                self?.raise(.failed(error))
            }
        }
    }
    
    private func validateIntegrity(of license: LicenseDocument, with passphrase: String) {
        crl.retrieve { [weak self] result in
            do {
                let pemCrl = try result.get()
                let context = try createContext(jsonLicense: license.json, hashedPassphrase: passphrase, pemCrl: pemCrl)
                self?.raise(.validatedIntegrity(context))
            } catch {
                self?.raise(.failed(.invalidLicense(error)))
            }
        }
    }
    
    private func fetchStatus(of license: LicenseDocument) {
        guard let link = license.link(withRel: .status) else {
            return raise(.failed(.noStatusDocument))
        }
        
        URLSession.shared.dataTask(with: link.href) { (data, response, error) in
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data,
                let status = try? StatusDocument(data: data)
            else {
                return self.raise(.failed(.noStatusDocument))
            }
            
            self.raise(.retrievedStatus(status))
        }.resume()
    }
    
    private func checkStatus(_ document: StatusDocument) {
        // Checks the status according to 4.3/ in the specification.
        raise({
            let updatedDate = document.updated?.status
            
            switch document.status {
            case .ready, .active:
                return .checkedStatus
            case .returned:
                return .failed(.licenseStatusReturned(updatedDate))
            case .expired:
                return .failed(.licenseStatusExpired(updatedDate))
            case .revoked:
                let devicesCount = document.events.filter({ $0.type == "register" }).count
                return .failed(.licenseStatusRevoked(updatedDate, devicesCount: devicesCount))
            case .cancelled:
                return .failed(.licenseStatusCancelled(updatedDate))
            }
        }())
    }
    
    private func registerDevice(for license: LicenseDocument, using status: StatusDocument) {
        // FIXME: Right now we ignore the Status Document returned by the register API, should we revalidate it instead?
        let skipped = device.registerLicense(license, using: status)
        self.raise(.registeredDevice(skipped: skipped))
    }
    
    private func fetchLicense(from status: StatusDocument) {
        guard let link = status.link(withRel: .license) else {
            return raise(.failed(.licenseFetching))
        }
        
        URLSession.shared.dataTask(with: link.href) { [weak self] (data, response, error) in
            guard let data = data, (response as? HTTPURLResponse)?.statusCode == 200 else {
                self?.raise(.failed(.licenseFetching))
                return
            }
            
            self?.raise(.retrievedLicenseData(data))
        }.resume()
    }
    
    private func reportSuccess(with license: LicenseDocument, status: StatusDocument?, context: DRMContext) {
        guard let completion = self.completion else {
            return
        }
        completion(.success((license, status, context)))
    }
    
    private func reportFailure(with error: LcpError) {
        if let (license, status, context) = fallbackLicense {
            reportSuccess(with: license, status: status, context: context)
        } else {
            guard let completion = self.completion else {
                return
            }
            completion(.failure(error))
        }
    }

    // Boring glue to call the handlers when a state occurs
    fileprivate func handle(_ state: State) {
        switch state {
        case .start:
            break
        case let .validateLicense(data, _):
            validateLicense(data: data)
        case let .requestPassphrase(license, _):
            requestPassphrase(for: license)
        case let .validateIntegrity(license, _, passphrase):
            validateIntegrity(of: license, with: passphrase)
        case let .fetchStatus(license, _):
            fetchStatus(of: license)
        case let .checkStatus(_, status, _):
            checkStatus(status)
        case let .registerDevice(license, status, _):
            registerDevice(for: license, using: status)
        case let .fetchLicense(status):
            fetchLicense(from: status)
        case let .valid(license, status, context):
            reportSuccess(with: license, status: status, context: context)
        case let .failure(error):
            reportFailure(with: error)
        }
    }

}
