//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

// Manages a fixed layout resource embedded in an iframe.
export function FixedPage(iframeId) {
  // Fixed dimensions for the page, extracted from the viewport meta tag.
  var _pageSize = null;
  // Available viewport size to fill with the resource.
  var _viewportSize = null;
  // Margins that should not overlap the content.
  var _safeAreaInsets = null;

  // iFrame containing the page.
  var _iframe = document.getElementById(iframeId);
  _iframe.addEventListener("load", loadPageSize);

  // Viewport element containing the iFrame.
  var _viewport = _iframe.closest(".viewport");

  // Parses the page size from the viewport meta tag of the loaded resource.
  function loadPageSize() {
    var viewport = _iframe.contentWindow.document.querySelector(
      "meta[name=viewport]"
    );
    if (!viewport) {
      return;
    }
    var regex = /(\w+) *= *([^\s,]+)/g;
    var properties = {};
    var match;
    while ((match = regex.exec(viewport.content))) {
      properties[match[1]] = match[2];
    }
    var width = Number.parseFloat(properties.width);
    var height = Number.parseFloat(properties.height);
    if (width && height) {
      _pageSize = { width: width, height: height };
      layoutPage();
    }
  }

  // Layouts the page iframe to center its content and scale it to fill the available viewport.
  function layoutPage() {
    if (!_pageSize || !_viewportSize || !_safeAreaInsets) {
      return;
    }

    _iframe.style.width = _pageSize.width + "px";
    _iframe.style.height = _pageSize.height + "px";
    _iframe.style.marginTop =
      _safeAreaInsets.top - _safeAreaInsets.bottom + "px";

    // Calculates the zoom scale required to fit the content to the viewport.
    var widthRatio = _viewportSize.width / _pageSize.width;
    var heightRatio = _viewportSize.height / _pageSize.height;
    var scale = Math.min(widthRatio, heightRatio);

    // Sets the viewport of the wrapper page (this page) to scale the iframe.
    var viewport = document.querySelector("meta[name=viewport]");
    viewport.content = "initial-scale=" + scale + ", minimum-scale=" + scale;
  }

  return {
    // Returns whether the page is currently loading its contents.
    isLoading: false,

    // Link object for the resource currently loaded in the page.
    link: null,

    // Loads the given resource ({link, url}) in the page.
    load: function (resource, completion) {
      if (!resource.link || !resource.url) {
        if (completion) {
          completion();
        }
        return;
      }

      var page = this;
      page.link = resource.link;
      page.isLoading = true;

      function loaded() {
        _iframe.removeEventListener("load", loaded);

        // Timeout to wait for the page to be laid out.
        // Note that using `requestAnimationFrame()` instead causes performance
        // issues in some FXL EPUBs with spreads.
        setTimeout(function () {
          page.isLoading = false;
          _iframe.contentWindow.eval(
            `readium.link = ${JSON.stringify(resource.link)};`
          );
          if (completion) {
            completion();
          }
        }, 100);
      }

      _iframe.addEventListener("load", loaded);
      _iframe.src = resource.url;
    },

    // Resets the page and empty its contents.
    reset: function () {
      if (!this.link) {
        return;
      }
      this.link = null;
      _pageSize = null;
      _iframe.src = "about:blank";
    },

    // Evaluates a script in the context of the page.
    eval: function (script) {
      if (!this.link || this.isLoading) {
        return;
      }
      return _iframe.contentWindow.eval(script);
    },

    // Updates the available viewport to display the resource.
    setViewport: function (viewportSize, safeAreaInsets) {
      _viewportSize = viewportSize;
      _safeAreaInsets = safeAreaInsets;
      layoutPage();
    },

    // Shows the page's viewport.
    show: function () {
      _viewport.style.display = "block";
    },

    // Hides the page's viewport.
    hide: function () {
      _viewport.style.display = "none";
    },
  };
}
