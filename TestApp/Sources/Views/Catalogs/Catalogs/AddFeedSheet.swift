//
//  AddFeedSheet.swift
//  TestApp
//
//  Created by Steven Zeck on 6/2/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import SwiftUI

struct AddFeedSheet: View {
    
    // For iOS 15, we can use @Environment(\.dismiss)
    @Binding var showingSheet: Bool
    var action: (String, String) -> Void
    
    @State var title: String = ""
    @State var url: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Feed Title", text: $title)
                TextField("URL", text: $url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                // FIXME better looking buttons here, or move to toolbar within sheet
                Button("Add") {
                    action(title, url)
                }
                Button("Cancel") {
                    showingSheet = false
                }
            }
            .navigationBarTitle("Add an OPDS Feed")
        }
    }
}

//struct AddFeedSheet_Previews: PreviewProvider {
//    static var previews: some View {
//        AddFeedSheet()
//    }
//}
