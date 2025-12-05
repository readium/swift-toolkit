# Font families in the EPUB navigator

Readium allows users to customize the font family used to render a reflowable EPUB, by changing the [EPUB navigator preferences](Navigator%20Preferences.md).

> [!NOTE]
> You cannot change the default font family of a fixed-layout EPUB (with zoomable pages), as it is similar to a PDF or a comic book.

## Available font families

iOS ships with a large collection of font families that you can use directly in the EPUB preferences. [Take a look at the Apple catalog of System Fonts](https://developer.apple.com/fonts/system-fonts/).

To improve readability, Readium embeds three additional font families designed for accessibility:

* [OpenDyslexic](https://opendyslexic.org/)
* [AccessibleDfA](https://github.com/Orange-OpenSource/font-accessible-dfa), by Orange
* [iA Writer Duospace](https://github.com/iaolo/iA-Fonts/tree/master/iA%20Writer%20Duospace), by iA

You can use all the iOS System Fonts out of the box with the EPUB navigator:

```swift
epubNavigator.submitPreferences(EPUBPreferences(
    fontFamily: "Palatino"
))
```

Alternatively, extend `FontFamily` to benefit from the compiler type safety:

```swift
extension FontFamily {
    public static let palatino: FontFamily = "Palatino"
}

epubNavigator.submitPreferences(EPUBPreferences(
    fontFamily: .palatino
))
```

For your convenience, a number of [recommended fonts](https://readium.org/readium-css/docs/CSS09-default_fonts) are pre-declared in the `FontFamily` type: Iowan Old Style, Palatino, Athelas, Georgia, Helvetica Neue, Seravek and Arial.

## Setting the available font families in the user interface

If you build your settings user interface with the EPUB Preferences Editor, you can customize the list of available font families using `with(supportedValues:)`.

```swift
epubPreferencesEditor.fontFamily.with(supportedValues: [
    nil, // A `nil` value means that the original author font will be used.
    .palatino,
    .helveticaNeue,
    .iaWriterDuospace,
    .accessibleDfA,
    .openDyslexic
])
```

## How to add custom font families?

To offer more choices to your users, you must embed and declare custom font families. Use the following steps:

1. Get the font files in the desired format, such as .ttf and .otf. [Google Fonts](https://fonts.google.com/) is a good source of free fonts.
2. Add the files to your app target from Xcode.
3. Declare new extensions for your custom font families to make them first-class citizens. This is optional but convenient.
    ```swift
    extension FontFamily {
        public static let literata: FontFamily = "Literata"
        public static let atkinsonHyperlegible: FontFamily = "Atkinson Hyperlegible"
    }
    ```
4. Configure the EPUB navigator with a declaration of the font faces for all the additional font families.
    ```swift
    let resources = Bundle.main.resourceURL!
    let navigator = try EPUBNavigatorViewController(
        publication: publication,
        initialLocation: locator,
        config: .init(
            fontFamilyDeclarations: [
                CSSFontFamilyDeclaration(
                    fontFamily: .literata,
                    fontFaces: [
                        // Literata is a variable font family, so we can provide a font weight range.
                        // https://fonts.google.com/knowledge/glossary/variable_fonts
                        CSSFontFace(
                            file: resources.appendingPathComponent("Literata-VariableFont_opsz,wght.ttf"),
                            style: .normal, weight: .variable(200...900)
                        ),
                        CSSFontFace(
                            file: resources.appendingPathComponent("Literata-Italic-VariableFont_opsz,wght.ttf"),
                            style: .italic, weight: .variable(200...900)
                        )
                    ]
                ).eraseToAnyHTMLFontFamilyDeclaration(),

                CSSFontFamilyDeclaration(
                    fontFamily: .atkinsonHyperlegible,
                    fontFaces: [
                        CSSFontFace(
                            file: resources.appendingPathComponent("Atkinson-Hyperlegible-Regular.ttf"),
                            style: .normal, weight: .standard(.normal)
                        ),
                        CSSFontFace(
                            file: resources.appendingPathComponent("Atkinson-Hyperlegible-Italic.ttf"),
                            style: .italic, weight: .standard(.normal)
                        ),
                        CSSFontFace(
                            file: resources.appendingPathComponent("Atkinson-Hyperlegible-Bold.ttf"),
                            style: .normal, weight: .standard(.bold)
                        ),
                        CSSFontFace(
                            file: resources.appendingPathComponent("Atkinson-Hyperlegible-BoldItalic.ttf"),
                            style: .italic, weight: .standard(.bold)
                        ),
                    ]
                ).eraseToAnyHTMLFontFamilyDeclaration()
            ]
        ),
        httpServer: GCDHTTPServer.shared
    )
    ```

You are now ready to use your custom font families.

