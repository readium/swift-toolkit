//
//  DownloadSession.swift
//  r2-shared-swift
//
//  Created by Senda Li on 2018/7/4.
//  Copyright © 2018 Readium. All rights reserved.
//

import Foundation

public protocol DownloadDisplayDelegate {
    func didStartDownload(task:URLSessionDownloadTask, description:String);
    func didFinishDownload(task:URLSessionDownloadTask);
    func didFailWithError(task:URLSessionDownloadTask, error: Error?);
    func didUpdateDownloadPercentage(task:URLSessionDownloadTask, percentage: Float);
}


/// Represents the percent-based progress of the download.
public enum DownloadProgress {
    /// Undetermined progress, a spinner should be shown to the user.
    case infinite
    /// A finite progress from 0.0 to 1.0, a progress bar should be shown to the user.
    case finite(Float)
}


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
    private override init() { super.init() }
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "org.readium.r2-shared.DownloadSession")
        return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    } ()
    
    public var displayDelegate:DownloadDisplayDelegate?
    private var taskMap = [URLSessionTask: Download]()
    
    /// Returns: an observable download progress value, from 0.0 to 1.0
    @discardableResult
    public func launch(request: URLRequest, description: String?, completionHandler: CompletionHandler?) -> Observable<DownloadProgress> {
        let task = self.session.downloadTask(with: request); task.resume()
        let download = Download(completion: completionHandler ?? { _, _, _, _ in return true })
        self.taskMap[task] = download

        DispatchQueue.main.async {
            let localizedDescription = description ?? "..."
            self.displayDelegate?.didStartDownload(task: task, description: localizedDescription)
        }
        
        return download.progress
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
            guard let downloadTask = task as? URLSessionDownloadTask else {return}
            
            guard let theError = error else {return}
            _ = self.taskMap[task]?.completion(nil, nil, error, downloadTask)
            self.taskMap.removeValue(forKey: task)
            
            self.displayDelegate?.didFailWithError(task: downloadTask, error: theError)
        }
    }
}
