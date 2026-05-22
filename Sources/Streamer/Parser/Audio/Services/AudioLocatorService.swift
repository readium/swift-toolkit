//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Locator service for audio publications.
final class AudioLocatorService: DefaultLocatorService {
    static func makeFactory() -> @Sendable (PublicationServiceContext) -> AudioLocatorService {
        { context in AudioLocatorService(publication: context.publication) }
    }

    private let readingOrder: [Link]
    private let durations: [Double]
    private let totalDuration: Double?

    override init(publication: Weak<Publication>) {
        let pub = publication()
        let readingOrder = pub?.readingOrder ?? []
        self.readingOrder = readingOrder
        let durations = readingOrder.map { $0.duration ?? 0 }
        self.durations = durations
        let total = durations.reduce(0, +)
        totalDuration = (total > 0) ? total : nil

        super.init(publication: publication)
    }

    /// Finds the reading order item containing the time `position` (in seconds), as well as its
    /// start time.
    private func readingOrderItemAtPosition(_ position: Double) -> (link: Link, startPosition: Double)? {
        var current: Double = 0
        for (i, duration) in durations.enumerated() {
            let link = readingOrder[i]
            if current ..< current + duration ~= position {
                return (link, startPosition: current)
            }

            current += duration
        }

        if position == totalDuration, let link = readingOrder.last {
            return (link, startPosition: current - (link.duration ?? 0))
        }

        return nil
    }

    override func locate(progression: Double) async -> Locator? {
        guard let totalDuration = totalDuration else {
            return nil
        }

        let positionInPublication = progression * totalDuration
        guard let (link, resourcePosition) = readingOrderItemAtPosition(positionInPublication) else {
            return nil
        }

        let positionInResource = positionInPublication - resourcePosition

        return Locator(
            href: link.url(),
            mediaType: link.mediaType ?? .binary,
            locations: .init(
                fragments: ["t=\(Int(positionInResource))"],
                progression: link.duration.map { duration in
                    if duration == 0 {
                        return 0
                    } else {
                        return positionInResource / duration
                    }
                },
                totalProgression: progression
            )
        )
    }
}
