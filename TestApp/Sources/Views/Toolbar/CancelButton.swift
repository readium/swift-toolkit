//
//  CancelButton.swift
//  TestApp
//
//  Created by Steven Zeck on 6/7/22.
//

import SwiftUI

struct CancelButton: View {
    var action: () -> Void = {}
    var body: some View {
        Button("Cancel", action: action)
    }
}

struct CancelButton_Previews: PreviewProvider {
    static var previews: some View {
        CancelButton()
    }
}
