//
//  HighlightCell.swift
//  r2-testapp-swift
//
//  Copyright 2021 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import SwiftUI

struct HighlightCellView: View {
    let highlight: Highlight
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color(highlight.color.uiColor))
                .frame(maxWidth: 20, maxHeight: .infinity)
            
            Text(highlight.locator.text.sanitized().highlight ?? "")
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding()
            
            Spacer()
        }
    }
}
