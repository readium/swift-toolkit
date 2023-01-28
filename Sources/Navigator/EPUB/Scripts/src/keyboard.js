//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

window.addEventListener("keydown", (event) => {
  if (blockedForPressKey(event)) {
    return;
  }

  stopScrolling(event);
  sendPressKeyMessage(event, "keydown");
});

window.addEventListener("keyup", (event) => {
  if (blockedForPressKey(event)) {
    return;
  }

  stopScrolling(event);
  sendPressKeyMessage(event, "keyup");
});

function blockedForPressKey(event) {
  if (event.defaultPrevented) {
    return true;
  }

  if (nearestInteractiveElement(document.activeElement) != null) {
    return true;
  }

  return false;
}

function stopScrolling(event) {
  event.stopPropagation();
  event.preventDefault();
}

function sendPressKeyMessage(event, keyType) {
  webkit.messageHandlers.pressKey.postMessage({
    type: keyType,
    code: event.code,
    key: event.key,
    option: event.altKey,
    control: event.ctrlKey,
    shift: event.shiftKey,
    command: event.metaKey,
    repeat: event.repeat,
  });
}

// See. https://github.com/JayPanoz/architecture/tree/touch-handling/misc/touch-handling
function nearestInteractiveElement(element) {
  if (element == null) {
    return null;
  }

  var interactiveTags = [
    "a",
    "audio",
    "button",
    "canvas",
    "details",
    "input",
    "label",
    "option",
    "select",
    "submit",
    "textarea",
    "video",
  ];
  if (interactiveTags.indexOf(element.nodeName.toLowerCase()) !== -1) {
    return element.outerHTML;
  }

  // Checks whether the element is editable by the user.
  if (
    element.hasAttribute("contenteditable") &&
    element.getAttribute("contenteditable").toLowerCase() != "false"
  ) {
    return element.outerHTML;
  }

  // Checks parents recursively because the touch might be for example on an <em> inside a <a>.
  if (element.parentElement) {
    return nearestInteractiveElement(element.parentElement);
  }

  return null;
}
