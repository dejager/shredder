//
//  UniformBuffer.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import Metal

final class UniformRingBuffer {
  let buffer: MTLBuffer
  let stride: Int

  private let framesInFlight: Int
  private let itemsPerFrame: Int
  private var frameIndex = 0

  init(
    device: MTLDevice,
    elementSize: Int,
    itemsPerFrame: Int,
    framesInFlight: Int = 3
  ) {
    self.stride = UniformRingBuffer.align(elementSize, to: 256)
    self.framesInFlight = framesInFlight
    self.itemsPerFrame = itemsPerFrame

    let length = stride * itemsPerFrame * framesInFlight
    guard let buffer = device.makeBuffer(length: length, options: .storageModeShared) else {
      fatalError("Unable to allocate uniform buffer.")
    }
    self.buffer = buffer
  }

  func nextFrameOffset() -> Int {
    frameIndex = (frameIndex + 1) % framesInFlight
    return frameIndex * stride * itemsPerFrame
  }

  func write<T>(_ value: T, at offset: Int) {
    let pointer = buffer.contents().advanced(by: offset)
    withUnsafeBytes(of: value) { bytes in
      guard let base = bytes.baseAddress else { return }
      pointer.copyMemory(from: base, byteCount: bytes.count)
    }
  }

  private static func align(_ value: Int, to alignment: Int) -> Int {
    (value + alignment - 1) & ~(alignment - 1)
  }
}
