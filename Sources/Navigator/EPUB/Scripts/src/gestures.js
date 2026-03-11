//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import { findDecorationTarget, handleDecorationClickEvent } from "./decorator";
import { adjustPointToViewport } from "./rect";
import { findNearestInteractiveElement } from "./dom";

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

  let point = adjustPointToViewport({ x: event.clientX, y: event.clientY });
  let pointerEvent = {
    phase: phase,
    defaultPrevented: event.defaultPrevented,
    pointerId: event.pointerId,
    pointerType: event.pointerType,
    x: point.x,
    y: point.y,
    buttons: event.buttons,
    targetElement: event.target.outerHTML,
    interactiveElement: findNearestInteractiveElement(event.target),
    targetElementInfo: extractTargetElementInfo(event.target),
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

/// Extracts metadata about the target element for gesture handling.
///
/// Returns an object with the element's bounding rectangle, tag name, and
/// media source URL if available. This information is used on the Swift side
/// to build a `GestureTarget`.
function extractTargetElementInfo(element) {
  if (!element || !element.getBoundingClientRect) {
    return null;
  }

  let mediaElement = findNearestMediaElement(element);
  if (!mediaElement) {
    return null;
  }

  let rect = mediaElement.getBoundingClientRect();
  let adjustedOrigin = adjustPointToViewport({ x: rect.left, y: rect.top });
  let adjustedEnd = adjustPointToViewport({
    x: rect.left + rect.width,
    y: rect.top + rect.height,
  });

  return {
    tag: mediaElement.tagName.toLowerCase(),
    src: mediaElement.src || mediaElement.getAttribute("href") || null,
    frame: {
      x: adjustedOrigin.x,
      y: adjustedOrigin.y,
      width: adjustedEnd.x - adjustedOrigin.x,
      height: adjustedEnd.y - adjustedOrigin.y,
    },
    outerHTML: mediaElement.outerHTML,
  };
}

/// Walks up the DOM tree from the given element to find the nearest media
/// element (img, svg, video, audio, canvas).
function findNearestMediaElement(element) {
  const mediaTags = ["IMG", "SVG", "VIDEO", "AUDIO", "CANVAS"];
  let current = element;
  while (current && current !== document.documentElement) {
    if (mediaTags.includes(current.tagName)) {
      return current;
    }
    current = current.parentElement;
  }
  return null;
}
