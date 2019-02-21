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
import R2Shared


/// To modify depending of the profiles supported by liblcp.a.
private let supportedProfiles = [
    "http://readium.org/lcp/basic-profile",
    "http://readium.org/lcp/profile-1.0",
]


typealias Context = Either<DRMContext, StatusError>


// Holds the License/Status Documents and the DRM context, once validated.
struct ValidatedDocuments {
    let license: LicenseDocument
    fileprivate let context: Context
    let status: StatusDocument?

    fileprivate init(_ license: LicenseDocument, _ context: Context, _ status: StatusDocument? = nil) {
        self.license = license
        self.context = context
        self.status = status
    }

    func getContext() throws -> DRMContext {
        switch context {
        case .left(let context):
            return context
        case .right(let error):
            throw error
        }
    }
    
}


/// Validation workflow of the License and Status Documents.
///
/// Use `validate` to start the validation of a Document.
/// Use `observe` to be notified when any validation is done or if an error occurs.
final class LicenseValidation: Loggable {

    // Dependencies for the State's handlers
    fileprivate weak var authentication: LCPAuthenticating?
    fileprivate let crl: CRLService
    fileprivate let device: DeviceService
    fileprivate let network: NetworkService
    fileprivate let passphrases: PassphrasesService

    // Last License and DRM context after a successful integrity check. Used as a fallback if the Status Document requires to update the License but the new one fails the integrity check.
    fileprivate var previousLicense: (LicenseDocument, DRMContext)?
    
    // List of observers notified when the Documents are validated, or if an error occurred.
    fileprivate var observers: [(callback: Observer, policy: ObserverPolicy)] = []
    
    fileprivate let onValidateIntegrity: (LicenseDocument) throws -> Void

    // Current state in the validation steps.
    private(set) var state: State = .start {
        didSet {
            log(.debug, "* \(state)")
            handle(state)
        }
    }

    init(authentication: LCPAuthenticating?, crl: CRLService, device: DeviceService, network: NetworkService, passphrases: PassphrasesService, onValidateIntegrity: @escaping (LicenseDocument) throws -> Void) {
        self.authentication = authentication
        self.crl = crl
        self.device = device
        self.network = network
        self.passphrases = passphrases
        self.onValidateIntegrity = onValidateIntegrity
    }

    // Raw Document's data to validate.
    enum Document {
        case license(Data)
        case status(Data)
    }
    
    /// Validates the given License or Status Document.
    /// If a validation is already running, LCPError.licenseIsBusy will be reported.
    func validate(_ document: Document) -> Deferred<ValidatedDocuments> {
        return Deferred { completion in
            let event: Event
            switch (self.state, document) {
                
            // A License Document can only be validated when opening intially the License, or when a Status Document requires a License update.
            case let (.start, .license(data)):
                event = .retrievedLicenseData(data)
            
            // A Status Document can only be validated when the License validation is done.
            case let (.valid, .status(data)):
                event = .retrievedStatusData(data)

            case let (.failure(error), _):
                throw error
                
            default:
                throw LCPError.licenseIsBusy
            }
            
            self.observe(.once, completion)
            try self.raise(event)
        }
    }

}


/// Validation statechart
///
/// The validation workflow is implemented using a Statechart pattern, following the specification here: https://github.com/readium/architecture/tree/master/other/lcp
/// Basically, the validation is in a given State that holds any working data and which progresses by handling Events.
/// This allows to decouple the flow decision from the services doing the actual work.
/// More information about statecharts: https://statecharts.github.io
extension LicenseValidation {

    enum State {
        case start
        
        // Validation steps
        case validateLicense(Data, StatusDocument?)
        case requestPassphrase(LicenseDocument, StatusDocument?)
        case validateIntegrity(LicenseDocument, StatusDocument?, passphrase: String)
        case fetchStatus(LicenseDocument, Context)
        case validateStatus(LicenseDocument, Context, Data)
        case fetchLicense(LicenseDocument, Context, StatusDocument)
        case checkLicenseStatus(LicenseDocument, Context, StatusDocument)
        case registerDevice(LicenseDocument, Context, StatusDocument)

        // Final states
        case valid(ValidatedDocuments)
        case failure(Error)
        
        /// Transitions the State when an Event is raised.
        /// This is where the decisions are taken: what to do next, should we go back to a previous state, etc.
        /// You should be able to draw the chart just by looking at the states and their possible transitions.
        fileprivate mutating func transition(_ event: Event) throws {
            switch (self, event) {

            // Start the validation when opening the License from its container.
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
            case let (.validateIntegrity(_, status, _), .validatedIntegrity(license, context)):
                // If we already have a Status Document, we skip the re-fetching to avoid any risk of infinite loop
                if let status = status {
                    self = .checkLicenseStatus(license, .left(context), status)
                } else {
                    self = .fetchStatus(license, .left(context))
                }
            case let (.validateIntegrity(_, _, _), .failed(error)):
                self = .failure(error)

            // 4.1/ Fetch the status document
            case let (.fetchStatus(license, context), .retrievedStatusData(data)):
                self = .validateStatus(license, context, data)
            case let (.fetchStatus(license, context), .failed(_)):
                // We ignore any error while fetching the Status Document, as it is optional
                self = .valid(ValidatedDocuments(license, context))

            // 4.2/ Validate the structure of the status document
            case let (.validateStatus(license, context, _), .validatedStatus(status)):
                // Fetches the License Document if it was updated
                if license.updated < status.licenseUpdated {
                    self = .fetchLicense(license, context, status)
                } else {
                    self = .checkLicenseStatus(license, context, status)
                }
            case let (.validateStatus(license, context, _), .failed(_)):
                // We ignore any error while validating the Status Document, as it is optional
                self = .valid(ValidatedDocuments(license, context))

            // 5/ Get an updated license if needed
            case let (.fetchLicense(_, _, status), .retrievedLicenseData(data)):
                self = .validateLicense(data, status)
            case let (.fetchLicense(license, context, status), .failed(_)):
                // Failures when updating the license are ignored
                self = .checkLicenseStatus(license, context, status)

            // 6/ Check the license status
            case let (.checkLicenseStatus(license, context, status), .checkedLicenseStatus(error)):
                if let error = error {
                    self = .valid(ValidatedDocuments(license, .right(error), status))
                } else {
                    self = .registerDevice(license, context, status)
                }

            // 7/ Register the device / license
            case let (.registerDevice(license, context, status), .registeredDevice(statusData)):
                if let statusData = statusData {
                    self = .validateStatus(license, context, statusData)
                } else {
                    self = .valid(ValidatedDocuments(license, context, status))
                }
            case let (.registerDevice(license, context, status), .failed(_)):  // Failures when registrating the device are ignored
                self = .valid(ValidatedDocuments(license, context, status))

            // Re-validate a new Status Document (for example, after calling an LSD interaction
            case let (.valid(documents), .retrievedStatusData(data)):
                self = .validateStatus(documents.license, documents.context, data)

            default:
                throw LCPError.runtime("\(type(of: self)): Unexpected event \(event) for state \(self)")
            }
        }
    }
    
    fileprivate enum Event {
        // Raised when reading the License from its container, or when updating it from an LCP server.
        case retrievedLicenseData(Data)
        // Raised when the License Document is parsed and its structure is validated.
        case validatedLicense(LicenseDocument)
        // Raised when we retrieved the passphrase from the local database, or from prompting the user.
        case retrievedPassphrase(String)
        // Raised after validating the integrity of the License using liblcp.a. If it fails, then the previously validated License is returned.
        case validatedIntegrity(LicenseDocument, DRMContext)
        // Raised after fetching the Status Document, or receiving it as a response of an LSD interaction.
        case retrievedStatusData(Data)
        // Raised after parsing and validating a Status Document's data.
        case validatedStatus(StatusDocument)
        // Raised after the License's status was checked, with any occurred status error.
        case checkedLicenseStatus(StatusError?)
        // Raised when the device is registered, with an optional updated Status Document.
        case registeredDevice(Data?)
        // Raised when any error occurs during the validation workflow.
        case failed(Error)
    }
    
    /// Should be called by the state handlers once they're done, to go to the next State.
    fileprivate func raise(_ event: Event) throws {
        log(.debug, "-> on \(event)")
        guard Thread.isMainThread else {
            throw LCPError.runtime("\(type(of: self)): To be safe, events must only be raised from the main thread")
        }
        
        try state.transition(event)
    }

}


/// State's handlers
extension LicenseValidation {

    private func validateLicense(data: Data) throws {
        let license = try LicenseDocument(data: data)

        // 1.a/ Validate the license structure
        // TODO: The app checks that the license is valid (EDRLab provides a JSON schema for LCP licenses in the EDRLab github, lcp-testing-tools). It the license is invalid, the user gets a notification like "This Readium LCP license is invalid, the publication cannot be processed".

        // 1.b/ Check its profile identifier
        let profile = license.encryption.profile
        guard supportedProfiles.contains(profile) else {
            throw LCPError.licenseProfileNotSupported
        }

        try raise(.validatedLicense(license))
    }
    
    private func requestPassphrase(for license: LicenseDocument) {
        passphrases.request(for: license, authentication: authentication)
            .map { Event.retrievedPassphrase($0) }
            .resolve(raise)
    }
    
    private func validateIntegrity(of license: LicenseDocument, with passphrase: String) {
        crl.retrieve()
            .map { crl -> (LicenseDocument, DRMContext) in
                let context = try createContext(jsonLicense: license.json, hashedPassphrase: passphrase, pemCrl: crl)

                try self.onValidateIntegrity(license)
                self.previousLicense = (license, context)
                return (license, context)
            }
            .catch { error in
                // Small hack to be able to save the license in the container when it is expired. Since it's considered as an integrity error by lcplib, we have to manually handle it.
                // FIXME: If possible, lcplib should provide a way to test the integrity of a license without checking its rights.
                if case LCPClientError.licenseOutOfDate = error {
                    try self.onValidateIntegrity(license)
                    self.previousLicense = nil  // Resets previous license to avoid the fallback in this case
                }
                
                // Recovers the previously validated license to continue the workflow if the current license is compromised.
                if let license = self.previousLicense {
                    self.log(.warning, "Recovers from compromised License Document using previous License")
                    return license
                }
                throw error
            }
            .map { .validatedIntegrity($0, $1) }
            .resolve(raise)
    }

    private func fetchStatus(of license: LicenseDocument) throws {
        let url = try license.url(for: .status)
        network.fetch(url)
            .map { status, data -> Event in
                guard status == 200 else {
                    throw LCPError.cancelled
                }
                
                return .retrievedStatusData(data)
            }
            .resolve(raise)
    }
    
    private func validateStatus(data: Data) throws {
        let status = try StatusDocument(data: data)
        try raise(.validatedStatus(status))
    }

    private func fetchLicense(from status: StatusDocument) throws {
        let url = try status.url(for: .license)
        network.fetch(url)
            .map { status, data -> Event in
                guard status == 200 else {
                    throw LCPError.cancelled
                }
                return .retrievedLicenseData(data)
            }
            .resolve(raise)
    }
    
    private func checkLicenseStatus(_ status: StatusDocument) throws {
        // Checks the status according to 4.3/ in the specification.
        let date = status.updated
        
        let error: StatusError?
        switch status.status {
        case .ready, .active:
            error = nil
        case .returned:
            error = .returned(date)
        case .expired:
            error = .expired(date)
        case .revoked:
            let devicesCount = status.events(for: .register).count
            error = .revoked(date, devicesCount: devicesCount)
        case .cancelled:
            error = .cancelled(date)
        }
        
        try raise(.checkedLicenseStatus(error))
    }
    
    private func registerDevice(for license: LicenseDocument, using status: StatusDocument) {
        device.registerLicense(license, using: status)
            .map { data in .registeredDevice(data) }
            .resolve(raise)
    }

    fileprivate func handle(_ state: State) {
        // Boring glue to call the handlers when a state occurs
        do {
            switch state {
            case .start:
                break
            case let .validateLicense(data, _):
                try validateLicense(data: data)
            case let .requestPassphrase(license, _):
                requestPassphrase(for: license)
            case let .validateIntegrity(license, _, passphrase):
                validateIntegrity(of: license, with: passphrase)
            case let .fetchStatus(license, _):
                try fetchStatus(of: license)
            case let .validateStatus(_, _, data):
                try validateStatus(data: data)
            case let .fetchLicense(_, _, status):
                try fetchLicense(from: status)
            case let .checkLicenseStatus(_, _, status):
                try checkLicenseStatus(status)
            case let .registerDevice(license, _, status):
                registerDevice(for: license, using: status)
            case let .valid(documents):
                notifyObservers(documents: documents, error: nil)
            case let .failure(error):
                notifyObservers(documents: nil, error: error)
            }
        } catch {
            try? raise(.failed(error))
        }
    }
    
    /// Syntactic sugar to raise either the given event, or an error wrapped as an Event.failed.
    /// Can be used to resolve a Deferred<Event>.
    fileprivate func raise(_ event: Event?, or error: Error?) {
        if let event = event {
            do {
                try raise(event)
            } catch {
                try? raise(.failed(error))
            }
        } else if let error = error {
            try? raise(.failed(error))
        }
    }

}


/// Validation observers
extension LicenseValidation {
    
    typealias Observer = (ValidatedDocuments?, Error?) -> Void
    
    enum ObserverPolicy {
        // The observer is automatically removed when called.
        case once
        // The observer is called everytime the validation is finished.
        case always
    }
    
    func observe(_ policy: ObserverPolicy = .always, _ observer: @escaping Observer) {
        self.observers.append((observer, policy))
    }
    
    private func notifyObservers(documents: ValidatedDocuments?, error: Error?) {
        for observer in observers {
            observer.callback(documents, error)
        }
        observers = observers.filter { $0.policy != .once }
    }
    
}
