/******/ (() => { // webpackBootstrap
/******/ 	"use strict";
/******/ 	var __webpack_modules__ = ({

/***/ "./src/fixed-page.js":
/*!***************************!*\
  !*** ./src/fixed-page.js ***!
  \***************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "FixedPage": () => (/* binding */ FixedPage)
/* harmony export */ });
//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//
// Manages a fixed layout resource embedded in an iframe.
function FixedPage(iframeId) {
  // Fixed dimensions for the page, extracted from the viewport meta tag.
  var _pageSize = null; // Available viewport size to fill with the resource.

  var _viewportSize = null; // Margins that should not overlap the content.

  var _safeAreaInsets = null; // iFrame containing the page.

  var _iframe = document.getElementById(iframeId);

  _iframe.addEventListener("load", loadPageSize); // Viewport element containing the iFrame.


  var _viewport = _iframe.closest(".viewport"); // Parses the page size from the viewport meta tag of the loaded resource.


  function loadPageSize() {
    var viewport = _iframe.contentWindow.document.querySelector("meta[name=viewport]");

    if (!viewport) {
      return;
    }

    var regex = /(\w+) *= *([^\s,]+)/g;
    var properties = {};
    var match;

    while (match = regex.exec(viewport.content)) {
      properties[match[1]] = match[2];
    }

    var width = Number.parseFloat(properties.width);
    var height = Number.parseFloat(properties.height);

    if (width && height) {
      _pageSize = {
        width: width,
        height: height
      };
      layoutPage();
    }
  } // Layouts the page iframe to center its content and scale it to fill the available viewport.


  function layoutPage() {
    if (!_pageSize || !_viewportSize || !_safeAreaInsets) {
      return;
    }

    _iframe.style.width = _pageSize.width + "px";
    _iframe.style.height = _pageSize.height + "px";
    _iframe.style.marginTop = _safeAreaInsets.top - _safeAreaInsets.bottom + "px";
    _iframe.style.marginLeft = _safeAreaInsets.left - _safeAreaInsets.right + "px"; // Calculates the zoom scale required to fit the content to the viewport.

    var widthRatio = _viewportSize.width / _pageSize.width;
    var heightRatio = _viewportSize.height / _pageSize.height;
    var scale = Math.min(widthRatio, heightRatio); // Sets the viewport of the wrapper page (this page) to scale the iframe.

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
        _iframe.removeEventListener("load", loaded); // Timeout to wait for the page to be laid out.
        // Note that using `requestAnimationFrame()` instead causes performance
        // issues in some FXL EPUBs with spreads.


        setTimeout(function () {
          page.isLoading = false;

          _iframe.contentWindow.eval("readium.link = ".concat(JSON.stringify(resource.link), ";"));

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
    }
  };
}

/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		var cachedModule = __webpack_module_cache__[moduleId];
/******/ 		if (cachedModule !== undefined) {
/******/ 			return cachedModule.exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		__webpack_modules__[moduleId](module, module.exports, __webpack_require__);
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/define property getters */
/******/ 	(() => {
/******/ 		// define getter functions for harmony exports
/******/ 		__webpack_require__.d = (exports, definition) => {
/******/ 			for(var key in definition) {
/******/ 				if(__webpack_require__.o(definition, key) && !__webpack_require__.o(exports, key)) {
/******/ 					Object.defineProperty(exports, key, { enumerable: true, get: definition[key] });
/******/ 				}
/******/ 			}
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/global */
/******/ 	(() => {
/******/ 		__webpack_require__.g = (function() {
/******/ 			if (typeof globalThis === 'object') return globalThis;
/******/ 			try {
/******/ 				return this || new Function('return this')();
/******/ 			} catch (e) {
/******/ 				if (typeof window === 'object') return window;
/******/ 			}
/******/ 		})();
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/hasOwnProperty shorthand */
/******/ 	(() => {
/******/ 		__webpack_require__.o = (obj, prop) => (Object.prototype.hasOwnProperty.call(obj, prop))
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/make namespace object */
/******/ 	(() => {
/******/ 		// define __esModule on exports
/******/ 		__webpack_require__.r = (exports) => {
/******/ 			if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 				Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 			}
/******/ 			Object.defineProperty(exports, '__esModule', { value: true });
/******/ 		};
/******/ 	})();
/******/ 	
/************************************************************************/
var __webpack_exports__ = {};
// This entry need to be wrapped in an IIFE because it need to be isolated against other modules in the chunk.
(() => {
/*!****************************************!*\
  !*** ./src/index-fixed-wrapper-two.js ***!
  \****************************************/
__webpack_require__.r(__webpack_exports__);
/* harmony import */ var _fixed_page__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./fixed-page */ "./src/fixed-page.js");
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//
// Script used for the single spread wrapper HTML page for fixed layout resources.

var pages = {
  left: (0,_fixed_page__WEBPACK_IMPORTED_MODULE_0__.FixedPage)("page-left"),
  right: (0,_fixed_page__WEBPACK_IMPORTED_MODULE_0__.FixedPage)("page-right"),
  center: (0,_fixed_page__WEBPACK_IMPORTED_MODULE_0__.FixedPage)("page-center")
};

function forEachPage(callback) {
  for (var position in pages) {
    callback(pages[position]);
  }
}

function getPageWithHref(href) {
  for (var position in pages) {
    var _page$link;

    var page = pages[position];

    if (((_page$link = page.link) === null || _page$link === void 0 ? void 0 : _page$link.href) === href) {
      return page;
    }
  }

  return null;
} // Public API called from Swift.


__webpack_require__.g.spread = {
  // Loads resources in the spread.
  load: function (resources) {
    forEachPage(function (page) {
      page.reset();
      page.hide();
    });

    function loaded() {
      if (pages.left.isLoading || pages.right.isLoading || pages.center.isLoading) {
        return;
      }

      webkit.messageHandlers.spreadLoaded.postMessage({});
    }

    for (var i in resources) {
      var resource = resources[i];
      var page = pages[resource.page];

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
      left: safeAreaInsets.left
    });
    pages.right.setViewport(viewportSize, {
      top: safeAreaInsets.top,
      right: safeAreaInsets.right,
      bottom: safeAreaInsets.bottom,
      left: 0
    });
    pages.center.setViewport(viewportSize, {
      top: safeAreaInsets.top,
      right: 0,
      bottom: safeAreaInsets.bottom,
      left: 0
    });
  }
};
})();

/******/ })()
;