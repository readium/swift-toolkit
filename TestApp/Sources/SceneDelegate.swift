//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var app: AppModule {
        AppDelegate.app
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        func makeItem(title: String, image: String) -> UITabBarItem {
            UITabBarItem(
                title: NSLocalizedString(title, comment: "Library tab title"),
                image: UIImage(named: image),
                tag: 0
            )
        }

        // Library
        let libraryViewController = app.library.rootViewController
        libraryViewController.tabBarItem = makeItem(title: "bookshelf_tab", image: "bookshelf")

        // OPDS Feeds
        let opdsViewController = app.opds.rootViewController
        opdsViewController.tabBarItem = makeItem(title: "catalogs_tab", image: "catalogs")

        // About
        let aboutViewController = app.aboutViewController
        aboutViewController.tabBarItem = makeItem(title: "about_tab", image: "about")

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [
            libraryViewController,
            opdsViewController,
            aboutViewController,
        ]

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        self.window = window

        // The scene can be launched by opening a publication, in which case
        // the URLs are delivered here instead of `scene(_:openURLContexts:)`.
        importPublications(from: connectionOptions.urlContexts)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        importPublications(from: URLContexts)
    }

    private func importPublications(from contexts: Set<UIOpenURLContext>) {
        for context in contexts {
            guard let url = context.url.anyURL.absoluteURL else {
                continue
            }

            Task {
                do {
                    try await app.library.importPublication(from: url, progress: { _ in })
                } catch {
                    guard
                        let error = error as? UserErrorConvertible,
                        let vc = window?.rootViewController
                    else {
                        print(error)
                        return
                    }
                    vc.alert(error)
                }
            }
        }
    }
}
