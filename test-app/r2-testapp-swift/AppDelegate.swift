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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    private var app: AppModule!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        app = try! AppModule()
        
        // Library
        let libraryViewController = app.library.rootViewController
        libraryViewController.tabBarItem = UITabBarItem(title: "Bookshelf", image: UIImage(named: "bookshelf"), tag: 0)
        
        // OPDS Feeds
        let opdsViewController = app.opds.rootViewController
        opdsViewController.tabBarItem = UITabBarItem(title: "OPDS Feeds", image: UIImage(named: "catalogs"), tag: 0)
        
        // About
        let aboutViewController = app.aboutViewController
        aboutViewController.tabBarItem = UITabBarItem(title: "About", image: UIImage(named: "about"), tag: 0)
        
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [
            libraryViewController,
            opdsViewController,
            aboutViewController
        ]
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        return true
    }
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return app.library.addPublication(at: url, from: nil)
    }

}
