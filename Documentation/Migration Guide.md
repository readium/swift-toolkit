# Migration Guide

All migration steps necessary in reading apps to upgrade to major versions of the Swift Readium toolkit will be documented in this file.

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

