//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/**
 * Tests the number of blank virtual columns filling the last screen of a
 * paginated resource.
 */

import { virtualColumnCountChange } from "../src/virtual-columns";

describe("virtualColumnCountChange", () => {
  it.each([
    // [case, documentWidth, pageWidth, colCountPerScreen, virtualColCount, scroll, expected]
    ["1 per screen, no virtual columns", 3000, 1000, 1, 0, false, 0],
    ["1 per screen removes all", 3000, 1000, 1, 2, false, -2],
    ["scroll mode removes all", 5000, 1000, 3, 1, true, -1],
    ["2 per screen, even", 2000, 1000, 2, 0, false, 0],
    ["2 per screen, odd", 2500, 1000, 2, 0, false, 1],
    ["3 per screen, remainder 0", 1800, 900, 3, 0, false, 0],
    ["3 per screen, remainder 1", 1200, 900, 3, 0, false, 2],
    ["3 per screen, remainder 2", 1500, 900, 3, 0, false, 1],
    ["3 per screen, already filled", 1800, 900, 3, 2, false, 0],
    ["2 per screen, already filled", 3000, 1000, 2, 1, false, 0],
    ["3 to 2 per screen, odd", 3500, 1000, 2, 2, false, -1],
    ["3 to 2 per screen, even", 3000, 1000, 2, 2, false, -2],
    ["hidden window, zero document width", 0, 1000, 3, 1, false, 0],
    ["hidden window, zero page width", 1800, 0, 3, 0, false, 0],
    ["NaN column count", 3000, 1000, NaN, 1, false, -1],
    ["fractional column width", 39333, 1180, 3, 0, false, 2],
    ["fractional column width, filled", 40120, 1180, 3, 2, false, 0],
  ])(
    "%s",
    (
      _,
      documentWidth,
      pageWidth,
      colCountPerScreen,
      virtualColCount,
      scroll,
      expected
    ) => {
      expect(
        virtualColumnCountChange({
          documentWidth,
          pageWidth,
          colCountPerScreen,
          virtualColCount,
          scroll,
        })
      ).toBe(expected);
    }
  );
});
