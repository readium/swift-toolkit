//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

// Script used for the single spread wrapper HTML page for fixed layout resources.

import { FixedPage } from "./fixed-page";

var page = FixedPage("page");

// Public API called from Swift.
global.spread = {
  // Loads resources in the spread.
  load: function (resources) {
    if (resources.length === 0) {
      return;
    }
    page.load(resources[0], function loaded() {
      webkit.messageHandlers.spreadLoaded.postMessage({});
    });
  },

  // Evaluates a JavaScript in the context of a resource.
  eval: function (href, script) {
    if (href === "#" || href === "" || page.link?.href === href) {
      return page.eval(script);
    }
  },

  // Updates the available viewport to display the resources.
  setViewport: function (viewportSize, safeAreaInsets) {
    page.setViewport(viewportSize, safeAreaInsets);
  },
};
