# Maintaining the Readium Swift toolkit

## Bumping the Minimum iOS Deployment Target

To bump the minimum required iOS version, update these files:

- `README.md`, section "Minimum Requirements"
- `Package.swift`
- `Support/CocoaPods/*.podspec` – edit `iosTarget` in `Support/CocoaPods/Specs.swift`, then run `make podspecs` and commit the generated files

## Creating a New Package

A new package is a separately distributable SPM library product. It requires updates to four places.

### 1. `Package.swift`

Add a new product and its source/test targets:

```swift
// products:
.library(name: "Readium<ModuleName>", targets: ["Readium<ModuleName>"]),

// targets:
.target(
    name: "Readium<ModuleName>",
    dependencies: ["ReadiumShared", "ReadiumNavigator"],
    path: "Sources/<ModuleName>"
),
.testTarget(
    name: "Readium<ModuleName>Tests",
    dependencies: ["Readium<ModuleName>"],
    path: "Tests/<ModuleName>Tests"
),
```

### 2. `Support/CocoaPods/Readium<ModuleName>.podspec`

Add an entry to `Support/CocoaPods/Specs.swift` and run `make podspecs` to generate the podspec file.

## Releasing a New Version

You are ready to release a new version of the Swift toolkit? Great, follow these steps:

1. Figure out the next version using the [semantic versioning scheme](https://semver.org).
2. Test a migration from the last released version.
    1. Create a **temporary** Git tag for `develop` with the next version tag (e.g. `3.0.1`).
    2. Clone the `swift-toolkit` from the previous version (`main` branch).
    3. Under `TestApp`, initialize it with the next toolkit version:
        ```shell
        make spm version=VERSION lcp=...
        ```
    4. Try to run the Test App, adjusting the integration if needed.
    5. Delete the Git tag created previously.
3. Review the list of supported features in `README.md`.
4. Update the [migration guide](docs/Migration%20Guide.md) in case of breaking changes.
5. Prepare the release.
    ```shell
    scripts/release-prepare.sh VERSION
    ```
    This script does the following:

    1. Creates a branch with the same name as the future tag, from `develop`.
    2. Bumps `version` in `Support/CocoaPods/Specs.swift`, then runs `make podspecs`.
    3. Bumps the version numbers in `README.md`, and checks the "Minimum Requirements" section.
    4. Bumps the version numbers in `TestApp/Sources/Info.plist`.
    5. Closes the version in the `CHANGELOG.md`, [for example](https://github.com/readium/swift-toolkit/pull/353/commits/a0714589b3da928dd923ba78f379116715797333#diff-06572a96a58dc510037d5efa622f9bec8519bc1beab13c9f251e97e657a9d4ed).
    6. Updates the localized strings (`make update-locales`).
    7. Creates a PR to merge in `develop`.
6. Verify the CI checks pass for the PR. **Do not merge it yet**.
7. Release the updated Podspecs.
    ```shell
    scripts/release-publish-podspecs.sh
    ```
8. Squash and merge the release PR on GitHub.
9. Tag the new version from `develop`.
    ```shell
    scripts/release-tag.sh
    ```
    This script does the following:
    ```shell
    git checkout develop
    git pull
    git tag -a VERSION -m VERSION
    git push --tags
    ```
10. Verify you can fetch the new version from the latest Test App with `make spm|cocoapods version=VERSION`
11. Announce the release.
    1. Create a new release on GitHub.
        ```shell
        scripts/release-github.sh
        ```
        The script creates a draft release pre-filled with documentation links and the formatted changelog. Edit the draft on GitHub to add the "What's Changed" section via "Generate release notes".
    2. Write a high-level summary of the changelog for the blog.
    3. Post the blog summary on Discord's `#announcement`, with a link to the GitHub release.
12. > **Note:** Before merging, verify that SPM and CocoaPods builds succeed against the new tag.

   Merge `develop` into `main`.
