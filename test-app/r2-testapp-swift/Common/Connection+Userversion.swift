//
//  Connection+Userversion.swift
//  r2-testapp-swift
//
//  Created by Aferdita Muriqi on 4/7/19.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SQLite

extension Connection {
  public var userVersion: Int32 {
    get { return Int32(try! scalar("PRAGMA user_version") as! Int64)}
    set { try! run("PRAGMA user_version = \(newValue)") }
  }
}
