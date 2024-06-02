//
//  ChatGPTView.swift
//  TestApp
//
//  Created by Sungbin Kim on 6/2/24.
//

import SwiftUI

struct ChatGPTView: View {
    var content: String
    
    var body: some View {
        Text(content).padding()
    }
}

#Preview {
    ChatGPTView(content: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")
}
