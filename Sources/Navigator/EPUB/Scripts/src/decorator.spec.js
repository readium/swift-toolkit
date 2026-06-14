/* eslint-env mocha, node */
const { JSDOM } = require("jsdom");
const fs = require("fs");
const path = require("path");
const assert = require("assert");

describe("rangeFromLocator — Option B-pragmatic decoder", () => {
  let dom;
  let document;
  let window;
  let globalsBefore;

  beforeEach(() => {
    // Path: from Sources/Navigator/EPUB/Scripts/src/ → 5 ups → repo root, then Tests/…
    const html = fs.readFileSync(
      path.join(
        __dirname,
        "../../../../../Tests/NavigatorTests/Fixtures/indexterm-cluster-cross-paragraph.html"
      ),
      "utf-8"
    );
    dom = new JSDOM(html, { runScripts: "outside-only" });
    document = dom.window.document;
    window = dom.window;

    // utils.js + vendor/hypothesis/anchoring/text-range.js use these browser
    // globals. Inject jsdom's so the require chain resolves under Node.
    globalsBefore = {
      document: global.document,
      window: global.window,
      NodeFilter: global.NodeFilter,
      Node: global.Node,
      Range: global.Range,
    };
    global.document = document;
    global.window = window;
    global.NodeFilter = window.NodeFilter;
    global.Node = window.Node;
    global.Range = window.Range;
  });

  afterEach(() => {
    global.document = globalsBefore.document;
    global.window = globalsBefore.window;
    global.NodeFilter = globalsBefore.NodeFilter;
    global.Node = globalsBefore.Node;
    global.Range = globalsBefore.Range;
  });

  it("explicit locations.domStart/domEnd produce a non-collapsed range", () => {
    // The fix is opt-in via locations.domStart/domEnd. The existing
    // TextQuoteAnchor path's behaviour for cross-element selections
    // (collapsed-range degeneracy when text.highlight spans interruptions
    // like indexterm clusters) is intentionally unchanged by this patch —
    // see FINDINGS §9–§10 + the upstream PR body for the mechanism.
    // If a future upstream change makes TextQuoteAnchor reliably handle
    // these cases, this decoder + the Gloss-side encoder can be retired
    // together.

    // Compute the expected DOM positions from the fixture.
    const pSource = document.getElementById("p-source");
    const pTarget = document.getElementById("p-target");
    const sourceText = pSource.firstChild;
    const targetText = [...pTarget.childNodes].find((n) => n.nodeType === 3);

    // Build a range spanning the source paragraph's tail into the target
    // paragraph's text after its leading indexterm anchors. Use
    // TextRange.fromRange's own encoding to compute char offsets — keeps
    // the test stable against subtle DOM-traversal differences between
    // jsdom and the real fix branch's TextRange implementation.
    const targetRange = document.createRange();
    targetRange.setStart(sourceText, sourceText.length - 30);
    targetRange.setEnd(targetText, 30);

    const { TextRange } = require("./vendor/hypothesis/anchoring/text-range");
    const encoded = TextRange.fromRange(targetRange).relativeTo(document.body);

    const locator = {
      locations: {
        domStart: encoded.start.offset,
        domEnd: encoded.end.offset,
      },
      // text fields irrelevant for the explicit-DOM-positions path; the
      // decoder must short-circuit before falling through to TextQuoteAnchor.
      text: {
        before: "anything",
        highlight: "anything",
        after: "anything",
      },
    };

    const expectedText = targetRange.toString();

    const { rangeFromLocator } = require("./utils");
    const range = rangeFromLocator(locator);

    assert.ok(range, "expected a Range, got null");
    assert.ok(!range.collapsed, "expected non-collapsed range");
    // Load-bearing assertion: the decoder must use locations.domStart/domEnd,
    // NOT the bogus text-fields. Pre-patch the TextQuoteAnchor path may
    // accidentally return a non-collapsed range from fuzzy-matching the
    // text fields, but that range will NOT match `targetRange`. Post-patch
    // the explicit-positions path returns exactly `targetRange`.
    assert.strictEqual(
      range.toString(),
      expectedText,
      `expected range text matching the explicit-DOM-positions targetRange (${JSON.stringify(
        expectedText
      )}), got ${JSON.stringify(range.toString())}`
    );
  });
});
