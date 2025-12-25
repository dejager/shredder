//
//  ShredderTests.swift
//  ShredderTests
//
//  Created by Nate de Jager on 2025-12-23.
//

import CoreGraphics
import Testing
@testable import Shredder

struct ShredderTests {
  struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
      self.state = seed
    }

    mutating func next() -> UInt64 {
      state = 2862933555777941757 &* state &+ 3037000493
      return state
    }
  }

  @Test func introCompletesToIdle() async throws {
    let config = ShredderConfig()
    var rng = SeededGenerator(seed: 1)
    let model = ShredderModel(config: config, random: RandomSource(generator: rng))
    let clock = ContinuousClock()
    let start = clock.now

    model.onAppear(at: start)
    model.tick(at: start.advanced(by: config.introDelay + config.introDuration + .seconds(0.05)))

    switch model.phase {
    case .idle:
      break
    default:
      #expect(false)
    }

    #expect(model.renderState.groupY == 0)
    #expect(model.renderState.groupRotZ == 0)
  }

  @Test func resetFinishesToIdle() async throws {
    let config = ShredderConfig()
    var rng = SeededGenerator(seed: 2)
    let model = ShredderModel(config: config, random: RandomSource(generator: rng))
    let clock = ContinuousClock()
    let start = clock.now

    model.dragChanged(translationY: 60, at: start)
    model.dragEnded(at: start)

    switch model.phase {
    case .resetting:
      break
    default:
      #expect(false)
    }

    model.tick(at: start.advanced(by: config.resetDuration + .seconds(0.05)))

    switch model.phase {
    case .idle:
      break
    default:
      #expect(false)
    }

    #expect(model.renderState.tearAmount == 0)
  }

  @Test func throwAdvancesPhoto() async throws {
    let config = ShredderConfig()
    var rng = SeededGenerator(seed: 3)
    let model = ShredderModel(config: config, random: RandomSource(generator: rng))
    let clock = ContinuousClock()
    let start = clock.now

    model.dragChanged(translationY: CGFloat(config.dragDistance), at: start)
    model.dragEnded(at: start)

    switch model.phase {
    case .throwing:
      break
    default:
      #expect(false)
    }

    model.tick(at: start.advanced(by: config.throwDuration + .seconds(0.05)))

    #expect(model.photoIndex == 1)
  }
}
