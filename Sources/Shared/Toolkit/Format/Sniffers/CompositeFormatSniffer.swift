//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public class CompositeFormatSniffer: FormatSniffer {
    private let sniffers: [FormatSniffer]

    public init(_ sniffers: [FormatSniffer]) {
        self.sniffers = sniffers
    }

    public convenience init(_ sniffers: FormatSniffer...) {
        self.init(sniffers)
    }

    public func sniffHints(_ hints: FormatHints) -> Format? {
        sniffers.first { $0.sniffHints(hints) }
    }

    public func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async throws(ReadError) -> Format? {
        try await refine(format: format) { sniffer, format throws(ReadError) -> Format? in
            try await sniffer.sniffBlob(blob, refining: format)
        }
    }

    public func sniffContainer<C: Container>(_ container: C, refining format: Format) async throws(ReadError) -> Format? {
        try await refine(format: format) { sniffer, format throws(ReadError) -> Format? in
            try await sniffer.sniffContainer(container, refining: format)
        }
    }

    private func refine(
        format: Format,
        with sniffing: (FormatSniffer, Format) async throws(ReadError) -> Format?
    ) async throws(ReadError) -> Format? {
        func refine(_ format: Format) async throws(ReadError) -> Format {
            for sniffer in sniffers {
                guard let newFormat = try await sniffing(sniffer, format),
                      newFormat.refines(format)
                else {
                    continue
                }
                return try await refine(newFormat)
            }

            return format
        }

        let newFormat = try await refine(format)
        if newFormat == format {
            return nil
        } else {
            return newFormat
        }
    }
}
