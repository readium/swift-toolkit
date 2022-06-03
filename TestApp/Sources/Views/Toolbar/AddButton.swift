//
//  AddButton.swift
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

struct AddButton: View {
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            Label("Add", systemImage: "plus")
        }
    }
}

struct AddButton_Previews: PreviewProvider {
    static var previews: some View {
        AddButton()
    }
}