//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import R2Shared
import R2Navigator
import SwiftUI

struct NewReaderView: View, Hashable, Equatable {
    let bookId: Book.Id
    
    static func == (lhs: NewReaderView, rhs: NewReaderView) -> Bool {
        return lhs.bookId == rhs.bookId
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(bookId)
    }
    
    @ObservedObject var viewModel: NewReaderViewModel
    
    var body: some View {
        VStack {
            GeometryReader { reader in
                // "actual" reader view
                NewReaderViewController(
                    makeReaderVCFunc: viewModel.makeReaderVCFunc
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .border(.red, width: 2) // debug info
            
            positionLabel()
        }
        .toolbar {
            // TODO: to add Dark Mode support for the Toolbar, such API can be used: https://stackoverflow.com/questions/56709463/change-the-stroke-fill-color-of-sf-symbol-icon-in-swiftui
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Table of Contents
                Button {
                    
                } label: {
                    Image(uiImage: #imageLiteral(resourceName: "menuIcon"))
                }
                // DRM management
                if viewModel.publication.isProtected {
                    Button {
                        // drm
                    } label: {
                        Image(uiImage: #imageLiteral(resourceName: "drm"))
                    }
                }
                // Bookmarks
                Button {
                    
                } label: {
                    Image(uiImage: #imageLiteral(resourceName: "bookmark"))
                }
                // Search
                if viewModel.publication._isSearchable {
                    Button {
                        
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                // User Settings (for EBUB only)
                Button {
                    
                } label: {
                    Image(uiImage: #imageLiteral(resourceName: "settingsIcon"))
                }
            }
        }
    }
    
    @ViewBuilder
    private func positionLabel() -> some View {
        Text(viewModel.positionLabelText)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }
}

struct NewReaderViewController: UIViewControllerRepresentable {
    let makeReaderVCFunc: () -> UIViewController
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        return makeReaderVCFunc()
    }
}

extension Publication: Equatable {
    public static func == (lhs: Publication, rhs: Publication) -> Bool {
        return lhs.id == rhs.id
    }
}
