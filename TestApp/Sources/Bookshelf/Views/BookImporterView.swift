//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//
// https://gist.github.com/MentalN/d4d2647aedd761831eeaf1450c299887
//

import Foundation
import SwiftUI
import UIKit
import R2Shared

enum BookImporterViewError: Error {
    case noSelectedFile
}

struct BookImporterView: UIViewControllerRepresentable {
    
    @Binding var choosenURL: URL?
    var completion: (Result<URL, Error>) -> Void
    
    func makeCoordinator() -> BookImporterView.Coordinator {
        return BookImporterView.Coordinator(parent: self, completion: completion)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<BookImporterView>) -> UIDocumentPickerViewController {
        
        var types = DocumentTypes.main.supportedUTTypes
        types.append(.text)
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: BookImporterView.UIViewControllerType, context: UIViewControllerRepresentableContext<BookImporterView>) {
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var completion: (Result<URL, Error>) -> Void
        var parent: BookImporterView
        
        init(parent: BookImporterView, completion: @escaping (Result<URL, Error>) -> Void){
            self.parent = parent
            self.completion = completion
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.choosenURL = url
                completion(.success(url))
            } else {
                completion(.failure(BookImporterViewError.noSelectedFile))
            }
        }
    }
}
