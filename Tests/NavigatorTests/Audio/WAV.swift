//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Generates WAV audio files, to play real audio without bundling fixtures.
enum WAV {
    /// Returns a silent mono 16-bit PCM WAV file of the given `duration` in
    /// seconds.
    static func silence(duration: Double, sampleRate: UInt32 = 8000) -> Data {
        let bytesPerSample: UInt32 = 2
        let dataSize = UInt32(duration * Double(sampleRate)) * bytesPerSample

        var wav = Data()
        wav.append(contentsOf: Array("RIFF".utf8))
        wav.append(littleEndian: 36 + dataSize)
        wav.append(contentsOf: Array("WAVE".utf8))

        wav.append(contentsOf: Array("fmt ".utf8))
        wav.append(littleEndian: UInt32(16)) // Chunk size
        wav.append(littleEndian: UInt16(1)) // PCM
        wav.append(littleEndian: UInt16(1)) // Mono
        wav.append(littleEndian: sampleRate)
        wav.append(littleEndian: sampleRate * bytesPerSample) // Byte rate
        wav.append(littleEndian: UInt16(bytesPerSample)) // Block align
        wav.append(littleEndian: UInt16(bytesPerSample * 8)) // Bits per sample

        wav.append(contentsOf: Array("data".utf8))
        wav.append(littleEndian: dataSize)
        wav.append(Data(count: Int(dataSize)))
        return wav
    }
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
