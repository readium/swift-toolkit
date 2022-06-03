//
//  AddBookSheet.swift
//  TestApp
//
//  Created by Steven Zeck on 6/2/22.
//

import SwiftUI

struct AddBookSheet: View {
    
    // For iOS 15, we can use @Environment(\.dismiss)
    @Binding var showingSheet: Bool
    var action: (String) -> Void
    
    @State var url: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("URL", text: $url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                // FIXME better looking buttons here
                Button("Add") {
                    action(url)
                }
                Button("Cancel") {
                    showingSheet = false
                }
            }
            .navigationBarTitle("Add a Book")
        }
    }
}

//struct AddBookSheet_Previews: PreviewProvider {
//    static var previews: some View {
//        AddBookSheet(showingSheet: true)
//    }
//}
