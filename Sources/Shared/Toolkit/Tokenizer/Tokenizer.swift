//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A tokenizer splits a content into a list of tokens.
public typealias Tokenizer<Data, Token> = (_ data: Data) throws -> [Token]
