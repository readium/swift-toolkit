//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Represents an on-going LCP acquisition task.
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
        @available(*, unavailable, message: "R2Shared.DownloadSession is deprecated")
        public let downloadTask: URLSessionDownloadTask?
    }
    
    /// Percent-based progress of the acquisition.
    public enum Progress {
        /// Undetermined progress, a spinner should be shown to the user.
        case indefinite
        /// A finite progress from 0.0 to 1.0, a progress bar should be shown to the user.
        case percent(Float)
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
    
    var subscriptions: [Cancellable] = []
    let progress = MutableObservableVariable<Progress>(.indefinite)

    private(set) var isCancelled = false
    private var isCompleted = false
    private let completion: (CancellableResult<Publication, LCPError>) -> Void
    
    var downloadTask: URLSessionDownloadTask?
    
    init(onProgress: @escaping (Progress) -> Void, completion: @escaping (CancellableResult<Publication, LCPError>) -> Void) {
        self.completion = completion
        
        progress.subscribe(observer: onProgress)
            .store(in: &subscriptions)
    }
    
    func didComplete(with result: CancellableResult<Publication, LCPError>) -> Void {
        guard !isCompleted else {
            return
        }
        isCompleted = true
        
        completion(result)
        
        if case .success(let publication) = result, (try? publication.localURL.checkResourceIsReachable()) == true {
            log(.warning, "The acquired LCP publication file was not moved in the completion closure. It will be removed from the file system.")
        }
    }

}
