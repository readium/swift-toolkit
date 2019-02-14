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

// When true, will show the state and transitions in the console.
private let DEBUG = true


// Holds the License/Status Documents and the DRM context, once validated.
struct ValidatedDocuments {
    let license: LicenseDocument
    let context: DRMContext
    private let status: StatusDocument?
    private let statusError: LCPStatusError?

    init(_ license: LicenseDocument, _ context: DRMContext, _ status: StatusDocument? = nil, statusError: LCPStatusError? = nil) {
        self.license = license
        self.context = context
        self.status = status
        self.statusError = statusError
    }
    
    func getStatus() throws -> StatusDocument {
        guard let status = status else {
            throw LCPError.noStatusDocument
        }
        return status
    }
    
    func checkLicenseStatus() throws {
        if let statusError = statusError {
            throw LCPError.status(statusError)
        }
    }

}


/// Validation workflow of the License and Status Documents.
///
/// Use `validate` to start the validation of a Document.
/// Use `observe` to be notified when any validation is done or if an error occurs.
final class LicenseValidation {

    // Dependencies for the State's handlers
    fileprivate let supportedProfiles: [String]
    fileprivate let passphrases: PassphrasesService
    fileprivate let licenses: LicensesRepository
    fileprivate let device: DeviceService
    fileprivate let crl: CRLService
    fileprivate let network: NetworkService
    fileprivate weak var authentication: LCPAuthenticating?

    // Last successfully validated documents used as a fallback when the newly fetched License Document fail to validate.
    // This is used to be tolerant of the Status Document's failures.
    fileprivate var fallbackDocuments: ValidatedDocuments?
    
    // List of observers notified when the Documents are validated, or if an error occurred.
    fileprivate var observers: [(callback: Observer, policy: ObserverPolicy)] = []
    
    // Current state in the validation steps.
    private(set) var state: State = .start {
        didSet {
            if DEBUG { print("#validation * \(state)") }
            handle(state)
        }
    }

    init(supportedProfiles: [String], passphrases: PassphrasesService, licenses: LicensesRepository, device: DeviceService, crl: CRLService, network: NetworkService, authentication: LCPAuthenticating?) {
        self.supportedProfiles = supportedProfiles
        self.passphrases = passphrases
        self.licenses = licenses
        self.device = device
        self.crl = crl
        self.network = network
        self.authentication = authentication
    }

    // Raw Document's data to validate.
    enum Document {
        case license(Data)
        case status(Data)
    }
    
    /// Validates the given License or Status Document.
    /// If a validation is already running, LCPError.busyLicense will be reported.
    func validate(_ document: Document) -> Deferred<ValidatedDocuments> {
        return Deferred { completion in
            let event: Event
            switch (self.state, document) {
            
            // A Status Document can only be validated when the License validation is done.
            case let (.done(documents), .status(data)):
                guard let status = try? StatusDocument(data: data) else {
                    // We ignore malformed Status Document
                    completion(documents, nil)
                    return
                }
                event = .retrievedStatus(status)
                
            // A License Document can only be validated when opening intially the License, or when a Status Document requires a License update.
            case let (.start, .license(data)):
                event = .retrievedLicenseData(data)
                
            case let (.failure(error), _):
                throw error
                
            default:
                throw LCPError.busyLicense
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
        case fetchStatus(LicenseDocument, DRMContext)
        case checkStatus(LicenseDocument, StatusDocument, DRMContext)
        case registerDevice(LicenseDocument, StatusDocument, DRMContext)
        case fetchLicense(StatusDocument)

        // Final states
        case done(ValidatedDocuments)
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
                self = .done(ValidatedDocuments(license, context))

            // 4.3/ Check that the status is "ready" or "active".
            case let (.checkStatus(license, status, context), .checkedStatus(error)):
                if let error = error {
                    self = .done(ValidatedDocuments(license, context, status, statusError: error))
                } else {
                    self = .registerDevice(license, status, context)
                }

            // 5/ Register the device / license
            case let (.registerDevice(license, status, context), .registeredDevice),
                 let (.registerDevice(license, status, context), .failed(_)):  // Failures when registrating the device are ignored
                // Fetches the License Document if it was updated
                if license.updated < status.updated.license {
                    self = .fetchLicense(status)
                } else {
                    self = .done(ValidatedDocuments(license, context, status))
                }
            case let (.registerDevice(license, _, context), .retrievedStatus(status)):
                self = .checkStatus(license, status, context)

            // 6/ Get an updated license if needed
            case let (.fetchLicense(status), .retrievedLicenseData(data)):
                self = .validateLicense(data, status)
            case let (.fetchLicense(_), .failed(error)):
                self = .failure(error)
                
            // Re-validate a new Status Document (for example, after calling an LSD interaction
            case let (.done(documents), .retrievedStatus(status)):
                self = .checkStatus(documents.license, status, documents.context)

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
        // Raised after validating the integrity of the License using liblcp.a
        case validatedIntegrity(DRMContext)
        // Raised after fetching the Status Document, or receiving it as a response of an LSD interaction.
        case retrievedStatus(StatusDocument)
        // Raised after the License's status was checked, with any status error.
        case checkedStatus(LCPStatusError?)
        // Raised when the device got registered.
        case registeredDevice
        // Raised when any error occurs during the validation workflow.
        case failed(Error)
    }
    
    /// Should be called by the state handlers once they're done, to go to the next State.
    fileprivate func raise(_ event: Event) throws {
        if DEBUG { print("#validation -> on \(event)") }
        guard Thread.isMainThread else {
            throw LCPError.runtime("\(type(of: self)): To be safe, events must only be raised from the main thread")
        }
        
        try willRaise(event)
        try state.transition(event)
    }

    fileprivate func willRaise(_ event: Event) throws {
        // FIXME: A few dirty side-effects, it should probably be refactored somewhere else... External event handlers maybe?
        switch (state, event) {
            
        case (.validateIntegrity(let license, _, _), .validatedIntegrity(_)):
            // Saves the license in the local database once we validated its integrity
            try licenses.addOrUpdateLicense(license)

        case let (.checkStatus(license, status, context), .checkedStatus(error)):
            // Updates the license's state in the local database
            try? licenses.updateLicenseStatus(license, to: status)
            // Saves the now-validated License Document as a fallback, in case we update the License later and it fails structure and integrity validation
            fallbackDocuments = ValidatedDocuments(license, context, status, statusError: error)
            
        default:
            break
        }
    }
    
}


/// State's handlers
extension LicenseValidation {

    private func validateLicense(data: Data) throws {
        guard let license = try? LicenseDocument(with: data) else {
            throw LCPError.invalidLCPL
        }

        // 1.a/ Validate the license structure
        // TODO: The app checks that the license is valid (EDRLab provides a JSON schema for LCP licenses in the EDRLab github, lcp-testing-tools). It the license is invalid, the user gets a notification like "This Readium LCP license is invalid, the publication cannot be processed".

        // 1.b/ Check its profile identifier
        let profile = license.encryption.profile.absoluteString
        guard supportedProfiles.contains(profile) else {
            throw LCPError.profileNotSupported
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
            .map { pemCRL -> Event in
                /// Check that current date is inside the [end - start] right's dates range.
                // FIXME: Is this really useful? According to the spec this is already checked by the lcplib.a
                let now = Date.init()
                if let start = license.rights.start,
                    !(now > start) {
                    throw LCPError.invalidRights
                }
                if let end = license.rights.end,
                    !(now < end) {
                    throw LCPError.invalidRights
                }

                let context = try createContext(jsonLicense: license.json, hashedPassphrase: passphrase, pemCrl: pemCRL)
                return .validatedIntegrity(context)
            }
            .resolve(raise)
    }
    
    private func fetchStatus(of license: LicenseDocument) throws {
        let link = try license.link(withRel: .status)
        network.fetch(link.href)
            .map { status, data -> Event in
                guard status == 200 else {
                    throw LCPError.noStatusDocument
                }
                
                let document = try StatusDocument(data: data)
                return .retrievedStatus(document)
            }
            .resolve(raise)
    }
    
    private func checkStatus(_ document: StatusDocument) throws {
        // Checks the status according to 4.3/ in the specification.
        let date = document.updated.status

        let error: LCPStatusError?
        switch document.status {
        case .ready, .active:
            error = nil
        case .returned:
            error = .returned(date)
        case .expired:
            error = .expired(date)
        case .revoked:
            let devicesCount = document.events.filter({ $0.type == "register" }).count
            error = .revoked(date, devicesCount: devicesCount)
        case .cancelled:
            error = .cancelled(date)
        }
        
        try raise(.checkedStatus(error))
    }
    
    private func registerDevice(for license: LicenseDocument, using status: StatusDocument) {
        device.registerLicense(license, using: status)
            .map { statusData -> Event in
                // If no status data is provided, it means the device was already registered.
                guard let statusData = statusData else {
                    return .registeredDevice
                }
                
                let status = try StatusDocument(data: statusData)
                return .retrievedStatus(status)
            }
            .resolve(raise)
    }
    
    private func fetchLicense(from status: StatusDocument) throws {
        let link = try status.link(withRel: .license)
        
        network.fetch(link.href)
            .map { status, data -> Event in
                guard status == 200 else {
                    throw LCPError.licenseFetching
                }
                return .retrievedLicenseData(data)
            }
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
            case let .checkStatus(_, status, _):
                try checkStatus(status)
            case let .registerDevice(license, status, _):
                registerDevice(for: license, using: status)
            case let .fetchLicense(status):
                try fetchLicense(from: status)
            case let .done(documents):
                notifyObservers(documents: documents, error: nil)
            case let .failure(error):
                let error = (fallbackDocuments == nil) ? error : nil
                notifyObservers(documents: fallbackDocuments, error: error)
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
