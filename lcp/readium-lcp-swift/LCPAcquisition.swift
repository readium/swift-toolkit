//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Represents an on-going LCP acquisition task.
///
/// Observe the progress and completion of the acquisition using its fluent interface.
///
/// ```
/// acquisition
///     .onProgress { progressDialog.progress = $0 }
///     .onCompletion { importPublication($0.localURL) }
/// ```
///
/// You can cancel the on-going download with `acquisition.cancel()`.
public final class LCPAcquisition: Loggable {

    /// Informations about an acquired publication protected with LCP.
    public struct Publication {
        /// Path to the downloaded publication.
        /// You must move this file to the user library's folder.
        public let localURL: URL

        /// Filename that should be used for the publication when importing it in the user library.
        public let suggestedFilename: String
        
        /// Download task used to fetch the publication.
        @available(*, deprecated, message: "This is for legacy purpose, if you're using R2Shared.DownloadSession")
        public let downloadTask: URLSessionDownloadTask?
        
    }
    
    /// Percent-based progress of the acquisition.
    public enum Progress {
        /// Undetermined progress, a spinner should be shown to the user.
        case indefinite
        /// A finite progress from 0.0 to 1.0, a progress bar should be shown to the user.
        case percent(Float)
    }

    /// Calls the given `closure` when the acquisition progress changes.
    @discardableResult
    public func onProgress(_ closure: @escaping (Progress) -> Void) -> Self {
        progress.observe(closure)
        return self
    }
    
    /// Calls the given `closure` when the acquisition finishes.
    ///
    /// The file at `Publication.localURL` needs to be moved before the completion closures return,
    /// otherwise it will be removed from the file system.
    @discardableResult
    public func onCompletion(_ closure: @escaping (CancellableResult<Publication, LCPError>) -> Void) -> Self {
        if let result = result {
            DispatchQueue.global().async {
                closure(result)
            }
            return self
        } else {
            completionClosure.append(closure)
            return self
        }
    }
    
    /// Cancels the acquisition.
    public func cancel() {
        guard !isCancelled else {
            return
        }
        isCancelled = true
        downloadTask?.cancel()
        didComplete(with: .cancelled)
    }
    
    let progress = MutableObservable<Progress>(.indefinite)

    private(set) var isCancelled = false
    private var result: CancellableResult<Publication, LCPError>?
    private var completionClosure: [(CancellableResult<Publication, LCPError>) -> Void] = []
    
    var downloadTask: URLSessionDownloadTask?
    
    init() {}
    
    func didComplete(with result: CancellableResult<Publication, LCPError>) -> Void {
        guard self.result == nil else {
            return
        }
        self.result = result
        
        for closure in completionClosure {
            closure(result)
        }
        
        if case .success(let publication) = result, (try? publication.localURL.checkResourceIsReachable()) == true {
            log(.warning, "The acquired LCP publication file was not moved in the completion closure. It will be removed from the file system.")
        }
    }

}
