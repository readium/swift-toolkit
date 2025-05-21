//
//  Copyright 2025 Readium Foundation. All rights reserved.
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

    public func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async -> ReadResult<Format?> {
        await refine(format: format) { sniffer, format in
            await sniffer.sniffBlob(blob, refining: format)
        }
    }

    public func sniffContainer<C: Container>(_ container: C, refining format: Format) async -> ReadResult<Format?> {
        await refine(format: format) { sniffer, format in
            await sniffer.sniffContainer(container, refining: format)
        }
    }

    private func refine(
        format: Format,
        with sniffing: (FormatSniffer, Format) async -> ReadResult<Format?>
    ) async -> ReadResult<Format?> {
        func refine(_ format: Format) async -> ReadResult<Format> {
            for sniffer in sniffers {
                let result = await sniffing(sniffer, format)
                switch result {
                case let .success(newFormat):
                    guard let newFormat = newFormat, newFormat.refines(format) else {
                        continue
                    }
                    return await refine(newFormat)

                case let .failure(error):
                    return .failure(error)
                }
            }

            return .success(format)
        }

        return await refine(format)
            .map { newFormat in
                if newFormat == format {
                    return nil
                } else {
                    return newFormat
                }
            }
    }
}
