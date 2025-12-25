//
//  ShredderModel.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import CoreGraphics
import Observation

@Observable
@MainActor
final class ShredderModel {
  struct IntroState {
    var start: ContinuousClock.Instant
    var rotation: Float
  }

  struct ThrowState {
    var start: ContinuousClock.Instant
    var tearStart: Float
    var tearTarget: Float
    var left: ThrowSide
    var right: ThrowSide
  }

  struct ResetState {
    var start: ContinuousClock.Instant
    var tearStart: Float
  }

  enum Phase {
    case intro(IntroState)
    case idle
    case dragging
    case throwing(ThrowState)
    case resetting(ResetState)

    var isAnimating: Bool {
      switch self {
      case .intro, .throwing, .resetting:
        return true
      case .idle, .dragging:
        return false
      }
    }
  }

  private let config: ShredderConfig
  private let assets: ShredderAssets
  private let clock = ContinuousClock()
  private var random: RandomSource

  private(set) var phase: Phase = .idle
  private(set) var renderState: RenderState
  private(set) var photoIndex: Int = 0

  private var tearAmount: Float = 0
  private var throwProgress: Float = 0
  private var throwLeft: ThrowSide = .zero
  private var throwRight: ThrowSide = .zero
  private var groupY: Float = 0
  private var groupRotZ: Float = 0
  private var hasAppeared = false

  var isAnimating: Bool { phase.isAnimating }

  init(
    config: ShredderConfig = .init(),
    assets: ShredderAssets = .init(),
    random: RandomSource = .init()
  ) {
    self.config = config
    self.assets = assets
    self.random = random
    self.renderState = RenderState(
      tearAmount: 0,
      throwProgress: 0,
      throwLeft: .zero,
      throwRight: .zero,
      groupY: 0,
      groupRotZ: 0,
      photoName: assets.photos.first ?? "",
      ripName: assets.ripName
    )
    updateRenderState()
  }

  func onAppear() {
    onAppear(at: clock.now)
  }

  func tick() {
    tick(at: clock.now)
  }

  func dragChanged(translationY: CGFloat) {
    dragChanged(translationY: translationY, at: clock.now)
  }

  func dragEnded() {
    dragEnded(at: clock.now)
  }

  func onAppear(at now: ContinuousClock.Instant) {
    guard !hasAppeared else { return }
    hasAppeared = true
    startIntro(at: now)
    updateRenderState()
  }

  func tick(at now: ContinuousClock.Instant) {
    switch phase {
    case .intro(let intro):
      let progress = introProgress(now: now, start: intro.start)
      let eased = easeInOut(progress)
      groupY = lerp(config.introStartY, 0, eased)
      groupRotZ = lerp(intro.rotation, 0, eased)
      if progress >= 1 {
        finishIntro()
      }

    case .throwing(let throwState):
      let progress = normalizedProgress(now: now, start: throwState.start, duration: config.throwDuration)
      throwProgress = easeIn(progress)
      let tearT = easeOut(progress)
      tearAmount = lerp(throwState.tearStart, throwState.tearTarget, tearT)
      throwLeft = throwState.left
      throwRight = throwState.right
      if progress >= 1 {
        finishThrow(at: now)
      }

    case .resetting(let reset):
      let progress = normalizedProgress(now: now, start: reset.start, duration: config.resetDuration)
      let eased = easeOut(progress)
      tearAmount = lerp(reset.tearStart, 0, eased)
      if progress >= 1 {
        finishReset()
      }

    case .dragging, .idle:
      break
    }

    updateRenderState()
  }

  func dragChanged(translationY: CGFloat, at now: ContinuousClock.Instant) {
    switch phase {
    case .intro, .throwing:
      return
    case .resetting:
      phase = .dragging
    case .idle, .dragging:
      break
    }

    let dy = Float(translationY)
    let normalized = clamp((2.0 * dy / config.dragDistance), min: 0, max: config.maxTear)
    tearAmount = normalized
    phase = .dragging

    if tearAmount >= config.throwStartThreshold {
      startThrow(at: now)
    }

    updateRenderState()
  }

  func dragEnded(at now: ContinuousClock.Instant) {
    switch phase {
    case .intro, .throwing:
      return
    case .idle, .dragging, .resetting:
      break
    }

    if tearAmount >= config.completeThreshold {
      startThrow(at: now)
    } else {
      startReset(at: now)
    }

    updateRenderState()
  }

  var textureNames: [String] {
    assets.textureNames
  }

  private func startThrow(at now: ContinuousClock.Instant) {
    if case .throwing = phase { return }

    let tearTarget = random.float(in: config.throwTearTargetRange)
    let xMagnitude = (2 + random.float(in: 0...3)) * 0.5
    let yMagnitude = -(3 + random.float(in: 0...3))
    let rotMagnitude = (2 + random.float(in: 0...3)) * 0.5

    let left = ThrowSide(x: -xMagnitude, y: yMagnitude, z: 1.0, rotZ: rotMagnitude)
    let right = ThrowSide(x: xMagnitude, y: yMagnitude, z: 1.0, rotZ: -rotMagnitude)

    throwProgress = 0
    throwLeft = left
    throwRight = right

    phase = .throwing(
      ThrowState(
        start: now,
        tearStart: tearAmount,
        tearTarget: tearTarget,
        left: left,
        right: right
      )
    )
  }

  private func finishThrow(at now: ContinuousClock.Instant) {
    if !assets.photos.isEmpty {
      photoIndex = (photoIndex + 1) % assets.photos.count
    }
    tearAmount = 0
    throwProgress = 0
    throwLeft = .zero
    throwRight = .zero
    startIntro(at: now)
  }

  private func startReset(at now: ContinuousClock.Instant) {
    throwProgress = 0
    throwLeft = .zero
    throwRight = .zero
    phase = .resetting(ResetState(start: now, tearStart: tearAmount))
  }

  private func finishReset() {
    tearAmount = 0
    throwProgress = 0
    phase = .idle
  }

  private func startIntro(at now: ContinuousClock.Instant) {
    let rotation = random.float(in: -Float.pi...Float.pi)
    groupY = config.introStartY
    groupRotZ = rotation
    phase = .intro(IntroState(start: now, rotation: rotation))
  }

  private func finishIntro() {
    groupY = 0
    groupRotZ = 0
    phase = .idle
  }

  private func introProgress(now: ContinuousClock.Instant, start: ContinuousClock.Instant) -> Float {
    let elapsed = start.duration(to: now) - config.introDelay
    if elapsed <= .zero { return 0 }
    return normalizedProgress(elapsed: elapsed, duration: config.introDuration)
  }

  private func normalizedProgress(
    now: ContinuousClock.Instant,
    start: ContinuousClock.Instant,
    duration: Duration
  ) -> Float {
    normalizedProgress(elapsed: start.duration(to: now), duration: duration)
  }

  private func normalizedProgress(elapsed: Duration, duration: Duration) -> Float {
    guard duration > .zero else { return 1 }
    let value = Float(elapsed.seconds / duration.seconds)
    return clamp(value, min: 0, max: 1)
  }

  private func updateRenderState() {
    renderState = RenderState(
      tearAmount: tearAmount,
      throwProgress: throwProgress,
      throwLeft: throwLeft,
      throwRight: throwRight,
      groupY: groupY,
      groupRotZ: groupRotZ,
      photoName: currentPhotoName,
      ripName: assets.ripName
    )
  }

  private var currentPhotoName: String {
    guard !assets.photos.isEmpty else { return "" }
    return assets.photos[photoIndex % assets.photos.count]
  }
}
