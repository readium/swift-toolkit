//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Locator service for audio publications.
final class AudioLocatorService: DefaultLocatorService {
    static func makeFactory() -> (PublicationServiceContext) -> AudioLocatorService {
        { context in AudioLocatorService(publication: context.publication) }
    }

    private actor Cache {
        let readingOrder: [Link]

        /// Duration per reading order index.
        let durations: [Double]

        /// Total duration of the publication.
        let totalDuration: Double?

        init(publication: Publication?) {
            readingOrder = publication?.readingOrder ?? []
            durations = readingOrder.map { $0.duration ?? 0 }
            let total = durations.reduce(0, +)
            totalDuration = (total > 0) ? total : nil
        }

        /// Finds the reading order item containing the time `position` (in seconds), as well as its
        /// start time.
        func readingOrderItemAtPosition(_ position: Double) -> (link: Link, startPosition: Double)? {
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
    }

    private let cache: Cache

    override init(publication: Weak<Publication>) {
        cache = Cache(publication: publication())
        super.init(publication: publication)
    }

    override func locate(progression: Double) async -> Locator? {
        guard let totalDuration = cache.totalDuration else {
            return nil
        }

        let positionInPublication = progression * totalDuration
        guard let (link, resourcePosition) = await cache.readingOrderItemAtPosition(positionInPublication) else {
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
