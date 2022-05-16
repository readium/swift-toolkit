//
//  AboutTab.swift
//  TestApp
//
//  Created by Steven Zeck on 5/15/22.
//

import SwiftUI

struct AboutTab: View {
    var body: some View {
        VStack {
            HStack {
                Text("Version")
                Text("2.3.0")
            }
            HStack {
                Text("Build")
                Text("1")
            }
            Text("© 2022 European Digital Reading Lab")
            Text("[BSD-3 License]")
            Text("R2 Reader wouldn't have been developed without the financial help of the French State.")
            Image("rf")
        }
    }
}

struct AboutTab_Previews: PreviewProvider {
    static var previews: some View {
        AboutTab()
    }
}
