//
//  Connection+Userversion.swift
//  r2-testapp-swift
//
//  Created by Aferdita Muriqi on 4/7/19.
//  Copyright © 2019 Readium. All rights reserved.
//

import Foundation
import SQLite

extension Connection {
  public var userVersion: Int32 {
    get { return Int32(try! scalar("PRAGMA user_version") as! Int64)}
    set { try! run("PRAGMA user_version = \(newValue)") }
  }
}
