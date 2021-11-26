//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftUI
import Combine
import R2Shared
import R2Navigator

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    
    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        init(text: Binding<String>) {
            _text = text
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }
    }
    
    func makeCoordinator() -> SearchBar.Coordinator {
        return Coordinator(text: $text)
    }
    
    func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.placeholder = "Search"
        searchBar.delegate = context.coordinator
        searchBar.searchBarStyle = .minimal
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: UIViewRepresentableContext<SearchBar>) {
        uiView.text = text
    }
}

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @State var query: String = ""
    var body: some View {
        let queryValueBinding = Binding<String>(get: {
            self.query
        }, set: {
            self.query = $0
            viewModel.search(with: query)
        })
        
        return VStack {
            SearchBar(text: queryValueBinding)
            List(viewModel.results.indices, id: \.self) { index in
                let locator = viewModel.results[index]
                (
                    Text(locator.previewTextBefore) +
                    Text(locator.previewTextHighlight).foregroundColor(Color.orange) +
                    Text(locator.previewTextAfter)
                )
                .onAppear(perform: {
                    if index == viewModel.results.count-1 {
                        viewModel.loadNextPage()
                    }
                })
                .onTapGesture {
                    viewModel.selectedLocator = locator
                }
            }
        }
    }
}

extension Locator {
    /// Sometimes when there's an image before the text, "text.before" looks like "\n\t\t\n\t\n\n\t\n\n\t Some Seach word"
    /// This function tries to remove leading tabs and newlines for a more compact preview
    var previewTextBefore: String {
        let textBefore = text.before ?? ""
        return String(textBefore.drop { char in char == "\n" || char == "\t" })
    }
    
    var previewTextHighlight: String {
        return text.highlight ?? ""
    }
    
    var previewTextAfter: String {
        return String(text.after ?? "")
    }
}

