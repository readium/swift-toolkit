# ADR 0001 – Sentence re-segmentation as a `ContentIterator` decorator

## Status

Accepted

## Context

TTS is unusable with PDF and EPUB FXL publications: sentences cut between printed lines, block elements and pages are spoken as broken fragments, and stray page text (page numbers, running headers) is pasted mid-sentence.

The root cause is structural. Each PDF page becomes one single-segment `TextContentElement` whose text keeps a `\n` between printed lines — and `NLTokenizer` breaks sentences at every newline. Each FXL page is a separate resource whose blocks are separate elements, so one sentence commonly spans several `<div>` elements of the same page. Sentence tokenization (`makeTextContentTokenizer`) is a pure per-element function which can never see across element boundaries.

An earlier design stitched sentences only across page *seams*, moving the continuation of a cut sentence onto the previous element. It could not fix mid-resource splits (newlines within a PDF page, sibling FXL blocks), and its terminal-punctuation fast path glued "P A R T O N E"-style display pages to the next sentence.

## Decision

Implement the fix as a `ContentIterator` decorator (`SentenceContentIterator`) wrapping the composite `PublicationContentIterator`, which re-segments the whole stream so that **each returned element holds exactly one sentence**.

* `Tokenizer` is a pure per-element function. Splitting fits there, but re-segmentation cannot: it needs cross-element state (a lookahead window over the neighboring pages), which is exactly what an iterator can hold.
* The wrap point is above the composite iterator, not inside resource iterators, so PDF same-`href` page seams and FXL cross-`href` seams flow through one handler.
* Raw elements are decomposed into **fragments** (a printed line of a PDF page blob, one segment of an FXL block). Page artifacts (`PageArtifactDetector`) and hard breaks (`HardBreakDetector`) become standalone elements; the remaining body fragments are joined into normalized logical text (de-hyphenated word cuts, direct joins for space-less scripts) and tokenized as **regions** — maximal fragment runs between *anchors*.
* Anchors force sentence boundaries at: publication edges, non-text neighbors, hard breaks, paragraph gaps (`\n\n`), seams failing the *bridge test* (the joined tail+head of the two pages re-tokenized; merged only when a sentence token straddles the seam), and caps bounding a region to 4 pages and 200 fragments.
* Every derivation is a pure function of a bounded window of raw elements: forward and backward iteration produce the exact same stream, caches are pure optimizations, and starting mid-publication returns the full sentence containing the start position.
* Emitted sentence elements carry the `sentenceAligned` attribute; `makeTextContentTokenizer` returns them untouched so their on-page locator highlights (e.g. a hyphenated "particu-") survive for decorations.

The decorator is applied automatically by `DefaultContentService`, for fixed-layout publications only (`metadata.layout == .fixed` or conforming to the PDF profile). Reflowable publications don't cut sentences between resources in a way visible to users, and their elements are semantic blocks rather than pages.

## Consequences

* All consumers of the `Content` API (TTS, search, extraction) see per-sentence elements without opting in. TTS speaks one utterance per sentence, with per-part locators for page turns and decorations; `ContentSearchService` reconstructs cross-page sentences in its sliding window and skips page-artifact elements by default (`ignoresPageArtifacts`).
* `element.segments.map(\.text).joined()` always equals the sentence's normalized logical text; the on-page form lives in each segment locator's `highlight`. Search-result locators therefore carry the *logical* form, which may be de-hyphenated relative to the page; navigation relies on the `page=` fragment and per-part locators.
* Known limitations, accepted: multi-*sentence* queries across an FXL resource boundary still fail (the search window flushes at resource boundaries); the activation gate uses the publication-wide layout, ignoring per-spine-item `rendition:layout` overrides in mixed EPUBs; a sentence spanning more than 4 pages is cut at the cap; letter-spaced display text ("P A R T O N E") is spoken as spelled letters — PDF extraction flattens typographic letter-spacing into ordinary spaces, so reconstructing the words would be guesswork, and a confident wrong reconstruction is worse than a spelled-out honest one. The fragment-level spoken-form/on-page-form split leaves room to slot in a normalizer later if this ever matters.
