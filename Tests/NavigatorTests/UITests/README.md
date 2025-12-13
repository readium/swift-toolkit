# Navigator UI Tests

This test host app provides a controlled environment for running UI tests against Readium Navigators in a real app context with full WebKit and SwiftUI lifecycle. It's designed to be simple and maintainable, avoiding the complexity of the main TestApp.

## Generate Xcode Project

```bash
cd Tests/NavigatorTests/UITests
xcodegen generate
```

This creates `NavigatorUITests.xcodeproj` from `project.yml`.

## Running Tests from Xcode

1. Open `NavigatorUITests.xcodeproj`
2. Select the `NavigatorTestHost` scheme
3. Choose a simulator (iPhone or iPad)
4. Run tests: Cmd+U or Product > Test

