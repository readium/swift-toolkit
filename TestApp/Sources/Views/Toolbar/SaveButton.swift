//
//  SaveButton.swift
//  TestApp
//
//  Created by Steven Zeck on 6/7/22.
//

import SwiftUI

struct SaveButton: View {
    var action: () -> Void = {}
    var body: some View {
        Button("Save", action: action)
    }
}

struct SaveButton_Previews: PreviewProvider {
    static var previews: some View {
        SaveButton()
    }
}
