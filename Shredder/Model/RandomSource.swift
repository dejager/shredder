//
//  RandomSource.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

struct RandomSource {
  private var generator: any RandomNumberGenerator

  init(generator: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
    self.generator = generator
  }

  mutating func float(in range: ClosedRange<Float>) -> Float {
    let unit = Float.random(in: 0...1, using: &generator)
    return range.lowerBound + (range.upperBound - range.lowerBound) * unit
  }
}
