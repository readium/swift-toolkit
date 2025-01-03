//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

// Script used for reflowable resources.

import "./index";

window.readium.isReflowable = true;

// Once `index-reflowable.js` is being executed, this means that the spread is
// starting to load, so it's the right time to send out the `spreadLoadStarted`
// event. If instead we were to send it after the window's "load" event below is
// received, we'd be sending the `spreadLoadStarted` event after all the
// HTML and external resources (stylesheets, images, etc) have been loaded.
webkit.messageHandlers.spreadLoadStarted.postMessage({});

window.addEventListener("load", function () {
  // Notifies native code that the page is loaded after it is rendered.
  // Waiting for the next animation frame seems to do the trick to make sure the page is fully rendered.
  window.requestAnimationFrame(function () {
    webkit.messageHandlers.spreadLoaded.postMessage({});
  });

  // Setups the `viewport` meta tag to disable zooming.
  let meta = document.createElement("meta");
  meta.setAttribute("name", "viewport");
  meta.setAttribute(
    "content",
    "width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, shrink-to-fit=no"
  );
  document.head.appendChild(meta);
});
