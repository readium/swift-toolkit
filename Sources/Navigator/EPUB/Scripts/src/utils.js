//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

// Catch JS errors to log them in the app.

import { TextQuoteAnchor } from "./vendor/hypothesis/anchoring/types";
import { getCurrentSelection } from "./selection";
import { getCssSelector } from "css-selector-generator";

window.addEventListener(
  "error",
  function (event) {
    webkit.messageHandlers.logError.postMessage({
      message: event.message,
      filename: event.filename,
      line: event.lineno,
    });
  },
  false
);

// Notify native code that the page has loaded.
window.addEventListener(
  "load",
  function () {
    const observer = new ResizeObserver(() => {
      // ResizeObserver runs before paint. Restore the retained content range
      // here rather than presenting a percentage-based page for one frame.
      onViewportWidthChanged();
      onScroll();
    });
    observer.observe(document.body);
  },
  false
);

function onViewportWidthChanged() {
  appendVirtualColumnIfNeeded();
  if (reflowRange && reflowRange.startContainer.isConnected) {
    scrollToRange(reflowRange, false);
  } else {
    snapCurrentPosition();
  }
  reflowGeometry = geometry();
}

/**
 * Having an odd number of columns when displaying two columns per screen causes snapping and page
 * turning issues. To fix this, we insert a blank virtual column at the end of the resource.
 */
function appendVirtualColumnIfNeeded() {
  const id = "readium-virtual-page";
  var virtualCol = document.getElementById(id);
  if (isScrollModeEnabled() || getColumnCountPerScreen() != 2) {
    virtualCol?.remove();
  } else {
    var documentWidth = document.scrollingElement.scrollWidth;
    var pageWidth = window.innerWidth;
    var colCount = documentWidth / pageWidth;
    var hasOddColCount = (Math.round(colCount * 2) / 2) % 1 > 0.1;
    if (hasOddColCount) {
      if (virtualCol) {
        virtualCol.remove();
      } else {
        virtualCol = document.createElement("div");
        virtualCol.setAttribute("id", id);
        virtualCol.style.breakBefore = "column";
        virtualCol.innerHTML = "&#8203;"; // zero-width space
        document.body.appendChild(virtualCol);
      }
    }
  }
}

var lastKnownProgressions;
var ticking = false;

/**
 * First and last progressions in range [0 - 1].
 * Expects an object {first, last}
 */
function notifyProgressions(progressions) {
  // A resize can dispatch scroll before ResizeObserver restores the range.
  // Never adopt that transient page as a new reading position.
  if (reflowGeometry === geometry()) captureReflowLocation();
  webkit.messageHandlers.progressionChanged.postMessage({
    ...progressions,
    locator: reflowLocator,
  });
}

window.addEventListener("scroll", onScroll);
window.addEventListener("resize", () => {
  onViewportWidthChanged();
  onScroll();
});

function onScroll() {
  if (readium.isFixedLayout) {
    return;
  }

  let root = document.scrollingElement;
  if (isScrollModeEnabled() && !isVerticalWritingMode()) {
    const scrollY = window.scrollY;
    const viewportHeight = window.innerHeight;
    const totalContentHeight = root.scrollHeight;
    lastKnownProgressions = {
      first: scrollY / totalContentHeight,
      last: (scrollY + viewportHeight) / totalContentHeight,
    };
  } else {
    let scrollX = window.scrollX;
    const viewportWidth = window.innerWidth;
    const totalContentWidth = root.scrollWidth;

    if (isRTL()) {
      scrollX = Math.abs(scrollX);
    }
    lastKnownProgressions = {
      first: scrollX / totalContentWidth,
      last: (scrollX + viewportWidth) / totalContentWidth,
    };
  }

  // Window is hidden
  if (root.scrollWidth === 0 || root.scrollHeight === 0) {
    return;
  }

  if (!ticking) {
    window.requestAnimationFrame(function () {
      notifyProgressions(lastKnownProgressions);
      ticking = false;
    });
  }
  ticking = true;
}

document.addEventListener(
  "selectionchange",
  debounce(50, function () {
    webkit.messageHandlers.selectionChanged.postMessage(getCurrentSelection());
  })
);

export function getColumnCountPerScreen() {
  return parseInt(
    window
      .getComputedStyle(document.documentElement)
      .getPropertyValue("column-count")
  );
}

export function isScrollModeEnabled() {
  const style = document.documentElement.style;
  return style.getPropertyValue("--USER__view").trim() == "readium-scroll-on";
}

export function isVerticalWritingMode() {
  const writingMode = window
    .getComputedStyle(document.documentElement)
    .getPropertyValue("writing-mode");
  return writingMode.startsWith("vertical");
}

export function isRTL() {
  const style = window.getComputedStyle(document.documentElement);
  return (
    style.getPropertyValue("direction") == "rtl" ||
    style.getPropertyValue("writing-mode") == "vertical-rl"
  );
}

// Scroll to the given TagId in document and snap.
export function scrollToId(id, animated) {
  let element = document.getElementById(id);
  if (!element) {
    return false;
  }

  scrollToRect(element.getBoundingClientRect(), animated);
  return true;
}

// Position must be in the range [0 - 1], 0-100%.
export function scrollToPosition(position, dir, animated) {
  if (position < 0 || position > 1) {
    console.error(
      `Expected a valid progression in scrollToPosition, got ${position}`
    );
    return;
  }

  if (isScrollModeEnabled()) {
    if (!isVerticalWritingMode()) {
      let offset = document.scrollingElement.scrollHeight * position;
      scrollTo({ top: offset, animated });
    } else {
      let offset = document.scrollingElement.scrollWidth * position;
      scrollTo({ left: -offset, animated });
    }
  } else {
    var documentWidth = document.scrollingElement.scrollWidth;
    var factor = dir == "rtl" ? -1 : 1;
    let offset = documentWidth * position * factor;
    scrollTo({ left: snapOffset(offset), animated });
  }
}

// Scrolls to the first occurrence of the given text snippet.
//
// The expected text argument is a Locator object, as defined here:
// https://readium.org/architecture/models/locators/
export function scrollToLocator(locator, animated) {
  let range = rangeFromLocator(locator);
  if (!range) {
    return false;
  }
  const moved = scrollToRange(range, animated);
  if (moved) {
    reflowRange = range;
    reflowLocator = locator;
    // Restoring a locator on the current page may not dispatch a scroll event.
    // Publish the retained anchor even when the scroll offset is unchanged.
    onScroll();
  }
  return moved;
}

function scrollToRange(range, animated) {
  const rect = Array.from(range.getClientRects()).find(
    (rect) => rect.width > 0 && rect.height > 0
  );
  return rect ? scrollToRect(rect, animated) : false;
}

function scrollToRect(rect, animated) {
  if (isScrollModeEnabled()) {
    scrollTo({ top: rect.top + window.scrollY, animated });
  } else {
    scrollTo({ left: snapOffset(rect.left + window.scrollX), animated });
  }

  return true;
}

// Returns false if the page is already at the left-most scroll offset.
export function scrollLeft(dir, animated) {
  var isRTL = dir == "rtl";
  var documentWidth = document.scrollingElement.scrollWidth;
  var pageWidth = window.innerWidth;
  var offset = window.scrollX - pageWidth;
  var minOffset = isRTL ? -(documentWidth - pageWidth) : 0;
  return scrollToOffset(Math.max(offset, minOffset), animated);
}

// Returns false if the page is already scrolled at the right-most scroll
// offset.
export function scrollRight(dir, animated) {
  var isRTL = dir == "rtl";
  var documentWidth = document.scrollingElement.scrollWidth;
  var pageWidth = window.innerWidth;
  var offset = window.scrollX + pageWidth;
  var maxOffset = isRTL ? 0 : documentWidth - pageWidth;
  return scrollToOffset(Math.min(offset, maxOffset), animated);
}

// Scrolls to the given left offset.
// Returns false if the page scroll position is already close enough to the given offset.
function scrollToOffset(offset, animated) {
  var currentOffset = window.scrollX;
  var pageWidth = window.innerWidth;

  // In some case the scrollX cannot reach the position respecting to innerWidth
  var diff = Math.abs(currentOffset - offset) / pageWidth;
  var moved = diff > 0.01;

  if (moved) {
    scrollTo({ left: offset, animated });
  }

  return moved;
}

// Scrolls to the given position.
function scrollTo({ left, top, animated } = {}) {
  document.scrollingElement.scrollTo({
    left,
    top,
    behavior: animated ? "smooth" : "instant",
  });
}

// Snap the offset to the screen width (page width).
function snapOffset(offset) {
  const delta = isRTL() ? -1 : 1;
  const value = offset + delta;
  return value - (value % window.innerWidth);
}

function snapCurrentPosition() {
  if (isScrollModeEnabled()) {
    return;
  }
  var currentOffset = window.scrollX;
  var currentOffsetSnapped = snapOffset(currentOffset + 1);

  document.scrollingElement.scrollLeft = currentOffsetSnapped;
}

// A DOM range survives CSS and viewport reflow without rounding the logical
// position to the beginning of a newly computed page.
let reflowRange = null;

let reflowLocator = null;
let reflowGeometry;

function geometry() {
  return [innerWidth, innerHeight, document.body.scrollWidth, document.body.scrollHeight].join(":");
}

function rangeIsVisible(range) {
  const rect = Array.from(range.getClientRects()).find(r => r.width > 0 && r.height > 0);
  return rect && rect.left >= 0 && rect.top >= 0 && rect.right <= innerWidth && rect.bottom <= innerHeight;
}

function captureReflowLocation() {
  if (readium.isFixedLayout || isScrollModeEnabled() || isVerticalWritingMode() || isRTL()) return;
  if (reflowRange?.startContainer.isConnected && rangeIsVisible(reflowRange)) return;
  reflowRange = null;
  reflowLocator = null;
  const deadline = performance.now() + 20;
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  let node;
  while ((node = walker.nextNode()) && performance.now() < deadline) {
    const parent = node.parentElement;
    if (parent.closest("script,style,noscript,[aria-hidden=true],[id^=r2-decoration-]")) continue;
    const style = getComputedStyle(parent);
    if (style.visibility === "hidden" || style.display === "none" || style.opacity === "0") continue;
    const range = document.createRange();
    range.selectNodeContents(node);
    if (!Array.from(range.getClientRects()).some(r => r.right > 0 && r.left < innerWidth && r.bottom > 0 && r.top < innerHeight)) continue;
    for (const match of node.textContent.matchAll(/\S+/gu)) {
      if (performance.now() >= deadline) return;
      range.setStart(node, match.index);
      range.setEnd(node, match.index + match[0].length);
      if (!rangeIsVisible(range)) continue;
      const quote = TextQuoteAnchor.fromRange(parent, range).toSelector();
      reflowRange = range;
      reflowLocator = {
        href: "#", type: "application/xhtml+xml",
        locations: { cssSelector: getCssSelector(parent) },
        text: { highlight: quote.exact, before: quote.prefix, after: quote.suffix },
      };
      return;
    }
  }
}

export function rangeFromLocator(locator) {
  try {
    let locations = locator.locations;
    let text = locator.text;
    if (text && text.highlight) {
      var root;
      if (locations && locations.cssSelector) {
        root = document.querySelector(locations.cssSelector);
      }
      if (!root) {
        root = document.body;
      }

      let anchor = new TextQuoteAnchor(root, text.highlight, {
        prefix: text.before,
        suffix: text.after,
      });

      return anchor.toRange();
    }

    if (locations) {
      var element = null;

      if (!element && locations.cssSelector) {
        element = document.querySelector(locations.cssSelector);
      }

      if (!element && locations.fragments) {
        for (const htmlId of locations.fragments) {
          element = document.getElementById(htmlId);
          if (element) {
            break;
          }
        }
      }

      if (element) {
        let range = document.createRange();
        range.setStartBefore(element);
        range.setEndAfter(element);
        return range;
      }
    }
  } catch (e) {
    logError(e);
  }

  return null;
}

/// User Settings.

export function setCSSProperties(properties) {
  for (const name in properties) {
    setProperty(name, properties[name]);
  }
}

// For setting user setting.
export function setProperty(key, value) {
  if (value === null) {
    removeProperty(key);
  } else {
    var root = document.documentElement;
    // The `!important` annotation is added with `setProperty()` because if
    // it's part of the `value`, it will be ignored by the Web View.
    root.style.setProperty(key, value, "important");
  }
}

// For removing user setting.
export function removeProperty(key) {
  var root = document.documentElement;

  root.style.removeProperty(key);
}

/// Toolkit

function debounce(delay, func) {
  var timeout;
  return function () {
    var self = this;
    var args = arguments;
    function callback() {
      func.apply(self, args);
      timeout = null;
    }
    clearTimeout(timeout);
    timeout = setTimeout(callback, delay);
  };
}

export function log() {
  var message = Array.prototype.slice.call(arguments).join(" ");
  webkit.messageHandlers.log.postMessage(message);
}

export function logErrorMessage(msg) {
  logError(new Error(msg));
}

export function logError(e) {
  webkit.messageHandlers.logError.postMessage({
    message: e.message,
  });
}
