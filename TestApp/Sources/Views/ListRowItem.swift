//
//  CatalogFeedRow.swift
//  TestApp
//
//  Created by Steven Zeck on 5/23/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import SwiftUI

struct ListRowItem: View {
    var action: () -> Void = {}
    var title: String
    
    var body: some View {
        Text(title)
            .font(.title3)
        .padding(.vertical, 8)
    }
}

struct CatalogFeedRow_Previews: PreviewProvider {
    static var previews: some View {
        ListRowItem(title: "Test")
    }
}
