//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

@available(*, deprecated, message: "This API will be removed in the future, please use your own download solution in your app")
public protocol DownloadDisplayDelegate {
    func didStartDownload(task: URLSessionDownloadTask, description: String)
    func didFinishDownload(task: URLSessionDownloadTask)
    func didFailWithError(task: URLSessionDownloadTask, error: Error?)
    func didUpdateDownloadPercentage(task: URLSessionDownloadTask, percentage: Float)
}

/// Represents the percent-based progress of the download.
@available(*, deprecated, message: "This API will be removed in the future, please use your own download solution in your app")
public enum DownloadProgress {
    /// Undetermined progress, a spinner should be shown to the user.
    case infinite
    /// A finite progress from 0.0 to 1.0, a progress bar should be shown to the user.
    case finite(Float)
}

@available(*, deprecated, message: "This API will be removed in the future, please use your own download solution in your app")
public class DownloadSession: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
    public typealias CompletionHandler = (URL?, URLResponse?, Error?, URLSessionDownloadTask) -> Bool?

    struct Download {
        let progress = MutableObservable<DownloadProgress>(.infinite)
        let completion: CompletionHandler
    }

    enum RequestError: LocalizedError {
        case notFound

        var errorDescription: String? {
            switch self {
            case .notFound:
                return R2SharedLocalizedString("DownloadSession.RequestError.notFound")
            }
        }
    }

    public static let shared = DownloadSession()
    override private init() { super.init() }

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "org.readium.r2-shared.DownloadSession")
        return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    }()

    public var displayDelegate: DownloadDisplayDelegate?
    private var taskMap = [URLSessionTask: Download]()

    /// Returns: an observable download progress value, from 0.0 to 1.0
    @discardableResult
    public func launch(request: URLRequest, description: String?, completionHandler: CompletionHandler?) -> Observable<DownloadProgress> {
        launchTask(request: request, description: description, completionHandler: completionHandler).progress
    }

    @discardableResult
    public func launchTask(request: URLRequest, description: String?, completionHandler: CompletionHandler?) -> (task: URLSessionDownloadTask, progress: Observable<DownloadProgress>) {
        let task = session.downloadTask(with: request)
        task.resume()
        let download = Download(completion: completionHandler ?? { _, _, _, _ in true })
        taskMap[task] = download

        DispatchQueue.main.async {
            let localizedDescription = description ?? "..."
            self.displayDelegate?.didStartDownload(task: task, description: localizedDescription)
        }

        return (task, download.progress)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let done: Bool?
        let download = taskMap[downloadTask]

        do {
            guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200 else {
                throw RequestError.notFound
            }

            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(location.pathExtension)

            try FileManager.default.moveItem(at: location, to: tempURL)
            done = download?.completion(tempURL, response, nil, downloadTask)
        } catch {
            done = download?.completion(nil, nil, error, downloadTask)
        }

        DispatchQueue.main.async {
            self.taskMap.removeValue(forKey: downloadTask)

            if done ?? false {
                self.displayDelegate?.didFinishDownload(task: downloadTask)
            } else {
                self.displayDelegate?.didFailWithError(task: downloadTask, error: nil)
            }
        }
    }

    private func didUpdateProgress(_ progress: Float, of task: URLSessionDownloadTask) {
        DispatchQueue.main.async {
            self.taskMap[task]?.progress.value = .finite(progress)
            self.displayDelegate?.didUpdateDownloadPercentage(task: task, percentage: progress)
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        didUpdateProgress(progress, of: downloadTask)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        let progress = Float(fileOffset) / Float(expectedTotalBytes)
        didUpdateProgress(progress, of: downloadTask)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            guard let downloadTask = task as? URLSessionDownloadTask else { return }

            guard let theError = error else { return }
            _ = self.taskMap[task]?.completion(nil, nil, error, downloadTask)
            self.taskMap.removeValue(forKey: task)

            self.displayDelegate?.didFailWithError(task: downloadTask, error: theError)
        }
    }
}
