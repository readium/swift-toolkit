//
//  AboutTab.swift
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

struct AboutTab: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Version")
                    .font(.title2)
                HStack(spacing: 10) {
                    Text("Version").frame(width: 170.0, alignment: .leading)
                    Text("2.3.0")
                }
                HStack(spacing: 10) {
                    Text("Build").frame(width: 170.0, alignment: .leading)
                    Text("1")
                }
                Text("Copyright").font(.title2)
                Link("© 2022 European Digital Reading Lab",
                     destination: URL(string: "https://www.edrlab.org/")!)
                Link("[BSD-3 License]",
                     destination: URL(string: "https://opensource.org/licenses/BSD-3-Clause")!)
                Text("Acknowledgements").font(.title2)
                Text("R2 Reader wouldn't have been developed without the financial help of the French State.")
                Image("rf")
            }
            .navigationTitle("About")
        }
    }
}

struct AboutTab_Previews: PreviewProvider {
    static var previews: some View {
        AboutTab()
    }
}
