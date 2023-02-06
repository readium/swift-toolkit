//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import { findNearestInteractiveElement } from "./dom";

window.addEventListener("keydown", (event) => {
  if (shouldIgnoreEvent(event)) {
    return;
  }

  preventDefault(event);
  sendPressKeyMessage(event, "keydown");
});

window.addEventListener("keyup", (event) => {
  if (shouldIgnoreEvent(event)) {
    return;
  }

  preventDefault(event);
  sendPressKeyMessage(event, "keyup");
});

function shouldIgnoreEvent(event) {
  return (
    event.defaultPrevented ||
    findNearestInteractiveElement(document.activeElement) != null
  );
}

// We prevent the default behavior for keyboard events, otherwise the web view
// might scroll.
function preventDefault(event) {
  event.stopPropagation();
  event.preventDefault();
}

function sendPressKeyMessage(event, keyType) {
  if (event.repeat) return;
  webkit.messageHandlers.pressKey.postMessage({
    type: keyType,
    code: event.code,
    // We use a deprecated `keyCode` property, because the value of `event.key`
    // changes depending on which modifier is pressed, while `event.code` shows
    // the key code of the physical keyboard key, ignoring the virtual layout.
    key: String.fromCharCode(event.keyCode),
    option: event.altKey,
    control: event.ctrlKey,
    shift: event.shiftKey,
    command: event.metaKey,
  });
}
