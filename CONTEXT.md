# Domain glossary

Terms used throughout the toolkit's code and documentation, in particular for the fixed-layout sentence re-segmentation feature.

* **Seam** – the boundary between two adjacent fixed-layout pages in the content stream. A PDF page boundary is a seam between two `page=` fragments of the same resource; an EPUB FXL page boundary is a seam between two resources.
* **Fragment** – the atomic unit of re-segmentation: a printed line of a PDF page blob, or one segment of a fixed-layout block element. Fragments are classified as body text, page artifacts or hard breaks.
* **Re-segmentation** – decomposing raw fixed-layout elements into fragments, joining them into normalized logical text and emitting one `TextContentElement` per sentence, so that no element starts or ends mid-sentence. See `SentenceContentIterator`.
* **Page Artifact** – page-boundary noise that is not part of the reading flow: a page number, a running header or footer. Detected by `PageArtifactDetector` implementations and emitted as standalone elements marked with the `pageArtifact` content attribute (skipped by TTS and, by default, by search).
* **Hard Break** – standalone display text that is not part of any sentence: a part or chapter heading ("P A R T O N E", "Chapter 1"), a title page line. Detected by `HardBreakDetector` implementations and emitted as its own element; unlike a page artifact it is spoken and searchable, but sentences never merge across it.
* **Region** – a maximal run of body fragments between two anchors, joined into logical text and tokenized into sentences as one unit. A region spans at most 4 pages and 200 fragments.
* **Anchor** – a position forcing a sentence boundary during re-segmentation: a publication edge, a non-text neighbor, a hard break, a paragraph gap, a seam failing the bridge test, or a size cap.
* **Bridge Test** – how a seam is checked for a spanning sentence: the tail of the left page's body is joined with the head of the right page's and re-tokenized; the seam is *bridged* only when a sentence token straddles it.
* **Continuation** – a part of a per-sentence element: a `TextContentElement.Segment` marked with the `continued` attribute, carrying the portion of the sentence found on the next fragment. Its locator targets its own page, so it stays renderable there.
* **Page Identity** – what distinguishes one fixed-layout page from another in the content stream: the resource `href` plus the `page=` locator fragment.
