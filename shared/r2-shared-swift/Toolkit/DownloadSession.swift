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

public typealias completionHandlerType = ((URL?, URLResponse?, Error?, URLSessionDownloadTask) -> Bool?)

public class DownloadSession: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
    
    enum RequestError: LocalizedError {
        case notFound
        
        var errorDescription: String? {
            switch self {
            case .notFound:
                return "Request failed: not found"
            }
        }
    }
    
    public static let shared = DownloadSession()
    private override init() { super.init() }
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    } ()
    
    public var displayDelegate:DownloadDisplayDelegate?
    private var taskMap = [URLSessionTask:completionHandlerType]()
    
    public func launch(request: URLRequest, description:String?, completionHandler:completionHandlerType?) {
        let task = self.session.downloadTask(with: request); task.resume()
        
        DispatchQueue.main.async {
            
            self.taskMap[task] = completionHandler
            let localizedDescription = description ?? "..."
            self.displayDelegate?.didStartDownload(task: task, description: localizedDescription)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let done: Bool?
        
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200 else {
                throw RequestError.notFound
            }
            
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(location.pathExtension)
            
            try FileManager.default.moveItem(at: location, to: tempURL)
            done = taskMap[downloadTask]?(tempURL, nil, nil, downloadTask)
        } catch {
            done = taskMap[downloadTask]?(nil, nil, error, downloadTask)
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
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            self.displayDelegate?.didUpdateDownloadPercentage(task: downloadTask, percentage: progress)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        let progress = Float(fileOffset) / Float(expectedTotalBytes)
        
        DispatchQueue.main.async {
            self.displayDelegate?.didUpdateDownloadPercentage(task: downloadTask, percentage: progress)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        DispatchQueue.main.async {
            
            guard let downloadTask = task as? URLSessionDownloadTask else {return}
            
            guard let theError = error else {return}
            _ = self.taskMap[task]?(nil, nil, error, downloadTask)
            self.taskMap.removeValue(forKey: task)
            
            self.displayDelegate?.didFailWithError(task: downloadTask, error: theError)
        }
    }
}
