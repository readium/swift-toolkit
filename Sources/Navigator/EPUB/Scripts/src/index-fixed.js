//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

// Script used for fixed layouts resources.

import "./index";

window.readium.isFixedLayout = true;

// Once `index-fixed.js` is being executed, this means that the spread is
// starting to load, so it's the right time to send out the `spreadLoadStarted`
// event.
// If instead we were to send it after the window's "load" event, we'd be
// sending the `spreadLoadStarted` event after all the HTML and external
// resources (stylesheets, images, etc) have been loaded.
webkit.messageHandlers.spreadLoadStarted.postMessage({});
