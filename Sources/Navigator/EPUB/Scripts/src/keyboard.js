//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

window.addEventListener("keydown", (event) => {
  if (event.repeat) {
    return;
  }

  webkit.messageHandlers.pressKey.postMessage({
    type: "keydown",
    code: event.code,
    key: event.key,
    option: event.altKey,
    control: event.ctrlKey,
    shift: event.shiftKey,
    command: event.metaKey,
  });
});

window.addEventListener("keyup", (event) => {
  webkit.messageHandlers.pressKey.postMessage({
    type: "keyup",
    code: event.code,
    key: event.key,
    option: event.altKey,
    control: event.ctrlKey,
    shift: event.shiftKey,
    command: event.metaKey,
  });
});
