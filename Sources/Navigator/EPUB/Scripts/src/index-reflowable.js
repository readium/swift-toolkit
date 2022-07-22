//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

// Script used for reflowable resources.

import "./index";

window.readium.isReflowable = true;

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

// Injects Readium CSS stylesheets.
document.addEventListener("DOMContentLoaded", function () {
  function createLink(name) {
    var link = document.createElement("link");
    link.setAttribute("rel", "stylesheet");
    link.setAttribute("type", "text/css");
    link.setAttribute("href", window.readiumCSSBaseURL + name + ".css");
    return link;
  }

  var head = document.getElementsByTagName("head")[0];
  head.appendChild(createLink("ReadiumCSS-after"));
  head.insertBefore(createLink("ReadiumCSS-before"), head.children[0]);
});
