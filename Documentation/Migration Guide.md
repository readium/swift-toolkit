# Migration Guide

All migration steps necessary in reading apps to upgrade to major versions of the Swift Readium toolkit will be documented in this file.

## 2.7.0

### `AudioNavigator` is now stable

`AudioNavigator` is now stable. Follow the deprecation errors to automatically rename the types.

All the setting properties (e.g. `navigator.rate`) are now in `navigator.settings`.

### GCDWebServer was renamed

To avoid [name collision with GCDWebServer](https://github.com/readium/swift-toolkit/issues/402), we renamed [our fork](https://github.com/readium/gcdwebserver) to `ReadiumGCDWebServer`. You will need to update your project to replace the old dependency:

* Swift Package Manager: There's nothing to do.
* Carthage:
    * Update the Carthage dependencies and make sure the new `ReadiumGCDWebServer.xcframework` was built.
    * Replace `GCDWebServer.xcframework` with `ReadiumGCDWebServer.xcframework` in your project.
* CocoaPods:
    * Replace the `pod 'GCDWebServer'` statement in your `Podfile` with the following, before running `pod install`.
        ```
        pod 'ReadiumGCDWebServer', podspec: 'https://raw.githubusercontent.com/readium/GCDWebServer/4.0.0/GCDWebServer.podspec'
        ```


## 2.5.0

In the following migration steps, only the `ReadiumInternal` one is mandatory with 2.5.0.

### New package: `ReadiumInternal`

A new Readium package was added to host the private internal utilities used by the other Readium modules. You will need to update your project to include it.

* Swift Package Manager: There's nothing to do.
* Carthage:
    * Update the Carthage dependencies and make sure the new `ReadiumInternal.xcframework` was built.
    * Add `ReadiumInternal.xcframework` to your project like any other Carthage dependency.
* CocoaPods:
    * Add the following statement to your `Podfile`, then run `pod install`:
    ```
    pod 'ReadiumInternal', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/2.5.0/Support/CocoaPods/ReadiumInternal.podspec'
    ```

:warning: It is not recommended to use any API from `ReadiumInternal` directly in your application. No compatibility guarantee is made between two versions.

### Migrating the HTTP server

:warning: Migrating to the new Preferences API (see below) is required for the user settings to work with the new HTTP server.

The Streamer's `PublicationServer` is now deprecated and you don't need to manage the HTTP server or register publications manually to it anymore.

Instead, the EPUB, PDF and CBZ navigators expect an instance of `HTTPServer` upon creation. They will take care of registering and removing the publication automatically from the provided server.

You can implement your own HTTP server using a third-party library. But the easiest way to migrate is to use the one provided in the new Readium package `ReadiumAdapterGCDWebServer`.

```swift
import R2Navigator
import ReadiumAdapterGCDWebServer

let navigator = try EPUBNavigatorViewController(
    publication: publication,
    httpServer: GCDHTTPServer.shared
)
```

### Upgrading to the new Preferences API

The 2.5.0 release introduces a brand new user preferences API for configuring the EPUB and PDF Navigators. This new API is easier and safer to use. To learn how to integrate it in your app, [please refer to the user guide](Guides/Navigator%20Preferences.md).

If you integrated the EPUB navigator from a previous version, follow these steps to migrate:

1. Get familiar with [the concepts of this new API](Guides/Navigator%20Preferences.md#overview).
2. Migrate the local HTTP server from your app, [as explained in the previous section](#migrating-the-http-server).
3. Adapt your user settings interface to the new API using preferences editors. The [Test App](https://github.com/readium/swift-toolkit/blob/2.5.0/TestApp/Sources/Reader/Common/Preferences/UserPreferences.swift) and the [user guide](Guides/Navigator%20Preferences.md#build-a-user-settings-interface) contain examples using SwiftUI.
4. [Handle the persistence of the user preferences](Guides/Navigator%20Preferences.md#save-and-restore-the-user-preferences). The settings are not stored in the User Defaults by the toolkit anymore. Instead, you are responsible for persisting and restoring the user preferences as you see fit (e.g. as a JSON file).
    * If you want to migrate the legacy EPUB settings, you can use the helper `EPUBPreferences.fromLegacyPreferences()` which will create a new `EPUBPreferences` object after translating the existing user settings.
5. Make sure you [restore the stored user preferences](Guides/Navigator%20Preferences.md#setting-the-initial-navigator-preferences-and-app-defaults) when initializing the EPUB navigator.

Please refer to the following table for the correspondence between legacy settings (from `UserSettings`) and new ones (`EPUBPreferences`).

| **Legacy**          | **New**                                                |
|---------------------|--------------------------------------------------------|
| `appearance`        | `theme`                                                |
| `backgroundColor`   | `backgroundColor`                                      |
| `columnCount`       | `columnCount` (reflowable) and `spread` (fixed-layout) |
| `fontFamily`        | `fontFamily`                                           |
| `fontOverride`      | N/A (handled automatically)                            |
| `fontSize`          | `fontSize`                                             |
| `hyphens`           | `hyphens`                                              |
| `letterSpacing`     | `letterSpacing`                                        |
| `lineHeight`        | `lineHeight`                                           |
| `pageMargins`       | `pageMargins`                                          |
| `paragraphMargins`  | `paragraphSpacing`                                     |
| `publisherDefaults` | `publisherStyles`                                      |
| `textAlignment`     | `textAlign`                                            |
| `textColor`         | `textColor`                                            |
| `verticalScroll`    | `scroll`                                               |
| `wordSpacing`       | `wordSpacing`                                          |
| N/A                 | `fontWeight`                                           |
| N/A                 | `imageFilter`                                          |
| N/A                 | `language`                                             |
| N/A                 | `ligatures`                                            |
| N/A                 | `paragraphIndent`                                      |
| N/A                 | `readingProgression`                                   |
| N/A                 | `textNormalization`                                    |
| N/A                 | `typeScale`                                            |
| N/A                 | `verticalText`                                         |

### Edge tap and keyboard navigation

2.5.0 ships with a new `DirectionalNavigationAdapter` helper to turn pages with the arrows and space keyboard keys or taps on the edge of the screen. To use it, you need to implement the following `VisualNavigatorDelegate` methods.

```swift
extension ReaderViewController: VisualNavigatorDelegate {

    func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
        let moved = DirectionalNavigationAdapter(navigator: navigator).didTap(at: point)
        if !moved {
            toggleNavigationBar()
        }
    }
    
    func navigator(_ navigator: VisualNavigator, didPressKey event: KeyEvent) {
        DirectionalNavigationAdapter(navigator: navigator).didPressKey(event: event)
    }
}
```

`DirectionalNavigationAdapter` offers a lot of customization options, take a look at the type documentation.


## 2.2.0

With this new release, we migrated all the [`r2-*-swift`](https://github.com/readium/?q=r2-swift) repositories to [a single `swift-toolkit` repository](https://github.com/readium/r2-testapp-swift/issues/404).

The same Readium libraries are available as before, but you will need to update the configuration of your dependency manager.

### Using Swift Package Manager

With SPM, instead of having one Swift Package per Readium library, we now have a single Readium Swift Package offering one product per Readium library.

First, remove all the Readium Swift Packages from your project setting, from the tab **Package Dependencies**. Then, add the new Swift Package using the following URL `https://github.com/readium/swift-toolkit.git`.

Xcode will then ask you which Package Product you want to add to your app. Add the ones you were using previously.

That's all, your project should build successfully.

### Using Carthage

Just replace the former Readium `Cartfile` statements with the new one:

```diff
+github "readium/swift-toolkit" ~> 2.2.0
-github "readium/r2-shared-swift" ~> 2.2.0
-github "readium/r2-streamer-swift" ~> 2.2.0
-github "readium/r2-navigator-swift" ~> 2.2.0
-github "readium/r2-opds-swift" ~> 2.2.0
-github "readium/r2-lcp-swift" ~> 2.2.0
```

Then, rebuild the libraries using `carthage update --platform ios --use-xcframeworks --cache-builds`. Carthage will build all the Readium libraries and their dependencies, but you are free to add only the ones you are using as before. Take a look at the [README](../README.md#carthage) for more information.

### Using CocoaPods

If you are using CocoaPods, you will need to update the URL to the Podspecs in your `Podfile`:

```diff
+  pod 'R2Shared', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/2.2.0/Support/CocoaPods/ReadiumShared.podspec'
+  pod 'R2Streamer', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/2.2.0/Support/CocoaPods/ReadiumStreamer.podspec'
+  pod 'R2Navigator', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/2.2.0/Support/CocoaPods/ReadiumNavigator.podspec'
+  pod 'ReadiumOPDS', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/2.2.0/Support/CocoaPods/ReadiumOPDS.podspec'
+  pod 'ReadiumLCP', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/2.2.0/Support/CocoaPods/ReadiumLCP.podspec'

-  pod 'R2Shared', podspec: 'https://raw.githubusercontent.com/readium/r2-shared-swift/2.2.0/R2Shared.podspec'
-  pod 'R2Streamer', podspec: 'https://raw.githubusercontent.com/readium/r2-streamer-swift/2.2.0/R2Streamer.podspec'
-  pod 'R2Navigator', podspec: 'https://raw.githubusercontent.com/readium/r2-navigator-swift/2.2.0/R2Navigator.podspec'
-  pod 'ReadiumOPDS', podspec: 'https://raw.githubusercontent.com/readium/r2-opds-swift/2.2.0/ReadiumOPDS.podspec'
-  pod 'ReadiumLCP', podspec: 'https://raw.githubusercontent.com/readium/r2-lcp-swift/2.2.0/ReadiumLCP.podspec'
```

Then, run `pod install` to update your project.

### Using a fork

If you are integrating your own forks of the Readium modules, you will need to migrate them to a single fork and port your changes. Follow strictly the given steps and it should go painlessly.

1. Upgrade your forks to the latest Readium 2.2.0 version from the legacy repositories, as you would with any update. The 2.2.0 version is available on both the legacy repositories and the new `swift-toolkit` one. It will be used to port your changes over to the single repository.
2. [Fork the new `swift-toolkit` repository](https://github.com/readium/swift-toolkit/fork) on your own GitHub space.
3. In a new local directory, clone your legacy forks as well as the new single fork:
    ```sh
    mkdir readium-migration
    cd readium-migration
   
    # Clone the legacy forks
    git clone https://github.com/USERNAME/r2-shared-swift.git
    git clone https://github.com/USERNAME/r2-streamer-swift.git
    git clone https://github.com/USERNAME/r2-navigator-swift.git
    git clone https://github.com/USERNAME/r2-opds-swift.git
    git clone https://github.com/USERNAME/r2-lcp-swift.git
   
    # Clone the new single fork
    git clone https://github.com/USERNAME/swift-toolkit.git
    ```
4. Reset the new fork to be in the same state as the 2.2.0 release.
    ```sh
    cd swift-toolkit
    git reset --hard 2.2.0
    ```
5. For each Readium module, port your changes over to the new fork.
    ```sh
    rm -rf Sources/*/*
   
    # Copy module sources
    cp -r ../r2-shared-swift/r2-shared-swift/* Sources/Shared
    cp -r ../r2-streamer-swift/r2-streamer-swift/* Sources/Streamer
    cp -r ../r2-navigator-swift/r2-navigator-swift/* Sources/Navigator
    cp -r ../r2-opds-swift/readium-opds/* Sources/OPDS
    cp -r ../r2-lcp-swift/readium-lcp-swift/* Sources/LCP

    # Remove obsolete files
    rm -rf Sources/*/Info.plist
    rm -rf Sources/*/*.h
    ```
6. Review your changes, then commit.
    ```sh
    git add Sources
    git commit -m "Apply local changes to Readium"
    ```
7. Finally, pull the changes to upgrade to the latest version of the fork. You might need to fix some conflicts.
    ```sh
    git pull --rebase
    git push
    ```
   
Your fork is now ready! To integrate it in your app as a local Git clone or submodule, follow the instructions from the [README](../README.md).


## [2.0.0](https://github.com/readium/r2-testapp-swift/compare/2.2.0-beta.2...2.2.0)

Nothing to change in your app to upgrade from 2.0.0-beta.2 to the final 2.0.0 release! Please follow the relevant sections if you are upgrading from an older version.

R2 modules are referencing regular `.framework` files again instead of XCFrameworks, [to fix an issue with Xcode 12.5](https://github.com/readium/r2-testapp-swift/issues/351#issuecomment-829250100). No change should be needed in your app though.

Note that all the APIs marked as deprecated in previous versions are now unavailable. You will need to follow the warning instructions if you were still using them.


## [2.0.0-beta.2](https://github.com/readium/r2-testapp-swift/compare/2.2.0-beta.1...2.2.0-beta.2)

This is the last beta before the final 2.0.0 release.

### Using XCFrameworks to build with Xcode 12

This new version requires Xcode 12 and Carthage 0.37.0 to work and is now using XCFrameworks for its dependencies. You will need to upgrade your app to use XCFrameworks as well.

Migrating a project to XCFrameworks is [explained on Carthage's repository](https://github.com/Carthage/Carthage#migrating-a-project-from-framework-bundles-to-xcframeworks) and you can see [an example of how it was done in `r2-testapp-swift`](https://github.com/readium/r2-testapp-swift/commit/1a3fc2bb25f0d1cf17a60e7cdb8756a0dbb6a3f6). Here is a breakdown of the steps to follow:

1. Delete your `Carthage/Build` folders to remove any existing framework bundles.
2. Upgrade your `Cartfile` to the latest dependency versions (see `r2-testapp-swift`).
3. Clear Carthage and Xcode's cache
    ```shell
    $ rm -rf ~/Library/Developer/Xcode/DerivedData
    $ rm -rf ~/Library/Caches/org.carthage.CarthageKit
    $ rm -rf ~/Library/Caches/carthage
    ```
4. Run `carthage update --use-xcframeworks --platform ios --cache-builds` to build the XCFrameworks.
5. Remove references to the old frameworks in each of your targets:
    * **WARNING**: `R2LCPClient.framework` is not XCFramework-ready, so you need to keep it as-is.
    * Delete references to Carthage frameworks from the target's **Frameworks, Libraries, and Embedded Content** section and/or its **Link Binary with Libraries** build phase.
    * Delete references to Carthage frameworks from any **Copy Files** build phases.
    * Remove all Carthage frameworks except `R2LCPClient.framework` from the target's `carthage copy-frameworks` build phase, if present.
6. Add references to XCFrameworks in each of your targets:
    * In the **General** settings tab, in the **Frameworks, Libraries, and Embedded Content** section, drag and drop each XCFramework from the `Carthage/Build` folder on disk.

#### Troubleshooting

If after migrating to XCFrameworks you experience some build issues like **Could not find module 'R2Shared' for target 'X'**, try building the `r2-shared-swift` target with Xcode manually, before building your app. If you know of a better way to handle this, [please share it with the community](https://github.com/readium/r2-testapp-swift/issues/new).

### LCP

#### Providing `liblcp`/`R2LCPClient` to `r2-lcp-swift`

[The dependency to `R2LCPClient.framework` was removed from `r2-lcp-swift`](https://github.com/readium/r2-lcp-swift/pull/112), which means:
  * Now `r2-lcp-swift` works as a regular Carthage dependency, you do not need to use a submodule anymore.
  * You do not need to modify `r2-lcp-swift`'s `Cartfile` anymore to add the private `liblcp` dependency.

However, you must provide a `R2LCPClient` facade to `LCPService` in your app. [See `r2-lcp-swift`'s README for up-to-date explanation](https://github.com/readium/r2-lcp-swift) or use the following snippet.

```swift
import R2LCPClient
import ReadiumLCP

let lcpService = LCPService(client: LCPClient())

/// Facade to the private R2LCPClient.framework.
class LCPClient: ReadiumLCP.LCPClient {

    func createContext(jsonLicense: String, hashedPassphrase: String, pemCrl: String) throws -> LCPClientContext {
        return try R2LCPClient.createContext(jsonLicense: jsonLicense, hashedPassphrase: hashedPassphrase, pemCrl: pemCrl)
    }

    func decrypt(data: Data, using context: LCPClientContext) -> Data? {
        return R2LCPClient.decrypt(data: data, using: context as! DRMContext)
    }

    func findOneValidPassphrase(jsonLicense: String, hashedPassphrases: [String]) -> String? {
        return R2LCPClient.findOneValidPassphrase(jsonLicense: jsonLicense, hashedPassphrases: hashedPassphrases)
    }

}
```

##### Troubleshooting

If you experience the following crash during runtime:

> dyld: Library not loaded: @rpath/R2LCPClient.framework/R2LCPClient

Make sure you embed the `R2LCPClient.framework` with a **Copy Carthage Frameworks** build phase. [See Carthage's README](https://github.com/Carthage/Carthage).

#### New loan renew API

[The Renew Loan LCP API got revamped](https://github.com/readium/r2-lcp-swift/pull/107) to better support Web vs PUT interactions. You need to provide an implementation of `LCPRenewDelegate` to `LCPLicense::renewLoan()`. Readium ships with a default `LCPDefaultRenewDelegate` implementation using `SFSafariViewController` for web interactions.

[See this commit for a migration example in `r2-testapp-swift`](https://github.com/readium/r2-testapp-swift/commit/79a00703c854a52b2272c042fd44e3bbabfeee8a).

## [2.0.0-beta.1](https://github.com/readium/r2-testapp-swift/compare/2.2.0-alpha.2...2.2.0-beta.1)

The version 2.0.0-beta.1 is mostly stabilizing the new APIs and fixing existing bugs. There's only two changes which might impact your codebase.

### Replacing `Format` by `MediaType`

To simplify the new format API, [we merged `Format` into `MediaType`](https://github.com/readium/architecture/pull/145) to offer a single interface. If you were using `Format`, you should be able to replace it by `MediaType` seamlessly.

### Replacing `File` by `FileAsset`

[`Streamer.open()` is now expecting an implementation of `PublicationAsset`](https://github.com/readium/architecture/pull/147) instead of an instance of `File`. This allows to open publications which are not represented as files on the device. For example a stream, an URL or any other custom structure.

Readium ships with a default implementation named `FileAsset` replacing the previous `File` type. The API is the same so you can just replace `File` by `FileAsset` in your project.


## [2.0.0-alpha.2](https://github.com/readium/r2-testapp-swift/compare/2.2.0-alpha.1...2.2.0-alpha.2)

The 2.0.0 introduces numerous new APIs in the Shared Models, Streamer and LCP libraries, which are detailed in the following proposals. We highly recommend skimming over the "Developer Guide" section of each proposal before upgrading to this new major version.

* [Format API](https://readium.org/architecture/proposals/001-format-api)
* [Composite Fetcher API](https://readium.org/architecture/proposals/002-composite-fetcher-api)
* [Publication Encapsulation](https://readium.org/architecture/proposals/003-publication-encapsulation)
* [Publication Helpers and Services](https://readium.org/architecture/proposals/004-publication-helpers-services)
* [Streamer API](https://readium.org/architecture/proposals/005-streamer-api)
* [Content Protection](https://readium.org/architecture/proposals/006-content-protection)

[This `r2-testapp-swift` commit](https://github.com/readium/r2-testapp-swift/commit/f2f7ed059c4159dfde0549968aa3c564b8278a16) showcases all the changes required to upgrade the Test App.

[Please reach out on Slack](http://readium-slack.herokuapp.com/) if you have any issue migrating your app to Readium 2.0.0, after checking the [troubleshooting section](#troubleshooting).

### Replacing the Parsers with `Streamer`

Whether you were using individual `PublicationParser` implementations or `Publication.parse()` to open a publication, you will need to replace them by an instance of `Streamer` instead.

#### Opening a Publication

Call `Streamer::open()` to parse a publication. It will return asynchronously a self-contained `Publication` model which handles metadata, resource access and DRM decryption. This means that `Container`, `PubBox` and `DRM` are not needed anymore, you can remove any reference from your app.

The `allowUserInteraction` parameter should be set to `true` if you intend to render the parsed publication to the user. It will allow the Streamer to display interactive dialogs, for example to enter DRM credentials. You can set it to `false` if you're parsing a publication in a background process, for example during bulk import.

```swift
let streamer = Streamer()

streamer.open(file: File(url: url), allowUserInteraction: true) { result in
    switch result {
    case .success(let publication):
        // ...
    case .failure(let error):
        alert(error.localizedDescription)
    case .cancelled:
        break
    }
}
```

#### Error Feedback

In case of failure, a `Publication.OpeningError` is returned. It implements `LocalizedError` and can be used directly to present an error message to the user.

If you wish to customize the error messages or add translations, you can override the strings declared in `r2-shared-swift/Resources/Localizable.strings` in your own app bundle. This goes for LCP errors as well, which are declared in `readium-lcp-swift/Resources/Localizable.strings`.

#### Advanced Usage

`Streamer` offers other useful APIs to extend the capabilities of the Readium toolkit. Take a look at its documentation for more details, but here's an overview:

* Add new custom parsers.
* Integrated DRM support, such as LCP.
* Provide different implementations for third-party tools, e.g. ZIP, PDF and XML.
* Customize the `Publication`'s metadata or `Fetcher` upon creation.
* Collect authoring warnings from parsers.

### Extracting Publication Covers

Extracting the cover of a publication for caching purposes can be done with a single call to `publication.cover`, instead of reaching for a `Link` with `cover` relation. You can use `publication.coverFitting(maxSize:)` to select the best resolution without exceeding a given size. It can be useful to avoid saving very large cover images.

```diff
-let cover = publication.coverLink
-    .flatMap { try? container.data(relativePath: $0.href) }
-    .flatMap { UIImage(data: $0) }

+let cover = publication.coverFitting(maxSize: CGSize(width: 100, height: 100))
```

### LCP and Other DRMs

#### Opening an LCP Protected Publication

Support for LCP is now fully integrated with the `Streamer`, which means that you don't need to retrieve the LCP license and fill `container.drm` yourself after opening a `Publication` anymore.

To enable the support for LCP in the `Streamer`, you need to initialize it with a `ContentProtection` implementation provided by `r2-lcp-swift`.

```swift
let lcpService = LCPService()
let streamer = Streamer(
    contentProtections: [
        lcpService.contentProtection()
    ]
)
```

Then, to prompt the user for their passphrase, you need to set `allowUserInteraction` to `true` and provide the instance of the hosting `UIViewController` with the `sender` parameter when opening the publication.

```swift
streamer.open(file: File(url: url), allowUserInteraction: true, sender: hostViewController)
```

Alternatively, if you already have the passphrase, you can pass it directly to the `credentials` parameter. If it's valid, the user won't be prompted.

#### Customizing the Passphrase Dialog

The LCP Service now ships with a default passphrase dialog. You can remove the former implementation from your app if you copied it from the test app. But if you still want to use a custom implementation of `LCPAuthenticating`, for example to have a different layout, you can pass it when creating the `ContentProtection`.

```swift
lcpService.contentProtection(with: CustomLCPAuthentication())
```

#### Presenting a Protected Publication with a Navigator

In case the credentials were incorrect or missing, the `Streamer` will still return a `Publication`, but in a "restricted" state. This allows reading apps to import publications by accessing their metadata without having the passphrase.

But if you need to present the publication with a Navigator, you will need to first check if the `Publication` is not restricted.

Besides missing credentials, a publication can be restricted if the Content Protection returned an error, for example when the publication is expired. In which case, you must display the error to the user by checking the presence of a `publication.protectionError`.

```swift
if !publication.isRestricted {
    presentNavigator(publication)

} else if let error = publication.protectionError {
    // A status error occurred, for example the publication expired
    alert(error)

} else {
    // User cancelled the unlocking, for example by dismissing a passphrase dialog.
}
```

#### Accessing an LCP License Information

To check if a publication is protected with a known DRM, you can use `publication.isProtected`.

If you need to access an LCP license's information, you can use the helper `publication.lcpLicense`, which will return the `LCPLicense` if the publication is protected with LCP and the passphrase was known. Alternatively, you can use `LCPService::retrieveLicense()` as before.

#### Acquiring a Publication from an LCPL

`LCPService.importPublication()` was replaced with `acquirePublication()`, which returns a cancellable task. It doesn't require the user to enter its passphrase anymore to download the publication.

```swift
let acquisition = lcpService.acquirePublication(
    from: lcpl,
    onProgress: { progress in ... },
    completion: { result in ... }
)
acquisition.cancel()
```

#### Supporting Other DRMs

You can integrate additional DRMs, such as Adobe ACS, by implementing the `ContentProtection` protocol. This will provide first-class support for this DRM in the Streamer and Navigator.

Take a look at the [Content Protection](https://readium.org/architecture/proposals/006-content-protection) proposal for more details. [An example implementation can be found in `r2-lcp-swift`](https://github.com/readium/r2-lcp-swift/tree/develop/readium-lcp-swift/Content%20Protection).

### Troubleshooting

#### Tried to present the LCP dialog without providing a `UIViewController` as `sender`

To be able to present the LCP passphrase dialog, the default `LCPDialogAuthentication` needs a hosting view controller as context. You must provide it to the `sender` parameter of `Streamer::open()`, if `allowUserInteraction` is true.

```swift
streamer.open(file: File(url: url), allowUserInteraction: true, sender: hostViewController)
```

#### Assertion failed: The provided publication is restricted. Check that any DRM was properly unlocked using a Content Protection.

Navigators will refuse to be opened if a publication is protected and not unlocked. You must check if a publication is not restricted by following [these instructions](#presenting-a-protected-publication-with-a-navigator).

