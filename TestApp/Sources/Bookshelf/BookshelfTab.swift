//
//  BookshelfTab.swift
//  TestApp
//
//  Created by Steven Zeck on 5/15/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import SwiftUI

struct BookshelfTab: View {
    
    var body: some View {
        
        var columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(books, id: \.self) { item in
                    BookCover(item)
                }
            }
        }
    }
}
