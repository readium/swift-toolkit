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
import R2Shared


/// To modify depending of the profiles supported by liblcp.a.
private let supportedProfiles = [
    "http://readium.org/lcp/basic-profile",
    "http://readium.org/lcp/profile-1.0",
]


typealias Context = Either<LCPClientContext, StatusError>


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

    func getContext() throws -> LCPClientContext {
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
    fileprivate let isProduction: Bool
    fileprivate let client: LCPClient
    fileprivate let authentication: LCPAuthenticating?
    fileprivate let allowUserInteraction: Bool
    fileprivate let sender: Any?
    fileprivate let crl: CRLService
    fileprivate let device: DeviceService
    fileprivate let httpClient: HTTPClient
    fileprivate let passphrases: PassphrasesService

    // List of observers notified when the Documents are validated, or if an error occurred.
    fileprivate var observers: [(callback: Observer, policy: ObserverPolicy)] = []
    
    fileprivate let onLicenseValidated: (LicenseDocument) throws -> Void

    // Current state in the validation steps.
    private(set) var state: State = .start {
        didSet {
            log(.debug, "* \(state)")
            handle(state)
        }
    }

    init(
        authentication: LCPAuthenticating?,
        allowUserInteraction: Bool,
        sender: Any?,
        isProduction: Bool,
        client: LCPClient,
        crl: CRLService,
        device: DeviceService,
        httpClient: HTTPClient,
        passphrases: PassphrasesService,
        onLicenseValidated: @escaping (LicenseDocument) throws -> Void
    ) {
        self.authentication = authentication
        self.allowUserInteraction = allowUserInteraction
        self.sender = sender
        self.isProduction = isProduction
        self.client = client
        self.crl = crl
        self.device = device
        self.httpClient = httpClient
        self.passphrases = passphrases
        self.onLicenseValidated = onLicenseValidated
    }

    // Raw Document's data to validate.
    enum Document {
        case license(Data)
        case status(Data)
    }
    
    /// Validates the given License or Status Document.
    /// If a validation is already running, `LCPError.licenseIsBusy` will be reported.
    func validate(_ document: Document) -> Deferred<ValidatedDocuments, Error> {
        let event: Event
        switch document {
        case .license(let data):
            event = .retrievedLicenseData(data)
        case .status(let data):
            event = .retrievedStatusData(data)
        }
        
        return observe(raising: event)
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
        case fetchStatus(LicenseDocument)
        case validateStatus(LicenseDocument, Data)
        case fetchLicense(LicenseDocument, StatusDocument)
        case checkLicenseStatus(LicenseDocument, StatusDocument?, statusDocumentTakesPrecedence: Bool)
        case requestPassphrase(LicenseDocument, StatusDocument?)
        case validateIntegrity(LicenseDocument, StatusDocument?, passphrase: String)
        case registerDevice(ValidatedDocuments, Link)

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

            // 1. Validate the license structure
            case let (.validateLicense(_, status), .validatedLicense(license)):
                // Skips the status fetch if we already have one, to avoid any infinite loop
                if let status = status {
                    self = .checkLicenseStatus(license, status, statusDocumentTakesPrecedence: false)
                } else {
                    self = .fetchStatus(license)
                }
            case let (.validateLicense(_, _), .failed(error)):
                self = .failure(error)

            // 2. Fetch the status document
            case let (.fetchStatus(license), .retrievedStatusData(data)):
                self = .validateStatus(license, data)
            case let (.fetchStatus(license), .failed(_)):
                // We ignore any error while fetching the Status Document, as it is optional
                self = .checkLicenseStatus(license, nil, statusDocumentTakesPrecedence: false)

            // 2.2. Validate the structure of the status document
            case let (.validateStatus(license, _), .validatedStatus(status)):
                // Fetches the License Document if it was updated
                if license.updated < status.licenseUpdated {
                    self = .fetchLicense(license, status)
                } else {
                    self = .checkLicenseStatus(license, status, statusDocumentTakesPrecedence: false)
                }
            case let (.validateStatus(license, _), .failed(_)):
                // We ignore any error while validating the Status Document, as it is optional
                self = .checkLicenseStatus(license, nil, statusDocumentTakesPrecedence: false)

            // 3. Get an updated license if needed
            case let (.fetchLicense(_, status), .retrievedLicenseData(data)):
                self = .validateLicense(data, status)
            case let (.fetchLicense(license, status), .failed(_)):
                // We ignore any error while fetching the updated License Document
                // Note: since we failed to get the updated License, then the Status Document will take precedence over the License when checking the status.
                self = .checkLicenseStatus(license, status, statusDocumentTakesPrecedence: true)

            // 4. Check the dates and license status
            case let (.checkLicenseStatus(license, status, _), .checkedLicenseStatus(error)):
                if let error = error {
                    self = .valid(ValidatedDocuments(license, .right(error), status))
                } else {
                    self = .requestPassphrase(license, status)
                }

            // 5. Get the passphrase associated with the license
            case let (.requestPassphrase(license, status), .retrievedPassphrase(passphrase)):
                self = .validateIntegrity(license, status, passphrase: passphrase)
            case (.requestPassphrase, .failed(let error)):
                self = .failure(error)
            case (.requestPassphrase, .cancelled):
                self = .start

            // 6. Validate the license integrity
            case let (.validateIntegrity(license, status, _), .validatedIntegrity(context)):
                let documents = ValidatedDocuments(license, .left(context), status)
                if let link = status?.link(for: .register) {
                    self = .registerDevice(documents, link)
                } else {
                    self = .valid(documents)
                }
            case let (.validateIntegrity(_, _, _), .failed(error)):
                self = .failure(error)

            // 7/ Register the device / license
            case let (.registerDevice(documents, _), .registeredDevice(statusData)):
                if let statusData = statusData {
                    self = .validateStatus(documents.license, statusData)
                } else {
                    self = .valid(documents)
                }
            case let (.registerDevice(documents, _), .failed(_)):
                // We ignore any error while registrating the device
                self = .valid(documents)

            // Re-validates a new Status Document (for example, after calling an LSD interaction
            case let (.valid(documents), .retrievedStatusData(data)):
                self = .validateStatus(documents.license, data)

            case let (.failure(error), _):
                throw error
                
            default:
                log(.warning, "\(type(of: self)): Unexpected event \(event) for state \(self)")
                throw LCPError.licenseIsBusy
            }
        }
    }
    
    fileprivate enum Event {
        // Raised when reading the License from its container, or when updating it from an LCP server.
        case retrievedLicenseData(Data)
        // Raised when the License Document is parsed and its structure is validated.
        case validatedLicense(LicenseDocument)
        // Raised after fetching the Status Document, or receiving it as a response of an LSD interaction.
        case retrievedStatusData(Data)
        // Raised after parsing and validating a Status Document's data.
        case validatedStatus(StatusDocument)
        // Raised after the License's status was checked, with any occurred status error.
        case checkedLicenseStatus(StatusError?)
        // Raised when we retrieved the passphrase from the local database, or from prompting the user.
        case retrievedPassphrase(String)
        // Raised after validating the integrity of the License using liblcp.a.
        case validatedIntegrity(LCPClientContext)
        // Raised when the device is registered, with an optional updated Status Document.
        case registeredDevice(Data?)
        // Raised when any error occurs during the validation workflow.
        case failed(Error)
        // Raised when the user cancelled the validation.
        case cancelled
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
        
        // In test mode, only the basic profile is authorized.
        // This is done here instead of during the integrity check because the passphrase can't be validated.
        guard isProduction || license.encryption.profile == "http://readium.org/lcp/basic-profile" else {
            throw LCPError.licenseProfileNotSupported
        }
        
        try onLicenseValidated(license)
        try raise(.validatedLicense(license))
    }
    
    private func fetchStatus(of license: LicenseDocument) throws {
        let url = try license.url(for: .status, preferredType: .lcpStatusDocument)
        // Short timeout to avoid blocking the License, since the LSD is optional.
        httpClient.fetch(HTTPRequest(url: url, headers: ["Accept": MediaType.lcpStatusDocument.string], timeoutInterval: 5))
            .map { .retrievedStatusData($0.body ?? Data()) }
            .eraseToAnyError()
            .resolve(raise)
    }
    
    private func validateStatus(data: Data) throws {
        let status = try StatusDocument(data: data)
        try raise(.validatedStatus(status))
    }
    
    private func fetchLicense(from status: StatusDocument) throws {
        let url = try status.url(for: .license, preferredType: .lcpLicenseDocument)
        // Short timeout to avoid blocking the License, since it can be updated next time.
        httpClient.fetch(HTTPRequest(url: url, timeoutInterval: 5))
            .map { .retrievedLicenseData($0.body ?? Data()) }
            .eraseToAnyError()
            .resolve(raise)
    }
    
    private func checkLicenseStatus(of license: LicenseDocument, status: StatusDocument?, statusDocumentTakesPrecedence: Bool) throws {
        var error: StatusError? = nil
        
        let now = Date()
        let start = license.rights.start ?? now
        let end = license.rights.end ?? now
        let isLicenseExpired = (start > now || now > end)
        
        let isStatusValid = [.ready, .active].contains(status?.status ?? .ready)
        
        // We only check the Status Document's status if the License itself is expired, to get a proper status error message. But in the case where the Status Document takes precedence (eg. after a failed License update), then we also check the status validity.
        if isLicenseExpired || (statusDocumentTakesPrecedence && !isStatusValid) {
            if let status = status {
                let date = status.updated
                switch status.status {
                case .ready, .active, .expired:
                    // If the status is "ready" or "active", the app MUST consider this is a server error and the correct status is "expired"
                    error = .expired(start: start, end: end)
                case .returned:
                    error = .returned(date)
                case .revoked:
                    let devicesCount = status.events(for: .register).count
                    error = .revoked(date, devicesCount: devicesCount)
                case .cancelled:
                    error = .cancelled(date)
                }
            } else {
                // No Status Document? Fallback on a generic "expired" error.
                error = .expired(start: start, end: end)
            }
        }
        
        try raise(.checkedLicenseStatus(error))
    }
    
    private func requestPassphrase(for license: LicenseDocument) {
        passphrases.request(for: license, authentication: authentication, allowUserInteraction: allowUserInteraction, sender: sender)
            .map { .retrievedPassphrase($0) }
            .resolve(raise)
    }
    
    private func validateIntegrity(of license: LicenseDocument, with passphrase: String) throws {
        // 1. Checks the profile
        let profile = license.encryption.profile
        guard supportedProfiles.contains(profile) else {
            throw LCPError.licenseProfileNotSupported
        }
        
        // 2. Creates the DRM context
        crl.retrieve()
            .tryMap { crl -> Event in
                let context = try self.client.createContext(jsonLicense: license.json, hashedPassphrase: passphrase, pemCrl: crl)
                return .validatedIntegrity(context)
            }
            .resolve(raise)
    }

    private func registerDevice(for license: LicenseDocument, at link: Link) {
        device.registerLicense(license, at: link)
            .map { data in .registeredDevice(data) }
            .resolve(raise)
    }

    fileprivate func handle(_ state: State) {
        // Boring glue to call the handlers when a state occurs
        do {
            switch state {
            case .start:
                // We are back to start? It means the validation was cancelled by the user.
                notifyObservers(.cancelled)
            case let .validateLicense(data, _):
                try validateLicense(data: data)
            case let .fetchStatus(license):
                try fetchStatus(of: license)
            case let .validateStatus(_, data):
                try validateStatus(data: data)
            case let .fetchLicense(_, status):
                try fetchLicense(from: status)
            case let .checkLicenseStatus(license, status, statusDocumentTakesPrecedence):
                try checkLicenseStatus(of: license, status: status, statusDocumentTakesPrecedence: statusDocumentTakesPrecedence)
            case let .requestPassphrase(license, _):
                requestPassphrase(for: license)
            case let .validateIntegrity(license, _, passphrase):
                try validateIntegrity(of: license, with: passphrase)
            case let .registerDevice(documents, link):
                registerDevice(for: documents.license, at: link)
            case let .valid(documents):
                notifyObservers(.success(documents))
            case let .failure(error):
                notifyObservers(.failure(error))
            }
        } catch {
            try? raise(.failed(error))
        }
    }
    
    /// Syntactic sugar to raise either the given event, or an error wrapped as an Event.failed.
    /// Can be used to resolve a Deferred<Event, Error>.
    fileprivate func raise(_ result: CancellableResult<Event, Error>) {
        switch result {
        case .success(let event):
            do {
                try raise(event)
            } catch {
                try? raise(.failed(error))
            }
        case .failure(let error):
            try? raise(.failed(error))
        case .cancelled:
            try? raise(Event.cancelled)
        }
    }

}


/// Validation observers
extension LicenseValidation {
    
    typealias Observer = (CancellableResult<ValidatedDocuments, Error>) -> Void
    
    enum ObserverPolicy {
        // The observer is automatically removed when called.
        case once
        // The observer is called everytime the validation is finished.
        case always
    }
    
    /// Observes the validation occured after raising the given event.
    fileprivate func observe(raising event: Event) -> Deferred<ValidatedDocuments, Error> {
        return deferredCatching(on: .main) { completion in
            try self.raise(event)
            self.observe(.once, completion)
        }
    }
    
    func observe(_ policy: ObserverPolicy = .always, _ observer: @escaping Observer) {
        // If the state is already valid or a failure, we notify it to the observer right away.
        var notified = true
        switch (state) {
        case .valid(let documents):
            observer(.success(documents))
        case .failure(let error):
            observer(.failure(error))
        default:
            notified = false
        }
        
        guard !notified || policy == .always else {
            return
        }
        self.observers.append((observer, policy))
    }
    
    private func notifyObservers(_ result: CancellableResult<ValidatedDocuments, Error>) {
        for observer in observers {
            observer.callback(result)
        }
        observers = observers.filter { $0.policy != .once }
    }
    
}
