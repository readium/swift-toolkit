# Contributing to the Readium Swift Toolkit

First and foremost, thanks for your interest! 🙏 We need contributors like you to help bring this project to fruition.

We welcome many kind of contributions such as improving the documentation, submitting bug reports and feature requests, or writing code.

## Writing code

### Coding standard

We use [`SwiftFormat`](https://github.com/nicklockwood/SwiftFormat) to ensure code formatting and avoid bikeshedding.

Before submitting a PR, save yourself some trouble by automatically formatting the code with `make format` from the project's root directory.

### Modifying the EPUB Navigator's JavaScript layer

The EPUB navigator injects a set of JavaScript files into a publication's resources, exposing a JavaScript API to the `WKWebView` under the `readium` global namespace. The JavaScript source code is located under [`Sources/Navigator/EPUB/Scripts`](Sources/Navigator/EPUB/Scripts).

`index-reflowable.js` is the root of the bundle injected in a reflowable EPUB's resources, while `index-fixed.js` is used for a fixed-layout EPUB's resources.

In the case of fixed-layout EPUBs, the publication resources are actually loaded inside an `iframe` in one of [our HTML wrapper pages](Sources/Navigator/EPUB/Assets/) (`fxl-spread-one.html` for single pages, `fxl-spread-two.html` when displaying two pages side-by-side). The matching `index-fixed-wrapper-one.js` and `index-fixed-wrapper-two.js` are injected in the HTML wrappers.

If you make any changes to the JavaScript files, you must regenerate the bundles embedded in the application. First, make sure you have [`corepack` installed](https://pnpm.io/installation#using-corepack). Then, run `make scripts` from the project's root directory.

