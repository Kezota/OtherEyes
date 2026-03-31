//
//  TemporalBuffer.swift
//  OtherEyes
//
//  Used by Fly (ghosting).
//

import CoreImage

final class TemporalBuffer: @unchecked Sendable {

    private let capacity: Int
    private var buffer: [CIImage] = []

    init(capacity: Int = 4) {
        self.capacity = capacity
    }

    /// Push a new frame into the buffer (called every captureOutput).
    func push(_ image: CIImage) {
        buffer.append(image)
        if buffer.count > capacity {
            buffer.removeFirst()
        }
    }

    /// The most recent frame (current).
    var current: CIImage? { buffer.last }

    /// The frame before the current one.
    var previous: CIImage? {
        guard buffer.count >= 2 else { return nil }
        return buffer[buffer.count - 2]
    }

    /// Returns the last `n` frames (newest first), up to available count.
    func lastFrames(_ n: Int) -> [CIImage] {
        let count = min(n, buffer.count)
        return Array(buffer.suffix(count).reversed())
    }

    /// Clear all stored frames (e.g. on animal switch).
    func clear() {
        buffer.removeAll()
    }
}
