//
//  AppDelegate.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 6/12/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Shared

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var container: AppContainer!
    var coordinator: AppCoordinator!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        
        // Set Readium 2's logging minimum level.
        R2EnableLog(withMinimumSeverityLevel: .debug)

        container = AppContainer.shared
        coordinator = container.make()
        coordinator.start { startViewController in
            window?.rootViewController = startViewController
        }

        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return coordinator.open(url: url)
    }

}
