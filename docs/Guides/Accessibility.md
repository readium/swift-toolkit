# Accessibility

Some publications declare their accessibility features and limitations as metadata which broadly mirror the [EPUB Accessibility](https://www.w3.org/TR/epub-a11y-11) specification.

```swift
let accessibility = publication.metadata.accessibility ?? Accessibility()

if accessibility.accessModesSufficient.contains([.textual]) {
    // This publication can be read aloud with a text-to-speech engine.
}

if accessibility.features.contains(.displayTransformability) {
    // The text and layout of this publication can be customized.
}
```

## Displaying accessibility metadata

While the [RWPM Accessibility models](https://readium.org/webpub-manifest/contexts/default/#accessibility-metadata) provide valuable information, they may be too complex and detailed to present to the user as it is. To simplify the presentation of this metadata to users, the Readium toolkit implements the [Accessibility Metadata Display Guide](https://w3c.github.io/publ-a11y/a11y-meta-display-guide/2.0/guidelines/) specification, developed by the W3C.

### How is the display guide structured?

The guide contains a list of fields that can be displayed as sections in your user interface. Each field has a list of related statements. For example, the `WaysOfReading` field provides information about whether the user can customize the text and layout (`visualAdjustments`) or if it is readable with text-to-speech or dynamic braille (`nonvisualReading`).

```swift
let guide = AccessibilityMetadataDisplayGuide(publication: publication)

switch guide.waysOfReading.visualAdjustments {
case .modifiable:
    // The text and layout of the publication can be customized.
case .unmodifiable:
    // The text and layout cannot be modified.
case .unknown:
    // No metadata provided
}
```

### Localized accessibility statements

While you are free to manually inspect the accessibility fields, the toolkit offers an API to automatically convert them into a list of localized statements (or claims) for direct display to the user.

Each statement has a *compact* and *descriptive* variant. The *descriptive* string is longer and provides more details about the claim.

For example:
- **Compact**: Prerecorded audio clips
- **Descriptive**: Prerecorded audio clips are embedded in the content

```swift
for statement in guide.waysOfReading.statements {
    print(statement.localizedString(descriptive: false))
}
```

If translations are missing in your language, **you are encouraged to submit a contribution [to the official W3C repository](https://github.com/w3c/publ-a11y-display-guide-localizations)**. Alternatively, you can override or translate the strings from `W3CAccessibilityMetadataDisplayGuide.strings` in the host application.

### Displaying all the recommended fields

If you wish to display all the accessibility fields as recommended in the official specification, you can iterate over all the fields and their statements in the guide.

The `shouldDisplay` property indicates whether the field does not have any meaningful statement. In which case, you may skip it in your user interface.

```swift
for field in guide.fields {
    guard field.shouldDisplay else {
        continue
    }

    print("Section: \(field.localizedTitle)")

    for statement in field.statements {
        print(statement.localizedString(descriptive: false))
    }
}
```

### Sample implementation in SwiftUI

```swift
struct AccessibilityMetadataView: View {

    var guide: AccessibilityMetadataDisplayGuide

    /// Indicates whether accessibility claims are displayed in their full
    /// descriptive statements.
    @State private var showDescriptive: Bool = false

    var body: some View {
        List {
            Text("Accessibility Claims")
                .font(.title)

            Toggle("Show descriptive statements", isOn: $showDescriptive)

            ForEach(guide.fields, id: \.id) { field in
                if field.shouldDisplay {
                    Section(field.localizedTitle) {
                        ForEach(field.statements) { statement in
                            Text(AttributedString(statement.localizedString(descriptive: showDescriptive)))
                        }
                    }
                }
            }
        }
    }
}
```
