# Maintaining the Readium Swift toolkit

## Bumping the Minimum iOS Deployment Target

To bump the minimum required iOS version, update these files:

- `README.md`, section "Minimum Requirements"
- `Package.swift`
- `Support/Carthage/project.yml`
- `Support/CocoaPods/*.podspec`

## Releasing a New Version

You are ready to release a new version of the Swift toolkit? Great, follow these steps:

1. Figure out the next version using the [semantic versioning scheme](https://semver.org).
2. Test a migration from the last released version.
    1. Create a **temporary** Git tag for `develop` with the next version tag (e.g. `3.0.1`).
    2. Clone the `swift-toolkit` from the previous version (`main` branch).
    3. Under `TestApp`, initialize it with the next toolkit version:
        ```shell
        make spm version=3.0.1 lcp=...
        ```
    4. Try to run the Test App, adjusting the integration if needed.
    5. Delete the Git tag created previously.
3. Update the localized strings (`make update-locales`).
4. Review the list of supported features in `README.md`.
5. Update the [migration guide](Documentation/Migration%20Guide.md) in case of breaking changes.
6. Issue the new release.
    1. Create a branch with the same name as the future tag, from `develop`.
    2. Bump the version numbers in the `Support/CocoaPods/*.podspec` files.
        * :warning: Don't forget to bump the version numbers of the Readium dependencies as well.
    3. Bump the version numbers in `README.md`, and check the "Minimum Requirements" section.
    4. Bump the version numbers in `TestApp/Sources/Info.plist`.
    5. Close the version in the `CHANGELOG.md`, [for example](https://github.com/readium/swift-toolkit/pull/353/commits/a0714589b3da928dd923ba78f379116715797333#diff-06572a96a58dc510037d5efa622f9bec8519bc1beab13c9f251e97e657a9d4ed).
    6. Create a PR to merge in `develop` and verify the CI workflows.
    7. Release the updated Podspecs:
        ```shell
        cd Support/CocoaPods

        pod repo add readium git@github.com:readium/podspecs.git

        pod repo push readium ReadiumInternal.podspec

        pod repo push readium ReadiumShared.podspec
        
        pod repo push readium ReadiumStreamer.podspec
        pod repo push readium ReadiumNavigator.podspec
        pod repo push readium ReadiumOPDS.podspec
        pod repo push readium ReadiumLCP.podspec
        pod repo push readium ReadiumAdapterGCDWebServer.podspec
        pod repo push readium ReadiumAdapterLCPSQLite.podspec
        ```
    8. Squash and merge the PR.
    9. Tag the new version from `develop`.
        ```shell
        git checkout develop
        git pull
        git tag -a 3.0.1 -m 3.0.1
        git push --tags
        ```
7. Verify you can fetch the new version from the latest Test App with `make spm|carthage|cocoapods version=3.0.1`
8. Announce the release.
    1. Create a new release on GitHub.
    2. Write a high-level summary of the changelog for the blog.
    3. Post the blog summary on Discord's `#announcement`, with a link to the GitHub release.
9. Merge `develop` into `main`.
