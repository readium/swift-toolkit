//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import { findDecorationTarget, handleDecorationClickEvent } from "./decorator";
import { adjustPointToViewport } from "./rect";
import { findNearestInteractiveElement } from "./dom";
import { getCssSelector } from "css-selector-generator";

let isSelecting = false;

window.addEventListener("DOMContentLoaded", function () {
  document.addEventListener("click", onClick, false);
  document.addEventListener("pointerdown", onPointerDown, false);
  document.addEventListener("pointerup", onPointerUp, false);
  document.addEventListener("pointermove", onPointerMove, false);
  document.addEventListener("pointercancel", onPointerCancel, false);

  document.addEventListener("selectionchange", function () {
    isSelecting = !window.getSelection().isCollapsed;
  });
});

function onClick(event) {
  if (!getSelection().isCollapsed) {
    // There's an on-going selection, the tap will dismiss it so we don't forward it.
    return;
  }

  let point = adjustPointToViewport({ x: event.clientX, y: event.clientY });
  let clickEvent = {
    defaultPrevented: event.defaultPrevented,
    x: point.x,
    y: point.y,
    targetElement: event.target.outerHTML,
    interactiveElement: findNearestInteractiveElement(event.target),
  };

  if (handleDecorationClickEvent(event, clickEvent)) {
    return;
  }

  // Send the tap data over the JS bridge even if it's been handled
  // within the webview, so that it can be preserved and used
  // by the WKNavigationDelegate if needed.
  webkit.messageHandlers.tap.postMessage(clickEvent);

  // We don't want to disable the default WebView behavior as it breaks some features without bringing any value.
  // event.stopPropagation();
  // event.preventDefault();
}

function onPointerDown(event) {
  onPointerEvent("down", event);
}

function onPointerUp(event) {
  onPointerEvent("up", event);
}

function onPointerMove(event) {
  onPointerEvent("move", event);
}

function onPointerCancel(event) {
  onPointerEvent("cancel", event);
}

function onPointerEvent(phase, event) {
  // If the user is currently selecting text, we report this event as cancelled to prevent detecting gestures.
  if (isSelecting) {
    phase = "cancel";
  }

  // Looking for the elements is costly, so we avoid doing it on every move event.
  // Skipping interactiveElement for move events is intentional: the Swift-side filter
  // that ignores events on interactive elements is meant to prevent hijacking taps on
  // links and inputs, not drag/scroll gestures, so move events can safely bypass it.
  var interactiveElement;
  var targetElement;
  if (phase != "move") {
    interactiveElement = findNearestInteractiveElement(event.target);
    targetElement = extractTargetElement(event.target);
  }

  let point = adjustPointToViewport({ x: event.clientX, y: event.clientY });
  let pointerEvent = {
    phase: phase,
    defaultPrevented: event.defaultPrevented,
    pointerId: event.pointerId,
    pointerType: event.pointerType,
    x: point.x,
    y: point.y,
    buttons: event.buttons,
    interactiveElement: interactiveElement,
    targetElement: targetElement,
    option: event.altKey,
    control: event.ctrlKey,
    shift: event.shiftKey,
    command: event.metaKey,
  };

  if (findDecorationTarget(event) != null) {
    return;
  }

  // Send the pointer data over the JS bridge even if it's been handled
  // within the webview, so that it can be preserved and used
  // by the WKNavigationDelegate if needed.
  webkit.messageHandlers.pointerEventReceived.postMessage(pointerEvent);

  // We don't want to disable the default WebView behavior as it breaks some features without bringing any value.
  // event.stopPropagation();
  // event.preventDefault();
}

/**
 * Extracts metadata about the target element for gesture handling.
 *
 * Returns an object with the element's bounding rectangle, tag name, source
 * URL, a CSS selector, the href of the document that contains the element,
 * an accessibility label, and a caption. This information is used on the
 * Swift side to build the appropriate `ContentElement`.
 */
function extractTargetElement(element) {
  if (!element || !element.getBoundingClientRect) {
    return null;
  }

  let imageElement = findNearestImageElement(element);
  if (!imageElement) {
    return null;
  }

  let rect = imageElement.getBoundingClientRect();
  // Adjust only the origin through the viewport transform; size is already
  // in viewport-relative units and does not depend on the frame offset.
  let adjustedOrigin = adjustPointToViewport({ x: rect.left, y: rect.top });

  let rawSrc =
    imageElement.getAttribute("src") ||
    imageElement.getAttribute("href") ||
    null;

  // Resolve the raw src/href attribute to an absolute URL using the document's
  // base URI. `getAttribute` returns the literal attribute value (possibly
  // relative), while we need the absolute form so Swift can relativize it
  // against the publication base URL to recover the correct manifest href.
  let src = rawSrc ? new URL(rawSrc, document.baseURI).href : null;

  // `html` is only needed for inline SVGs that have no resolvable `src`.
  let html = src ? null : imageElement.outerHTML;

  return {
    tag: imageElement.tagName.toLowerCase(),
    html: html,
    src: src,
    resourceHref: window.readium?.link?.href ?? null,
    frame: {
      x: adjustedOrigin.x,
      y: adjustedOrigin.y,
      width: rect.width,
      height: rect.height,
    },
    accessibilityLabel: imageElement.getAttribute("aria-label")?.trim() || null,
    caption: extractCaption(imageElement),
    cssSelector: getCssSelector(imageElement),
  };
}

/**
 * Returns a human-readable caption for an image element by checking, in
 * order: the `alt` attribute, the `title` attribute, the text content of the
 * first SVG `<title>` child, the text content of the first SVG `<desc>`
 * child, and the text content of a `<figcaption>` inside a parent `<figure>`.
 * Returns `null` when none of these are present.
 *
 * When `alt` is present — even as an empty string (decorative image) — no
 * other source is consulted, so that an explicit `alt=""` suppresses fallback
 * captions rather than incorrectly propagating them.
 */
function extractCaption(imageElement) {
  if (imageElement.hasAttribute("alt")) {
    const alt = imageElement.getAttribute("alt").trim();
    return alt || null;
  }

  const title = imageElement.getAttribute("title")?.trim();
  if (title) return title;

  const svgTitle = imageElement
    .querySelector(":scope > title")
    ?.textContent.trim();
  if (svgTitle) return svgTitle;

  const svgDesc = imageElement
    .querySelector(":scope > desc")
    ?.textContent.trim();
  if (svgDesc) return svgDesc;

  const figure = imageElement.closest("figure");
  if (figure) {
    const figcaption = figure.querySelector("figcaption")?.textContent.trim();
    if (figcaption) return figcaption;
  }

  return null;
}

/**
 * Walks up the DOM tree from the given element to find the nearest image
 * element (img, svg).
 */
function findNearestImageElement(element) {
  const imageTags = ["img", "svg"];
  let current = element;
  while (current && current !== document.documentElement) {
    if (imageTags.includes(current.tagName.toLowerCase())) {
      return current;
    }
    current = current.parentElement;
  }
  return null;
}
