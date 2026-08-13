//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import { findDecorationTarget, handleDecorationClickEvent } from "./decorator";
import { adjustPointToViewport } from "./rect";
import { findNearestInteractiveElement } from "./dom";
import { extractTargetElement } from "./content";

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
    targetElement = adjustTargetElementToViewport(
      extractTargetElement(event.target)
    );
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
 * Adjusts the frame of the given target element to the viewport, for FXL
 * resources laid out in a frame of their own.
 *
 * Only the origin goes through the viewport transform; the size is already in
 * viewport-relative units and does not depend on the frame offset.
 */
function adjustTargetElementToViewport(targetElement) {
  if (!targetElement) {
    return targetElement;
  }

  let frame = targetElement.frame;
  let origin = adjustPointToViewport({ x: frame.x, y: frame.y });
  return {
    ...targetElement,
    frame: { ...frame, x: origin.x, y: origin.y },
  };
}
