//
//  DownloadSession.swift
//  r2-shared-swift
//
//  Created by Senda Li on 2018/7/4.
//  Copyright © 2018 Readium. All rights reserved.
//

import Foundation

public protocol DownloadDisplayDelegate {
    func didStartDownload(task:URLSessionDownloadTask);
    func didFinishDownload(task:URLSessionDownloadTask);
    func didFailWithError(task:URLSessionDownloadTask, error: Error);
    func didUpdateDownloadPercentage(task:URLSessionDownloadTask, percentage: Float);
}

public typealias completionHandlerType = ((URL?, URLResponse?, Error?) -> Void)

public class DownloadSession: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
    
    public static let shared = DownloadSession()
    private override init() { super.init() }
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    } ()
    
    public var displayDelegate:DownloadDisplayDelegate?
    private var taskMap = [URLSessionTask:completionHandlerType]()
    
    public func launch(request: URLRequest, completionHandler:completionHandlerType?) {
        let task = self.session.downloadTask(with: request); task.resume()
        self.taskMap[task] = completionHandler
        
        DispatchQueue.main.async {
            self.displayDelegate?.didStartDownload(task: task)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        self.taskMap[downloadTask]?(location, nil, nil)
        self.taskMap.removeValue(forKey: downloadTask)
        
        DispatchQueue.main.async {
            self.displayDelegate?.didFinishDownload(task: downloadTask)
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
        self.taskMap[task]?(nil, nil, error)
        self.taskMap.removeValue(forKey: task)
        guard let theError = error else {return}
        
        DispatchQueue.main.async {
            self.displayDelegate?.didFailWithError(task: task as! URLSessionDownloadTask, error: theError)
        }
    }
}
