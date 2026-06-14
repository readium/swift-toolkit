//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

// Base script used by both reflowable and fixed layout resources.

import "./gestures";
import "./keyboard";
import { findFirstVisibleLocator } from "./dom";
import {
  removeProperty,
  scrollLeft,
  scrollRight,
  scrollToId,
  scrollToPosition,
  scrollToLocator,
  setProperty,
  setCSSProperties,
} from "./utils";
import { getDecorations, registerTemplates } from "./decorator";
import { TextRange } from "./vendor/hypothesis/anchoring/text-range";

// GLOSS upstream fix (closes #<PR>): expose TextRange so consumers of
// the new opt-in locations.domStart/domEnd keys (honored by
// rangeFromLocator) can compute them from a live Range. Encoder side
// of the same opt-in contract as the rangeFromLocator decoder.
window.__readiumTextRange = TextRange;

// Public API used by the navigator.
global.readium = {
  // utils
  scrollToId: scrollToId,
  scrollToPosition: scrollToPosition,
  scrollToLocator: scrollToLocator,
  scrollLeft: scrollLeft,
  scrollRight: scrollRight,
  setCSSProperties: setCSSProperties,
  setProperty: setProperty,
  removeProperty: removeProperty,

  // decoration
  registerDecorationTemplates: registerTemplates,
  getDecorations: getDecorations,

  // DOM
  findFirstVisibleLocator: findFirstVisibleLocator,
};
