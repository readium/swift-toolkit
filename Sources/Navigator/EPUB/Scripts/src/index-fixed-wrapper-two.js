//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

// Script used for the single spread wrapper HTML page for fixed layout resources.

import { FixedPage } from "./fixed-page";

var pages = {
  left: FixedPage("page-left"),
  right: FixedPage("page-right"),
  center: FixedPage("page-center"),
};

function forEachPage(callback) {
  for (const position in pages) {
    callback(pages[position]);
  }
}

function getPageWithHref(href) {
  for (const position in pages) {
    var page = pages[position];
    if (page.link?.href === href) {
      return page;
    }
  }
  return null;
}

// Public API called from Swift.
global.spread = {
  // Loads resources in the spread.
  load: function (resources) {
    forEachPage(function (page) {
      page.reset();
      page.hide();
    });

    function loaded() {
      if (
        pages.left.isLoading ||
        pages.right.isLoading ||
        pages.center.isLoading
      ) {
        return;
      }
      webkit.messageHandlers.spreadLoaded.postMessage({});
    }

    for (const i in resources) {
      const resource = resources[i];
      const page = pages[resource.page];
      if (page) {
        page.show();
        page.load(resource, loaded);
      }
    }
  },

  // Evaluates a JavaScript in the context of a resource.
  // If the href is '#' or empty, then the script is executed on all the pages.
  eval: function (href, script) {
    if (href === "#" || href === "") {
      forEachPage(function (page) {
        page.eval(script);
      });
    } else {
      var page = getPageWithHref(href);
      if (page) {
        return page.eval(script);
      }
    }
  },

  // Updates the available viewport to display the resources.
  setViewport: function (viewportSize, safeAreaInsets) {
    viewportSize.width /= 2;

    pages.left.setViewport(viewportSize, {
      top: safeAreaInsets.top,
      right: 0,
      bottom: safeAreaInsets.bottom,
      left: safeAreaInsets.left,
    });

    pages.right.setViewport(viewportSize, {
      top: safeAreaInsets.top,
      right: safeAreaInsets.right,
      bottom: safeAreaInsets.bottom,
      left: 0,
    });

    pages.center.setViewport(viewportSize, {
      top: safeAreaInsets.top,
      right: 0,
      bottom: safeAreaInsets.bottom,
      left: 0,
    });
  },
};
