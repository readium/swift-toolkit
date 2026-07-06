# Ubiquitous Language

Glossary of core terms in the Readium Swift toolkit, including the concurrency
contract each one commits to since the Swift 6 migration.

## Publication

An immutable, shareable model of an opened publication (EPUB, PDF, audiobook,
comic). Safe to pass between threads; all mutation happens before it is
published to callers.

## Resource / Streamable

A proxy to an individual data source (file, ZIP entry, HTTP body) supporting
asynchronous ranged reads. Implementations must be safe to call from any
thread and are expected to serialize their own internal state. Streaming reads
are cooperatively cancellable: an implementation should stop producing chunks
promptly when the surrounding task is cancelled.

## Container

A read-only collection of Resources addressed by URL, backing a Publication
(e.g. an exploded directory or a ZIP archive).

## Publication Service

An optional capability attached to a Publication (positions, search, cover,
content protection…). Holds a weak back-reference to its Publication, which is
set exactly once while the Publication is being assembled and never mutated
afterwards.

## Navigator

A user-facing component rendering a Publication and tracking the reading
location. Navigators are UI objects: they live on the main actor, and all
navigator and delegate calls happen there.

## Streamer

The component that parses an Asset into a Publication.
