# r2-lcp-swift

Swift wrapper module for LCP support

[Changes and releases are documented in the Changelog](CHANGELOG.md)

## Adding the module to your iOS project

> _Note:_ requires Swift 4.2 (and Xcode 10.1).

### Carthage

[Carthage][] is a simple, decentralized dependency manager for Cocoa. To install `ReadiumLCP` with Carthage:

 1. Make sure Carthage is [installed][Carthage Installation] and up-to-date.

 2. Update your app's `Cartfile` to include the following:

    ```ruby
    github "readium/r2-lcp-swift" "develop"
    ```

 3. Run `carthage update --use-xcframeworks --platform ios` and [add the appropriate frameworks to your app][Carthage Usage].

### Integration in your project

After adding the `r2-lcp-swift` module to your project and the private `R2LCPClient.framework` provided by [EDRLab](contact@edrlab.org), you can use LCP in your app by creating an instance of `LCPService`.

`LCPService` expects an implementation of `LCPClient`, which acts as a facade to `R2LCPClient.framework`. Copy and paste the following:

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

## Dependencies in this module

  - [R2Shared](https://github.com/readium/r2-shared-swift) : Custom types shared by several readium-2 Swift modules.
  - [ZIPFoundation](https://github.com/edrlab/ZIPFoundation) : Effortless ZIP Handling in Swift
  - [SQLite.swift](https://github.com/stephencelis/SQLite.swift) : A type-safe, Swift-language layer over SQLite3.
  - [CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift) : CryptoSwift is a growing collection of standard and secure cryptographic algorithms implemented in Swift


[Carthage]: https://github.com/Carthage/Carthage
[Carthage Installation]: https://github.com/Carthage/Carthage#installing-carthage
[Carthage Usage]: https://github.com/Carthage/Carthage#adding-frameworks-to-an-application

