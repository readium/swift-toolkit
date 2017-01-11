//
//  AppDelegate.swift
//  R2Streamer
//
//  Created by Olivier Körner on 14/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var epubServer: RDEpubServer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        epubServer = RDEpubServer()
        
        let epubPaths = fetchContainerPaths()
        var publications = [RDPublication]()
        
        for path in epubPaths {
            let fullPath = Bundle.main.path(forResource: "Samples/\(path)", ofType: nil)
            var isDirectory: ObjCBool = false
            
            if FileManager.default.fileExists(atPath: fullPath!, isDirectory: &isDirectory) {
                
                var container: RDContainer?
                if isDirectory.boolValue {
                    container = RDDirectoryContainer(directory: fullPath!)
                } else {
                    container = RDEpubContainer(path: fullPath!)
                }
                
                let parser = RDEpubParser(container: container!)
                do {
                    let pub = try parser.parse()
                    if let pubURL = epubServer!.baseURL?.appendingPathComponent("\(path)/manifest.json", isDirectory: false) {
                        pub!.links.append(RDLink(href: pubURL.absoluteString, typeLink: "application/webpub+json", rel: "self"))
                    }
                    publications.append(pub!)
                    let json = pub?.toJSONString(prettyPrint: true)
                    NSLog(json!)
                    epubServer!.addEpub(container: container!, withEndpoint: path)
                    NSLog("Adding endpoint \(path) for publication \(pub!.metadata.title)")
                } catch {
                    NSLog("Error parsing publication at path '\(path)': \(error)")
                }
            }
        }
        
        let navigationViewController = window?.rootViewController as! UINavigationController
        let libraryViewController = LibraryViewController(publications: publications)
        navigationViewController.viewControllers = [libraryViewController]
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    /// Get the list of EPUBs in the app bundle
    func fetchContainerPaths() -> [String] {
        if let samplesPath = Bundle.main.path(forResource: "Samples", ofType: nil) {
            let containerPaths = try! FileManager.default.contentsOfDirectory(atPath: samplesPath)
            return containerPaths
        }
        return [String]()
    }

}

