//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct About: View {
    var body: some View {
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
        .padding()
        .navigationTitle("About")
    }
}

struct About_Previews: PreviewProvider {
    static var previews: some View {
        About()
    }
}
