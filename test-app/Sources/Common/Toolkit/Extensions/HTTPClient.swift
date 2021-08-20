//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import R2Shared

struct HTTPDownload {
    let file: URL
    let response: HTTPResponse
}

extension HTTPClient {
    
    func fetch(_ request: HTTPRequestConvertible) -> AnyPublisher<HTTPResponse, HTTPError> {
        var cancellable: R2Shared.Cancellable? = nil
        return Future { promise in
            cancellable = self.fetch(request, completion: promise)
        }
        .handleEvents(receiveCancel: { cancellable?.cancel() })
        .eraseToAnyPublisher()
    }
    
    func download(_ request: HTTPRequestConvertible, progress: @escaping (Double) -> Void) -> AnyPublisher<HTTPDownload, HTTPError> {
        openTemporaryFileForWriting()
            .flatMap { (destination, handle) -> AnyPublisher<HTTPDownload, HTTPError> in
                var cancellable: R2Shared.Cancellable? = nil
                
                return Future { promise in
                    cancellable = self.stream(request,
                        consume: { data, progression in
                            if let progression = progression {
                                progress(progression)
                            }
                            handle.write(data)
                        },
                        completion: { result in
                            do {
                                try handle.close()
                                promise(.success(HTTPDownload(file: destination, response: try result.get())))
                            } catch {
                                try? FileManager.default.removeItem(at: destination)
                                promise(.failure(HTTPError(error: error)))
                            }
                        })
                }
                .handleEvents(receiveCancel: {
                    cancellable?.cancel()
                    try? handle.close()
                    try? FileManager.default.removeItem(at: destination)
                })
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    private func openTemporaryFileForWriting() -> AnyPublisher<(URL, FileHandle), HTTPError> {
        Paths.makeTemporaryURL()
            .tryMap { destination in
                // Makes sure the file exists.
                try "".write(to: destination, atomically: true, encoding: .utf8)
                let handle = try FileHandle(forWritingTo: destination)
                return (destination, handle)
            }
            .mapError { HTTPError(kind: .other, cause: $0) }
            .eraseToAnyPublisher()
    }
}
