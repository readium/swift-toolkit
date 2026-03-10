//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A playback item produced by a ``GuidedAudioSequencer``.
///
/// Covers the **full audio file** - all nodes and segments regardless of
/// where playback starts within it.
public struct GuidedAudioClip {
    /// The full audio clip, covering all segments of the file.
    public let clip: AudioClip

    /// All nodes for this file in playback order.
    ///
    /// Each element corresponds to the segment at the same index in
    /// `clip.segments`.
    public let nodes: [GuidedNavigationNode]
}

/// Translates the linear stream of ``GuidedNavigationNode`` values produced
/// by a ``GuidedNavigationCursor`` into coalesced ``GuidedAudioClip`` values
/// ready for an ``AudioClipPlayer``.
///
/// ## Responsibilities
///
/// - **Clip coalescing** — consecutive nodes that share the same audio file
///   are merged into a single ``GuidedAudioClip`` covering the full file.
/// - **Segment-to-node mapping** — `GuidedAudioClip.nodes[i]` corresponds to
///   `AudioClip.segments[i]`, enabling positional synchronization during
///   playback.
/// - **Role-based skip filtering** — nodes whose role is in ``skippedRoles``
///   are silently discarded when building clips.
@MainActor public final class GuidedAudioSequencer {
    /// Roles whose nodes are silently discarded during clip construction.
    ///
    /// Changing this property takes effect on the next call to ``next()``,
    /// ``previous()``, or ``seek(to:)``.
    public var skippedRoles: Set<ContentRole>

    private let publication: Publication
    private let cursor: GuidedNavigationCursor

    /// Creates a sequencer.
    ///
    /// - Parameters:
    ///   - publication: Used to resolve audio HREFs to ``Link`` objects.
    ///   - cursor: The navigation cursor, owned exclusively by the sequencer.
    ///   - skippedRoles: Roles whose nodes are silently discarded when building
    ///     clips. Defaults to none.
    public init(
        publication: Publication,
        cursor: GuidedNavigationCursor,
        skippedroles: Set<ContentRole> = []
    ) {
        self.publication = publication
        self.cursor = cursor
        skippedRoles = skippedroles
    }

    /// Advances the cursor and returns the next coalesced clip, or `nil` when
    /// the end of the publication is reached.
    ///
    /// All nodes sharing the same audio file are merged into a single
    /// ``GuidedAudioClip``. Playback should start at `segments[0]`.
    public func next() async -> GuidedAudioClip? {
        await buildClip(forward: true)
    }

    /// Retreats the cursor and returns the previous coalesced clip, or `nil`
    /// when the beginning of the publication is reached.
    ///
    /// All nodes sharing the same audio file are merged into a single
    /// ``GuidedAudioClip``. Playback should start at the last segment
    /// (`segments[nodes.count - 1]`).
    public func previous() async -> GuidedAudioClip? {
        await buildClip(forward: false)
    }

    /// Seeks to the given node `indexPath` and returns the clip that contains
    /// it.
    ///
    /// All nodes sharing the same audio file are merged into the returned
    /// ``GuidedAudioClip``. `startIndex` is the index of the node matching
    /// `indexPath` inside `clip.nodes` (and the corresponding `clip.segments`
    /// entry), indicating where the player should begin playback within the
    /// audio clip.
    ///
    /// If the matching node is in ``skippedRoles``, the cursor advances to the
    /// next non-skipped node before building the clip.
    ///
    /// Returns `nil` if `indexPath` could not be located in the cursor.
    public func seek(
        to indexPath: GuidedNavigationNode.IndexPath
    ) async -> (clip: GuidedAudioClip, startIndex: Int)? {
        guard await cursor.seek(to: indexPath) else {
            return nil
        }
        return await buildClipFromSeek()
    }

    /// Seeks to `reference` and returns the clip that contains it.
    ///
    /// All nodes sharing the same audio file are merged into the returned
    /// ``GuidedAudioClip``. `startIndex` is the index of the matching node
    /// inside `clip.nodes` (and the corresponding `clip.segments` entry),
    /// indicating where the player should begin playback within the file.
    ///
    /// Returns `nil` if `reference` could not be resolved to a node.
    public func seek(to reference: any Reference) async -> (clip: GuidedAudioClip, startIndex: Int)? {
        guard await cursor.seek(to: reference) else {
            return nil
        }
        return await buildClipFromSeek()
    }

    /// Builds a full-file clip after the cursor has been seeked.
    ///
    /// On entry the cursor is positioned *before* the target node. The
    /// returned clip covers the entire audio file — scanning backward to
    /// determine `startIndex` (non-skipped nodes before the target) then
    /// forward to collect all non-skipped nodes for the file.
    private func buildClipFromSeek() async -> (clip: GuidedAudioClip, startIndex: Int)? {
        // Consume the target node (cursor advances past it).
        guard let (_, targetRef) = await nextPlayableNode() else {
            return nil
        }

        // Un-consume the target so the backward scan can traverse past it.
        _ = await cursor.previous()

        // Scan backward to count non-skipped same-file nodes before the target.
        var startIndex = 0
        while let (_, ref) = await previousPlayableNode() {
            if targetRef.href.isEquivalentTo(ref.href) {
                startIndex += 1
            } else {
                _ = await cursor.next()
                break
            }
        }

        guard let clip = await buildClip(forward: true) else {
            return nil
        }

        return (
            clip: clip,
            startIndex: startIndex
        )
    }

    /// Builds a clip from the current position, in the requested direction.
    private func buildClip(forward: Bool) async -> GuidedAudioClip? {
        let step = forward ? nextPlayableNode : previousPlayableNode

        guard
            let (firstNode, firstRef) = await step(),
            let link = publication.linkWithHREF(firstRef.href)
        else {
            return nil
        }

        var nodes: [(node: GuidedNavigationNode, segment: AudioClip.Segment)] = [
            (firstNode, segment(from: firstRef)),
        ]

        while let (node, ref) = await step() {
            if firstRef.href.isEquivalentTo(ref.href) {
                nodes.append((node, segment(from: ref)))
            } else {
                // Backtracks as the last node returned by `step()` was not consumed.
                _ = forward ? await cursor.previous() : await cursor.next()
                break
            }
        }

        if !forward {
            nodes.reverse()
        }

        // Apply the same filter + sort + dedup steps as AudioClip.init so that
        // nodes[i] always corresponds to clip.segments[i].
        nodes = AudioClip.normalizeSegments(nodes, extracting: \.segment)

        guard !nodes.isEmpty else {
            return nil
        }

        return GuidedAudioClip(
            clip: AudioClip(link: link, segments: nodes.map(\.segment)),
            nodes: nodes.map(\.node)
        )
    }

    private func nextPlayableNode() async -> (GuidedNavigationNode, AudioReference)? {
        while let node = await cursor.next() {
            if let ref = playableRef(for: node) {
                return (node, ref)
            }
        }
        return nil
    }

    private func previousPlayableNode() async -> (GuidedNavigationNode, AudioReference)? {
        while let node = await cursor.previous() {
            if let ref = playableRef(for: node) {
                return (node, ref)
            }
        }
        return nil
    }

    /// Returns the playable audio reference for the given ``node``, if any.
    ///
    ///
    /// A node is excluded when one of its enclosing roles is in
    /// ``skippedRoles``, or when it has the `sequence` role. Sequence nodes
    /// act as containers: their audio reference is ignored and their children
    /// are processed normally.
    private func playableRef(for node: GuidedNavigationNode) -> AudioReference? {
        guard !node.object.roles.contains(.sequence), !node.enclosingRoles.containsAny(skippedRoles) else {
            return nil
        }

        return node.object.refs?.audio
    }

    private func segment(from ref: AudioReference) -> AudioClip.Segment {
        switch ref.temporal {
        case let .clip(c): return AudioClip.Segment(start: c.start ?? 0, end: c.end)
        case let .position(p): return AudioClip.Segment(start: p.time, end: nil)
        case nil: return AudioClip.Segment(start: 0, end: nil)
        }
    }
}
