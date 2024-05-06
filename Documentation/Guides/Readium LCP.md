# Supporting Readium LCP

You can use the Readium Swift toolkit to download and read publications that are protected with the [Readium LCP](https://www.edrlab.org/readium-lcp/) DRM.

:point_up: To use LCP with the Readium toolkit, you must first obtain the `R2LCPClient` private library by contacting [EDRLab](https://www.edrlab.org/contact/).

## Overview

An LCP publication is protected with a *user passphrase* and distributed using an LCP License Document (`.lcpl`) .

The user flow typically goes as follows:

1. The user imports a `.lcpl` file into your application.
2. The application uses the Readium toolkit to download the protected publication from the `.lcpl` file to the user's bookshelf. The downloaded file can be a `.epub`, `.lcpdf` (PDF), or `.lcpa` (audiobook) package.
3. The user opens the protected publication from the bookshelf.
4. If the passphrase isn't already recorded in the `ReadiumLCP` internal database, the user will be asked to enter it to unlock the contents.
5. The publication is decrypted and rendered on the screen.

## Setup

To support LCP in your application, you require two components:

* The `ReadiumLCP` package from the toolkit provides APIs for downloading and decrypting protected publications. Import it as you would any other Readium package, such as `R2Navigator`.
* The private `R2LCPClient` library customized for your application [is available from EDRLab](https://www.edrlab.org/contact/). They will provide instructions for integrating the `R2LCPClient` framework into your application.

### File formats

Readium LCP specifies new file formats.

| Name | File extension | Media type |
|------|----------------|------------|
| [License Document](https://readium.org/lcp-specs/releases/lcp/latest.html#32-content-conformance) | `.lcpl` | `application/vnd.readium.lcp.license.v1.0+json` |
| [LCP for PDF package](https://readium.org/lcp-specs/notes/lcp-for-pdf.html) | `.lcpdf` | `application/pdf+lcp` |
| [LCP for Audiobooks package](https://readium.org/lcp-specs/notes/lcp-for-audiobooks.html) | `.lcpa` | `application/audiobook+lcp` |

:point_up: EPUB files protected by LCP are supported without a special file extension or media type because EPUB accommodates any DRM scheme in its specification.

To support these formats in your application, you need to [register them in your `Info.plist`](https://developer.apple.com/documentation/uniformtypeidentifiers/defining_file_and_data_types_for_your_app) as imported types.

```xml
<dict>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>org.readium.lcpl</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.content</string>
                <string>public.data</string>
                <string>public.json</string>
            </array>
            <key>UTTypeDescription</key>
            <string>LCP License Document</string>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>lcpl</string>
                </array>
                <key>public.mime-type</key>
                <string>application/vnd.readium.lcp.license.v1.0+json</string>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>org.readium.lcpdf</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.content</string>
                <string>public.data</string>
                <string>public.archive</string>
                <string>public.zip-archive</string>
            </array>
            <key>UTTypeDescription</key>
            <string>LCP for PDF package</string>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>lcpdf</string>
                </array>
                <key>public.mime-type</key>
                <string>application/pdf+lcp</string>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>org.readium.lcpa</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.content</string>
                <string>public.data</string>
                <string>public.archive</string>
                <string>public.zip-archive</string>
            </array>
            <key>UTTypeDescription</key>
            <string>LCP for Audiobooks package</string>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>lcpa</string>
                </array>
                <key>public.mime-type</key>
                <string>application/audiobook+lcp</string>
            </dict>
        </dict>
    </array>
</dict>
```

Next, declare the imported types as [Document Types](https://help.apple.com/xcode/mac/current/#/devddd273fdd) in the `Info.plist` to have your application listed in the "Open with..." dialogs.

```xml
<dict>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>LCP License Document</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>org.readium.lcpl</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>
            <string>LCP for PDF package</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>org.readium.lcpdf</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>
            <string>LCP for Audiobooks package</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>org.readium.lcpa</string>
            </array>
        </dict>
    </array>
</dict>
```

:point_up: If EPUB is not included in your document types, now is a good time to add it.

## Initializing the `LCPService`

`ReadiumLCP` offers an `LCPService` object that exposes its API. Since the `ReadiumLCP` package is not linked with `R2LCPClient`, you need to create your own adapter when setting up the `LCPService`.

```swift
import R2LCPClient
import ReadiumLCP

let lcpService = LCPService(client: LCPClientAdapter())

/// Facade to the private R2LCPClient.framework.
class LCPClientAdapter: ReadiumLCP.LCPClient {
    func createContext(jsonLicense: String, hashedPassphrase: String, pemCrl: String) throws -> LCPClientContext {
        try R2LCPClient.createContext(jsonLicense: jsonLicense, hashedPassphrase: hashedPassphrase, pemCrl: pemCrl)
    }

    func decrypt(data: Data, using context: LCPClientContext) -> Data? {
        R2LCPClient.decrypt(data: data, using: context as! DRMContext)
    }

    func findOneValidPassphrase(jsonLicense: String, hashedPassphrases: [String]) -> String? {
        R2LCPClient.findOneValidPassphrase(jsonLicense: jsonLicense, hashedPassphrases: hashedPassphrases)
    }
}
```

## Acquiring a publication from a License Document (LCPL)

Users need to import a License Document into your application to download the protected publication (`.epub`, `.lcpdf`, or `.lcpa`).

The `LCPService` offers an API to retrieve the full publication from an LCPL on the filesystem.

```swift
let acquisition = lcpService.acquirePublication(
    from: lcplURL,
    onProgress: { progress in
        switch progress {
            case .indefinite:
                // Display an activity indicator.
            case .percent(let percent):
                // Display a progress bar with percent from 0 to 1.
        }
    },
    completion: { result in
        switch result {
        case let .success(publication):
            // Import the `publication.localURL` file as any publication.
        case let .failure(error):
            // Display the error message
        case .cancelled:
            // The acquisition was cancelled before completion.
        }
    }
)
```

If the user wants to cancel the download, call `cancel()` on the object returned by `LCPService.acquirePublication()`.

After the download is completed, import the `publication.localURL` file into the bookshelf like any other publication file.

## Opening a publication protected with LCP

### Initializing the `Streamer`

A publication protected with LCP can be opened using the `Streamer` component, just like a non-protected publication. However, you must provide a [`ContentProtection`](https://readium.org/architecture/proposals/006-content-protection.html) implementation when initializing the `Streamer` to enable LCP. Luckily, `LCPService` has you covered.

```swift
let authentication = LCPDialogAuthentication()

let streamer = Streamer(
    contentProtections: [
        lcpService.contentProtection(with: authentication)
    ]
)
```

An LCP package is secured with a *user passphrase* for decrypting the content. The `LCPAuthenticating` protocol used by `LCPService.contentProtection(with:)` provides the passphrase when needed. You can use the default `LCPDialogAuthentication` which displays a pop-up to enter the passphrase, or implement your own method for passphrase retrieval.

:point_up: The user will be prompted once per passphrase since `ReadiumLCP` stores known passphrases on the device. 

### Opening the publication

You are now ready to open the publication file with your `Streamer` instance.

```swift
streamer.open(
    asset: FileAsset(url: publicationURL),
    allowUserInteraction: true,
    sender: hostViewController,
    completion: { result in
        switch result {
        case .success(let publication):
            // Import or present the publication.
        case .failure(let error):
            // Present the error.
        case .cancelled:
            // The operation was cancelled.
        }
    }
)
```

The `allowUserInteraction` and `sender` arguments are forwarded to the `LCPAuthenticating` implementation when the passphrase is unknown. `LCPDialogAuthentication` shows a pop-up only if `allowUserInteraction` is `true`, using the `sender` as the pop-up's host `UIViewController`.

When importing the publication to the bookshelf, set `allowUserInteraction` to `false` as you don't need the passphrase for accessing the publication metadata and cover. If you intend to present the publication using a Navigator, set `allowUserInteraction` to `true` as decryption will be required.

:point_up: To check if a publication is protected with LCP before opening it, you can use `LCPService.isLCPProtected()`.

### Using the opened `Publication`

After obtaining a `Publication` instance, you can access the publication's metadata to import it into the user's bookshelf. The user passphrase is not needed for reading the metadata or cover.

However, if you want to display the publication with a Navigator, verify it is not restricted. It could be restricted if the user passphrase is unknown or if the license is no longer valid (e.g., expired loan, revoked purchase, etc.).

```swift
if publication.isRestricted {
    if let error = publication.protectionError as? LCPError {
        // The user is not allowed to open the publication. You should display the error.
    } else {
        // We don't have the user passphrase.
        // You may use `publication` to access its metadata, but not to render its content.
    }
} else {
    // The publication is not restricted, you may render it with a Navigator component.
}
```

## Obtaining information on an LCP license

An LCP License Document contains metadata such as its expiration date, the remaining number of characters to copy and the user name. You can access this information using an `LCPLicense` object.

Use the `LCPService` to retrieve the `LCPLicense` instance for a publication.

```swift
lcpService.retrieveLicense(
    from: publicationURL,
    authentication: LCPDialogAuthentication(),
    allowUserInteraction: true,
    sender: hostViewController
) { result in
    switch result {
    case .success(let lcpLicense):
        if let lcpLicense = lcpLicense {
            if let user = lcpLicense.license.user.name {
                print("The publication was acquired by \(user)")
            }
            if let endDate = lcpLicense.license.rights.end {
                print("The loan expires on \(endDate)")
            }
            if let copyLeft = lcpLicense.charactersToCopyLeft {
                print("You can copy up to \(copyLeft) characters remaining.")
            }
        } else {
            // The file was not protected by LCP.
        }
    case .failure(let error):
        // Display the error.
    case .cancelled:
        // The operation was cancelled.
    }
}
```

If you have already opened a `Publication` with the `Streamer`, you can directly obtain the `LCPLicense` using `publication.lcpLicense`.

## Managing a loan

Readium LCP allows borrowing publications for a specific period. Use the `LCPLicense` object to manage a loan and retrieve its end date using `lcpLicense.license.rights.end`.

### Returning a loan

Some loans can be returned before the end date. You can confirm this by using `lcpLicense.canReturnPublication`. To return the publication, execute:

```swift
lcpLicense.returnPublication { error in
    if let error = error {
        // Present the error.
    } else {
        // The publication was returned.
    }
}
```

### Renewing a loan

The loan end date may also be extended. You can confirm this by using `lcpLicense.canRenewLoan`.

Readium LCP supports [two types of renewal interactions](https://readium.org/lcp-specs/releases/lsd/latest#35-renewing-a-license):

* Programmatic: You show your own user interface.
* Interactive: You display a web view, and the Readium LSD server manages the renewal for you.

You need to support both interactions by implementing the `LCPRenewDelegate` protocol. A default implementation is available with `LCPDefaultRenewDelegate`.

```swift
lcpLicense.renewLoan(
    with: LCPDefaultRenewDelegate(
        presentingViewController: hostViewController
    )
) { result in
    switch result {
    case .success, .cancelled:
        // The publication was renewed.
    case let .failure(error):
        // Display the error.
    }
}
```

## Handling `LCPError`

The APIs may fail with an `LCPError`. These errors **must** be displayed to the user with a suitable message.

`LCPError` implements `LocalizedError`, enabling you to retrieve a user-friendly message. It's recommended to override the LCP localized strings in your app to translate them. These strings can be found at [Sources/LCP/Resources/en.lproj/Localizable.strings](https://github.com/readium/swift-toolkit/blob/main/Sources/LCP/Resources/en.lproj/Localizable.strings).

:warning: In the next major update, `LCPError` will no longer be localized. Applications will need to provide their own localized error messages. If you are adding LCP to a new app, consider treating `LCPError` as non-localized from the start to ease future migration.
