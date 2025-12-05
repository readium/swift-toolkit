# Navigator

You can use a Readium Navigator to present the publication to the user. The `Navigator` renders resources on the screen and offers APIs and user interactions for navigating the contents.

> [!IMPORTANT]
> Navigators do not have user interfaces besides the view that displays the publication. Applications are responsible for providing a user interface with bookmark buttons, a progress bar, etc.

## Default implementations

The Readium toolkit comes with several `Navigator` implementations for different publication profiles. Some are `UIViewController`s, designed to be added to your view hierarchy, while others are chromeless and can be used in the background.

| Navigator                     | Profile     | Formats                                                               |
|-------------------------------|-------------|-----------------------------------------------------------------------|
| `EPUBNavigatorViewController` | `epub`      | EPUB (`.epub`), Readium Web Publication (`.webpub`)                   |
| `PDFNavigatorViewController`  | `pdf`       | PDF (`.pdf`), LCP-protected PDF (`.lcpdf`)                            |
| `CBZNavigatorViewController`  | `divina`    | Zipped Comic Book (`cbz`), Readium Divina (`.divina`)                 |
| `AudioNavigator`              | `audiobook` | Zipped Audio Book (`.zab`), Readium Audiobook (`.audiobook`, `.lcpa`) |

To find out which Navigator is compatible with a publication, refer to its [profile](https://readium.org/webpub-manifest/profiles/). Use `publication.conforms(to:)` to identify the publication's profile.

```swift
if publication.conforms(to: .epub) {
    let navigator = try EPUBNavigatorViewController(
        publication: publication,
        initialLocation: lastReadLocation,
        httpServer: GCDHTTPServer.shared
    )

    hostViewController.present(navigator, animated: true)
}
```

## Navigator APIs

Navigators implement a set of shared interfaces to help reuse the reading logic across publication profiles. For example, instead of using specific implementations like `EPUBNavigatorViewController`, use the `Navigator` interface to create a location history manager compatible with all Navigator types.

You can create custom Navigators and easily integrate them into your app with minimal modifications by implementing these interfaces.

### `Navigator` interface

All Navigators implement the `Navigator` interface, which provides the foundation for navigating resources in a `Publication`. You can use it to move through the publication's content or to find the current position.

Note that this interface does not specify how the content is presented to the user.

### `VisualNavigator` interface

Navigators rendering the content visually on the screen implement the `VisualNavigator` interface. This interface offers details about the presentation style (e.g., scrolled, right-to-left, etc.) and allows monitoring input events like taps or keyboard strokes.

### `SelectableNavigator` interface

Navigators enabling users to select parts of the content implement `SelectableNavigator`. You can use it to extract the `Locator` and content of the selected portion.

### `DecorableNavigator` interface

A Decorable Navigator is able to render decorations over a publication, such as highlights or margin icons.

[See the corresponding proposal for more information](https://readium.org/architecture/proposals/008-decorator-api.html).

## Instantiating a Navigator

### Visual Navigators

The Visual Navigators are implemented as `UIViewController` and must be added to your iOS view hierarchy to render the publication contents. 

```swift
let navigator = try EPUBNavigatorViewController(
    publication: publication,
    initialLocation: lastReadLocation,
    httpServer: GCDHTTPServer.shared
)

hostViewController.present(navigator, animated: true)
```

> [!NOTE]
> The HTTP server is used to serve the publication resources to the Navigator. You may use your own implementation, or the recommended `GCDHTTPServer` which is part of the `ReadiumAdapterGCDWebServer` package.

### Audio Navigator

The `AudioNavigator` is chromeless and does not provide any user interface, allowing you to create your own custom UI.

```swift
let navigator = AudioNavigator(
    publication: publication,
    initialLocation: lastReadLocation
)

navigator.play()
```

## Navigating the contents of the publication

The `Navigator` interface offers various `go` APIs for navigating the publication. For instance:

* to the previous or next pages: `navigator.goForward()` or `navigator.goBackward()`
* to a link from the `publication.tableOfContents` or `publication.readingOrder`: `navigator.go(to: link)`
* to a locator from a search result: `navigator.go(to: locator)`

## Reading progression

### Saving and restoring the last read location

Navigators don't store any data permanently. Therefore, it is your responsibility to save the last read location in your database and restore it when creating a new Navigator.

You can observe the current position in the publication by implementing a `NavigatorDelegate`.

```swift
navigator.delegate = MyNavigatorDelegate()

class MyNavigatorDelegate: NavigatorDelegate {

    override func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
        if let position = locator.locations.position {
            print("At position \(position) on \(publication.positions.count)")
        }
        if let progression = locator.locations.progression {
            return "Progression in the current resource: \(progression)%"
        }
        if let totalProgression = locator.locations.totalProgression {
            return "Total progression in the publication: \(progression)%"
        }

        // Save the position in your bookshelf database
        database.saveLastReadLocation(locator.jsonString)
    }
}
```

The `Locator` object may be serialized to JSON in your database, and deserialized to set the initial location when creating the navigator.

```swift
let lastReadLocation = Locator(jsonString: dabase.lastReadLocation())

let navigator = try EPUBNavigatorViewController(
    publication: publication,
    initialLocation: lastReadLocation,
    httpServer: GCDHTTPServer.shared
)
```

### Bookmarking the current location

Use a Navigator's `currentLocation` property to persists the current position, for instance as a bookmark.

After the user selects a bookmark from your user interface, navigate to it using `navigator.go(bookmark.locator)`.

### Displaying a progression slider

To display a percentage-based progression slider, use the `locations.totalProgression` property of the `currentLocation`. This property holds the total progression across an entire publication.

Given a progression from 0 to 1, you can obtain a `Locator` object from the `Publication`. This can be used to navigate to a specific percentage within the publication.

```swift
if let locator = publication.locate(progression: 0.5) {
    navigator.go(to: locator)
}
```

### Displaying the number of positions

> [!NOTE]
> Readium does not have the concept of pages, as they are not useful when dealing with reflowable publications across different screen sizes. Instead, we use [**positions**](https://readium.org/architecture/models/locators/positions/) which remain stable even when the user changes the font size or device.

Not all Navigators provide positions, but most `VisualNavigator` implementations do. Verify if `publication.positions` is not empty to determine if it is supported.

To find the total positions in the publication, use `publication.positions.count`. You can get the current position with `navigator.currentLocation?.locations.position`.

## Navigating with edge taps and keyboard arrows

Readium provides a `DirectionalNavigationAdapter` helper to turn pages using arrow and space keys or screen taps.

You can use it from your `VisualNavigatorDelegate` implementation:

```swift
extension MyReader: VisualNavigatorDelegate {

    func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
        // Turn pages when tapping the edge of the screen.
        guard !DirectionalNavigationAdapter(navigator: navigator).didTap(at: point) else {
            return
        }

        toggleNavigationBar()
    }

    func navigator(_ navigator: VisualNavigator, didPressKey event: KeyEvent) {
        // Turn pages when pressing the arrow keys.
        DirectionalNavigationAdapter(navigator: navigator).didPressKey(event: event)
    }
}
```

`DirectionalNavigationAdapter` offers a lot of customization options. Take a look at its API.

## User preferences

Readium Navigators support user preferences, such as font size or background color. Take a look at [the Preferences API guide](Preferences.md) for more information.
