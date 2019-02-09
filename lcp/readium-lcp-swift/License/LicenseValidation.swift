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

// When true, will show the state and transitions in the console.
private let DEBUG = true


final class LicenseValidation {
    
    typealias ValidatedLicense = (LicenseDocument, StatusDocument?, DRMContext)
    
    fileprivate let supportedProfiles: [String]
    fileprivate let passphrases: PassphrasesService
    fileprivate let licenses: LicensesRepository
    fileprivate let device: DeviceService
    fileprivate let crl: CRLService
    fileprivate let network: NetworkService
    fileprivate weak var authenticating: LCPAuthenticating?
    
    fileprivate var completion = PopVariable<(Result<ValidatedLicense>) -> Void>()
    
    // Already validated license used as a fallback when the newly fetched one fails to validate.
    fileprivate var fallbackLicense: ValidatedLicense?
    
    // Current state in the validation steps.
    fileprivate var state: State = .start {
        didSet {
            if DEBUG { print("#validation * \(state)") }
            handle(state)
        }
    }

    init(supportedProfiles: [String], passphrases: PassphrasesService, licenses: LicensesRepository, device: DeviceService, crl: CRLService, network: NetworkService, authenticating: LCPAuthenticating?) {
        self.supportedProfiles = supportedProfiles
        self.passphrases = passphrases
        self.licenses = licenses
        self.device = device
        self.crl = crl
        self.network = network
        self.authenticating = authenticating
    }
    
    func validateLicenseData(_ data: Data, _ completion: @escaping (Result<ValidatedLicense>) -> Void) {
        guard case .start = self.state else {
            completion(.failure(.cancelled))  // FIXME: better error?
            return
        }

        self.completion.set(completion)
        self.raise(.retrievedLicenseData(data))
    }
    
}

/// Implementation of the License Validation statechart, as described here: https://github.com/readium/architecture/tree/master/other/lcp
/// More information about statecharts: https://statecharts.github.io
extension LicenseValidation {

    fileprivate enum Event {
        case retrievedLicenseData(Data)  // either from a local container, or from LCP server
        case validatedLicense(LicenseDocument)
        case retrievedPassphrase(String)
        case validatedIntegrity(DRMContext)
        case retrievedStatus(StatusDocument)
        case checkedStatus
        case registeredDevice(skipped: Bool)
        case failed(LCPError)
    }

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
        case failure(LCPError)
        
        /// Statechart's transitions
        /// This is where the decisions are taken: what to do next, should we go back to a previous state, etc.
        /// You should be able to draw the chart just by looking at the states and their possible transitions (event).
        mutating func transition(_ event: Event) {
            switch (self, event) {

            case let (.start, .retrievedLicenseData(data)):
                self = .validateLicense(data, nil)

            // 1/ Validate the license structure and check its profile identifier
            case let (.validateLicense(_, status), .validatedLicense(license)):
                self = .requestPassphrase(license, status)
            case let (.validateLicense(_, _), .failed(error)):
                self = .failure(error)

            // 2/ Get the passphrase associated with the license
            case let (.requestPassphrase(license, status), .retrievedPassphrase(passphrase)):
                self = .validateIntegrity(license, status, passphrase: passphrase)
            case let (.requestPassphrase(_, _), .failed(error)):
                self = .failure(error)

            // 3/ Validate the license integrity
            case let (.validateIntegrity(license, status, _), .validatedIntegrity(context)):
                // If we already have a Status Document, we skip the re-fetching to avoid any risk of infinite loop
                if let status = status {
                    self = .registerDevice(license, status, context)
                } else {
                    self = .fetchStatus(license, context)
                }
            case let (.validateIntegrity(_, _, _), .failed(error)):
                self = .failure(error)

            // 4/ Check the license status

            // 4.1/ Fetch the status document + 4.2/ Validate the structure of the status document
            case let (.fetchStatus(license, context), .retrievedStatus(status)):
                self = .checkStatus(license, status, context)
            case let (.fetchStatus(license, context), .failed(_)):
                // We ignore any error while fetching the Status Document, as it is optional
                self = .valid(license, nil, context)

            // 4.3/ Check that the status is "ready" or "active".
            case let (.checkStatus(license, status, context), .checkedStatus):
                self = .registerDevice(license, status, context)
            case let (.checkStatus(_, _, _), .failed(error)):
                self = .failure(error)

            // 5/ Register the device / license
            case let (.registerDevice(license, status, context), .registeredDevice(_)):
                // Fetches the License Document if it was updated
                if let updateDate = status.updated?.license,
                    license.dateOfLastUpdate() < updateDate {
                    self = .fetchLicense(status)
                } else {
                    self = .valid(license, status, context)
                }

            // 6/ Get an updated license if needed
            case let (.fetchLicense(status), .retrievedLicenseData(data)):
                self = .validateLicense(data, status)
            case let (.fetchLicense(_), .failed(error)):
                self = .failure(error)

            default:
                if DEBUG { print("#validation Ignoring unexpected event \(event) for state \(self)") }
            }
        }
    }

    fileprivate func raise(_ event: Event) {
        dispatchOnMainThreadIfNeeded { [weak self] in
            guard let `self` = self else { return }

            // A few dirty side-effects, maybe it should be refactored somewhere else... External event handlers maybe?
            var event = event
            
            switch (self.state, event) {
                
            case (.validateIntegrity(let license, _, _), .validatedIntegrity(_)):
                // Saves the license in the local database once we validated its integrity
                do {
                    try self.licenses.addOrUpdateLicense(license)
                } catch {
                    event = .failed(LCPError.wrap(error))
                }

            case let (.checkStatus(license, status, context), .checkedStatus):
                // Updates the license's state in the local database
                try? self.licenses.updateLicenseStatus(license, to: status)
                // Saves the now-validated license as a fallback, in case the updated license fails validation
                self.fallbackLicense = (license, status, context)
                
            default:
                break
            }

            if DEBUG { print("#validation -> on \(event)") }
            self.state.transition(event)
        }
    }
    
    /// Syntactic sugar to raise an event from a Result enum.
    /// If the result is a failure, then the error is raised as an Event.failed.
    fileprivate func raise(_ result: Result<Event>) {
        raise(result.map(
            success: { $0 },
            failure: { .failed($0) }
        ))
    }
    
}


/// State's handlers
extension LicenseValidation {

    private func validateLicense(data: Data) {
        guard let license = try? LicenseDocument(with: data) else {
            return raise(.failed(.invalidLCPL))
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
        deferred { self.passphrases.request(for: license, authenticating: self.authenticating, completion: $0) }
            .map { Event.retrievedPassphrase($0) }
            .resolve(raise)
    }
    
    private func validateIntegrity(of license: LicenseDocument, with passphrase: String) {
        deferred { self.crl.retrieve($0) }
            .map { pemCRL -> Event in
                // FIXME: Is this really useful? According to the spec this is already checked by the lcplib.a
                try {
                    /// Check that current date is inside the [end - start] right's dates range.
                    let now = Date.init()
                    if let start = license.rights.start,
                        !(now > start) {
                        throw LCPError.invalidRights
                    }
                    if let end = license.rights.end,
                        !(now < end) {
                        throw LCPError.invalidRights
                    }
                }()
                
                let context = try createContext(jsonLicense: license.json, hashedPassphrase: passphrase, pemCrl: pemCRL)
                return .validatedIntegrity(context)
            }
            .resolve(raise)
    }
    
    private func fetchStatus(of license: LicenseDocument) {
        guard let link = license.link(withRel: .status) else {
            return raise(.failed(.noStatusDocument))
        }
        
        deferred { self.network.fetch(link.href, $0) }
            .map { status, data -> Event in
                guard status == 200 else {
                    throw LCPError.noStatusDocument
                }
                
                let document = try StatusDocument(data: data)
                return .retrievedStatus(document)
            }
            .resolve(raise)
    }
    
    private func checkStatus(_ document: StatusDocument) {
        // Checks the status according to 4.3/ in the specification.
        let updatedDate = document.updated?.status

        switch document.status {
        case .ready, .active:
            raise(.checkedStatus)
        case .returned:
            raise(.failed(.licenseStatusReturned(updatedDate)))
        case .expired:
            raise(.failed(.licenseStatusExpired(updatedDate)))
        case .revoked:
            let devicesCount = document.events.filter({ $0.type == "register" }).count
            raise(.failed(.licenseStatusRevoked(updatedDate, devicesCount: devicesCount)))
        case .cancelled:
            raise(.failed(.licenseStatusCancelled(updatedDate)))
        }
    }
    
    private func registerDevice(for license: LicenseDocument, using status: StatusDocument) {
        // FIXME: Right now we ignore the Status Document returned by the register API, should we revalidate it instead?
        let skipped = device.registerLicense(license, using: status)
        raise(.registeredDevice(skipped: skipped))
    }
    
    private func fetchLicense(from status: StatusDocument) {
        guard let link = status.link(withRel: .license) else {
            return raise(.failed(.licenseFetching))
        }
        
        deferred { self.network.fetch(link.href, $0) }
            .map { status, data -> Event in
                guard status == 200 else {
                    throw LCPError.licenseFetching
                }
                return .retrievedLicenseData(data)
            }
            .resolve(raise)
    }
    
    private func reportSuccess(license: LicenseDocument, status: StatusDocument?, context: DRMContext) {
        guard let completion = self.completion.pop() else {
            return
        }
        completion(.success((license, status, context)))
    }
    
    private func reportFailure(_ error: LCPError) {
        if let (license, status, context) = fallbackLicense {
            reportSuccess(license: license, status: status, context: context)
        } else {
            guard let completion = self.completion.pop() else {
                return
            }
            completion(.failure(error))
        }
    }

    fileprivate func handle(_ state: State) {
        // Boring glue to call the handlers when a state occurs
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
            reportSuccess(license: license, status: status, context: context)
        case let .failure(error):
            reportFailure(error)
        }
    }

}
