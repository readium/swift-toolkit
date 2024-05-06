# Maintaining the Readium Swift toolkit

## Releasing a new version

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
3. Update the [migration guide](Documentation/Migration%20Guide.md) in case of breaking changes.
4. Issue the new release.
    1. Create a branch with the same name as the future tag, from `develop`.
    2. Bump the version numbers in the `Support/CocoaPods/*.podspec` files.
        * :warning: Don't forget to use `:tag` in the `Podspec` files instead of `:branch`, [for example](https://github.com/readium/swift-toolkit/pull/353/commits/a0714589b3da928dd923ba78f379116715797333#diff-b726fa4aff3ea878dedf3e0f78607c09975ef5412966dc1b547d9b5e9e4b0d9cL9).
    3. Bump the version numbers in `README.md`.
    4. Bump the version numbers in `TestApp/Sources/Info.plist`.
    5. Close the version in the `CHANGELOG.md`, [for example](https://github.com/readium/swift-toolkit/pull/353/commits/a0714589b3da928dd923ba78f379116715797333#diff-06572a96a58dc510037d5efa622f9bec8519bc1beab13c9f251e97e657a9d4ed).
    6. Create a PR to merge in `develop` and verify the CI workflows.
    7. Squash and merge the PR.
    8. Tag the new version from `develop`.
        ```shell
        git checkout develop
        git pull
        git tag -a 3.0.1 -m 3.0.1
        git push --tags
        ```
5. Verify you can fetch the new version from the latest Test App with `make spm|carthage|cocoapods version=3.0.1`
7. Announce the release.
    1. Create a new release on GitHub.
    2. Publish a new TestFlight beta with LCP enabled.
        * Click on "External Groups" > "Public Beta", then add the new build so that it's available to everyone.
8. Merge `develop` into `main`.
9. :warning: Revert to `:branch => "develop"` in the `Podspec` files in `develop`.

