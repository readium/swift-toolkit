# Contributing to the Readium Swift Toolkit

First and foremost, thanks for your interest! 🙏 We need contributors like you to help bring this project to fruition.

We welcome many kind of contributions such as improving the documentation, submitting bug reports and feature requests, or writing code.

## Writing code

### Setting up the Xcode projects

The Xcode projects (Playground and TestApp) are not committed to this repository, they are generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen). Install it first, then run from the project's root directory:

```sh
make dev
```

This generates both the [Playground](Playground) project, which is used to run the unit tests and try out the toolkit, and the [Test App](TestApp) project.

To enable Readium LCP, provide the liblcp URL given to you by EDRLab:

```sh
make dev lcp=https://.../Package.swift
```

Then, use the `Support/Readium.xcworkspace` workspace for working on the toolkit.

> [!IMPORTANT]
> Run `make dev` again after pulling any change from the repository, as the projects may be out of date.

If you only need one of the two applications, use `make playground` for the Playground, or run `make dev` from the `TestApp` directory for the Test App.

### Coding standard

We use [`SwiftFormat`](https://github.com/nicklockwood/SwiftFormat) to ensure code formatting and avoid bikeshedding.

Before submitting a PR, save yourself some trouble by automatically formatting the code with `make format` from the project's root directory.

### Modifying the EPUB Navigator's JavaScript layer

The EPUB navigator injects a set of JavaScript files into a publication's resources, exposing a JavaScript API to the `WKWebView` under the `readium` global namespace. The JavaScript source code is located under [`Sources/Navigator/EPUB/Scripts`](Sources/Navigator/EPUB/Scripts).

`index-reflowable.js` is the root of the bundle injected in a reflowable EPUB's resources, while `index-fixed.js` is used for a fixed-layout EPUB's resources.

In the case of fixed-layout EPUBs, the publication resources are actually loaded inside an `iframe` in one of [our HTML wrapper pages](Sources/Navigator/EPUB/Assets/) (`fxl-spread-one.html` for single pages, `fxl-spread-two.html` when displaying two pages side-by-side). The matching `index-fixed-wrapper-one.js` and `index-fixed-wrapper-two.js` are injected in the HTML wrappers.

If you make any changes to the JavaScript files, you must regenerate the bundles embedded in the application. First, make sure you have [`corepack` installed](https://pnpm.io/installation#using-corepack). Then, run `make scripts` from the project's root directory.

