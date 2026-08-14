# Maintaining the Readium Swift toolkit

## Upgrading Third-Party Dependencies

The toolkit uses several dependency managers; each must be updated independently.

### SPM

In `Package.swift`, bump the version for each dependency.

Commit both `Package.swift` and the updated `Package.resolved`.

### CocoaPods

In `Support/CocoaPods/Specs.swift`, update the version for any external `.pod(...)` dependency, then regenerate:

```shell
make podspecs
```

### EPUB Navigator scripts

```shell
cd Sources/Navigator/EPUB/Scripts
pnpm update
make scripts
```

### Build tools

In `BuildTools/Package.swift`, bump the versions, then update the lock:

```shell
swift package update --package-path BuildTools
```

## Bumping the Minimum iOS Deployment Target

To bump the minimum required iOS version, update these files:

- `README.md`, section "Minimum Requirements"
- `Package.swift`
- `Support/CocoaPods/*.podspec` – edit `iosTarget` in `Support/CocoaPods/Specs.swift`, then run `make podspecs` and commit the generated files

## Creating a New Package

A new package is a separately distributable SPM library product. It requires updates to a few places.

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

### 3. `Playground/Support/Playground.xctestplan`

Add the new test target to the test plan, otherwise it will not be run by `make test`. `make playground` copies this file to `Playground/Playground.xctestplan`, which is the one referenced by the scheme, hence the `container:..` paths relative to the `Playground` folder:

```json
{
  "target" : {
    "containerPath" : "container:..",
    "identifier" : "Readium<ModuleName>Tests",
    "name" : "Readium<ModuleName>Tests"
  }
}
```

## Releasing a New Version

You are ready to release a new version of the Swift toolkit? Great, follow these steps:

1. Figure out the next version using the [semantic versioning scheme](https://semver.org). Prerelease versions such as `4.0.0-alpha.1`, `4.0.0-beta.1` or `4.0.0-rc.1` are supported by the release scripts, but a few steps below behave differently for them. They are flagged with **Prerelease**.
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

    1. Creates a branch with the same name as the future tag, from `develop`. The podspecs declare `:tag => s.version` and `pod repo push` lints them by cloning that ref, which does not exist yet at step 7, so the identically-named branch stands in for the tag.
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
    The script pushes the podspecs one by one, in dependency order. If one of them fails, it offers to retry and, if you give up, prints the command to resume the sequence where it stopped (`--start N`).

    > **Warning:** all the podspecs must be pushed **before** merging the PR at step 8. `pod repo push` lints each podspec by cloning `:tag => s.version`, which resolves to the release branch created at step 5, since the tag does not exist yet. Merging the PR deletes that branch, leaving no ref to clone, and every remaining podspec fails to lint.
8. Squash and merge the release PR on GitHub.
9. Tag the new version from `develop`.
    ```shell
    scripts/release-tag.sh
    ```
    The script fast-forwards `develop` to `origin/develop`, extracts the version from the last commit message (the squash-merge of the release PR), then creates the annotated tag and pushes it with an explicit refspec, so that the temporary tag from step 2 is never pushed by mistake.

    It also deletes the local release branch, if it is still around, because it has the same name as the tag and would otherwise make the ref ambiguous. GitHub usually already deleted the remote one on squash-merge.
10. Verify you can fetch the new version from the latest Test App with `make spm|cocoapods version=VERSION`
11. Announce the release.
    1. Create a new release on GitHub.
        ```shell
        scripts/release-github.sh
        ```
        The script creates a draft release pre-filled with documentation links and the formatted changelog. Edit the draft on GitHub to add the "What's Changed" section via "Generate release notes".

        **Prerelease:** the script passes `--prerelease` to `gh release create`, so the release is marked as a prerelease and the last stable release keeps the GitHub "Latest release" badge.

        Publishing the release triggers the `Documentation` workflow, which builds and deploys the API reference to `readium.org/swift-toolkit/VERSION/`.

        **Prerelease:** only the versioned folder is generated and deployed. The `latest` folder and the root redirect keep pointing to the API reference of the last stable release.
    2. Write a high-level summary of the changelog for the blog.
    3. Post the blog summary on Discord's `#announcement`, with a link to the GitHub release.
12. > **Note:** Before merging, verify that SPM and CocoaPods builds succeed against the new tag.

    Merge `develop` into `main`.

    **Prerelease:** skip this step. Prereleases live on `develop` only and `main` stays on the stable line, until `develop` is merged for the final release (e.g. `4.0.0`).
