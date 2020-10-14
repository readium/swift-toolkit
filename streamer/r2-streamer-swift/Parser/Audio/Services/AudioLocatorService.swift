//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Locator service for audio publications.
final class AudioLocatorService: LocatorService {
    
    /// Total duration of the publication.
    private let totalDuration: Double?
    
    /// Duration per reading order index.
    private let durations: [Double]
    
    private let readingOrder: [Link]
    
    init(readingOrder: [Link]) {
        self.durations = readingOrder.map { $0.duration ?? 0 }
        let totalDuration = durations.reduce(0, +)
        self.totalDuration = (totalDuration > 0) ? totalDuration : nil
        self.readingOrder = readingOrder
    }
    
    func locate(_ locator: Locator) -> Locator? {
        if readingOrder.firstIndex(withHREF: locator.href) != nil {
            return locator
        }
        
        if let totalProgression = locator.locations.totalProgression, let target = locate(progression: totalProgression) {
            return target.copy(
                title: locator.title,
                text: locator.text
            )
        }
        
        return nil
    }
    
    func locate(progression: Double) -> Locator? {
        guard let totalDuration = totalDuration else {
            return nil
        }
        
        let positionInPublication = progression * totalDuration
        guard let (link, resourcePosition) = readingOrderItemAtPosition(positionInPublication) else {
            return nil
        }
        
        let positionInResource = positionInPublication - resourcePosition
        
        return Locator(
            href: link.href,
            type: link.type ?? MediaType.binary.string,
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
    
    static func makeFactory() -> (PublicationServiceContext) -> AudioLocatorService {
        { context in AudioLocatorService(readingOrder: context.manifest.readingOrder) }
    }
    
    /// Finds the reading order item containing the time `position` (in seconds), as well as its
    /// start time.
    private func readingOrderItemAtPosition(_ position: Double) -> (link: Link, startPosition: Double)? {
        var current: Double = 0
        for (i, duration) in durations.enumerated() {
            let link = readingOrder[i]
            let itemDuration = link.duration ?? 0
            if current..<current+itemDuration ~= position {
                return (link, startPosition: current)
            }
            
            current += itemDuration
        }
        
        if position == totalDuration, let link = readingOrder.last {
            return (link, startPosition: current - (link.duration ?? 0))
        }
    
        return nil
    }
    
}
