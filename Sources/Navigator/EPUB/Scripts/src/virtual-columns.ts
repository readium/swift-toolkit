//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

interface VirtualColumnsLayout {
  /** Scroll width of the document, including the virtual columns. */
  documentWidth: number;
  /** Width of a screen. */
  pageWidth: number;
  /** Number of columns per screen, `NaN` when it can't be read. */
  colCountPerScreen: number;
  /** Number of virtual columns already in the document. */
  virtualColCount: number;
  /** Whether the document is scrolled instead of paginated. */
  scroll: boolean;
}

/**
 * Returns how many blank virtual columns to append (positive) or remove
 * (negative) at the end of a resource, so that its number of columns is a
 * multiple of the number of columns per screen.
 *
 * Each virtual column fills a column on its own, so they are not counted as
 * columns of the resource. A hidden window (zero width) changes nothing.
 */
export function virtualColumnCountChange({
  documentWidth,
  pageWidth,
  colCountPerScreen,
  virtualColCount,
  scroll,
}: VirtualColumnsLayout): number {
  const perScreen = scroll ? 1 : colCountPerScreen || 1;
  if (perScreen > 1 && (documentWidth === 0 || pageWidth === 0)) {
    return 0;
  }

  let missingColCount = 0;
  if (perScreen > 1) {
    const colWidth = pageWidth / perScreen;
    const colCount = Math.max(
      0,
      Math.round(documentWidth / colWidth) - virtualColCount
    );
    missingColCount = (perScreen - (colCount % perScreen)) % perScreen;
  }
  return missingColCount - virtualColCount;
}
