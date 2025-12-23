//
//  ShredderView.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import SwiftUI

// MARK: - ShredderView

struct ShredderView: View {
  @State private var tearAmount: Float = 0
  @State private var index: Int = 0
  @State private var throwLeft: ThrowSide = .zero
  @State private var throwRight: ThrowSide = .zero
  @State private var isThrowing: Bool = false
  @State private var throwStartTime: Date?
  @State private var throwTearStart: Float = 0
  @State private var throwTearTarget: Float = 0
  @State private var isIntro: Bool = true
  @State private var introStartTime: Date?
  @State private var introRotStart: Float = 0
  @State private var isResetting: Bool = false
  @State private var resetStartTime: Date?
  @State private var resetTearStart: Float = 0
  @State private var timelineNow: Date = .now
  @State private var hasAppeared: Bool = false

  private let completeThreshold: Float = 1.10
  private let maxTear: Float = 2.0
  private let throwDuration: TimeInterval = 0.7
  private let resetDuration: TimeInterval = 0.2
  private let dragDistance: Float = 400.0
  private let introDelay: TimeInterval = 0.1
  private let introDuration: TimeInterval = 1.1
  private let introStartY: Float = 10.0

  private let photos: [String] = ["banana", "mango"]

  var body: some View {
    content(now: timelineNow)
      .overlay {
        if isThrowing || isResetting || isIntro {
          TimelineView(.animation) { timeline in
            Color.clear
              .onAppear {
                timelineNow = timeline.date
              }
              .onChange(of: timeline.date) { _, newValue in
                timelineNow = newValue
              }
          }
          .allowsHitTesting(false)
        }
      }
      .onAppear {
        if !hasAppeared {
          hasAppeared = true
          startIntro()
        }
      }
  }

  @ViewBuilder private func content(now: Date) -> some View {
    let throwProgress = throwProgress(at: now)
    let throwT = isThrowing ? easeIn(throwProgress) : 0
    let tearT = isThrowing ? easeOut(throwProgress) : 0
    let throwTear = isThrowing ? lerp(throwTearStart, throwTearTarget, tearT) : tearAmount
    let resetProgress = resetProgress(at: now)
    let resetT = isResetting ? easeOut(resetProgress) : 0
    let displayTear = isResetting ? lerp(resetTearStart, 0, resetT) : throwTear
    let done = isThrowing && throwProgress >= 1.0
    let resetDone = isResetting && resetProgress >= 1.0
    let introProgress = introProgress(at: now)
    let introT = isIntro ? easeInOut(introProgress) : 1
    let introY = isIntro ? lerp(introStartY, 0, introT) : 0
    let introRot = isIntro ? lerp(introRotStart, 0, introT) : 0
    let introDone = isIntro && introProgress >= 1.0

    ZStack {
      Color(photos[index])
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: index)

      MetalShredView(
        tearAmount: displayTear,
        throwProgress: throwT,
        throwLeft: throwLeft,
        throwRight: throwRight,
        groupY: introY,
        groupRotZ: introRot,
        photoName: photos[index],
        ripName: "rip"
      )
      .ignoresSafeArea()
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            guard !isThrowing, !isIntro else { return }
            if isResetting {
              cancelReset()
            }
            let dy = Float(value.translation.height)
            let normalized = max(0, min(maxTear, (2.0 * dy / dragDistance)))
            tearAmount = normalized
            if tearAmount >= 1.5 {
              startThrow()
            }
          }
          .onEnded { _ in
            guard !isThrowing, !isIntro else { return }
            if tearAmount >= completeThreshold {
              startThrow()
            } else {
              startReset()
            }
          }
      )
    }
    .onChange(of: done) { _, finished in
      if finished {
        finishThrow()
      }
    }
    .onChange(of: resetDone) { _, finished in
      if finished {
        finishReset()
      }
    }
    .onChange(of: introDone) { _, finished in
      if finished {
        finishIntro()
      }
    }
  }

  private func startThrow() {
    guard !isThrowing else { return }
    if isResetting {
      cancelReset()
    }
    isThrowing = true
    let now = Date()
    throwStartTime = now
    timelineNow = now
    throwTearStart = tearAmount
    throwTearTarget = 1.5 + Float.random(in: 0...1.5)

    let xMagnitude = (2 + Float.random(in: 0...3)) * 0.5
    let yMagnitude = -(3 + Float.random(in: 0...3))
    let rotMagnitude = (2 + Float.random(in: 0...3)) * 0.5

    throwLeft = ThrowSide(x: -xMagnitude, y: yMagnitude, z: 1.0, rotZ: rotMagnitude)
    throwRight = ThrowSide(x: xMagnitude, y: yMagnitude, z: 1.0, rotZ: -rotMagnitude)
  }

  private func finishThrow() {
    guard isThrowing else { return }
    index = (index + 1) % photos.count
    tearAmount = 0
    throwLeft = .zero
    throwRight = .zero
    throwStartTime = nil
    throwTearStart = 0
    throwTearTarget = 0
    isThrowing = false
    startIntro()
  }

  private func startReset() {
    guard !isResetting else { return }
    isResetting = true
    let now = Date()
    resetStartTime = now
    timelineNow = now
    resetTearStart = tearAmount
  }

  private func finishReset() {
    guard isResetting else { return }
    tearAmount = 0
    resetStartTime = nil
    resetTearStart = 0
    isResetting = false
  }

  private func cancelReset() {
    isResetting = false
    resetStartTime = nil
    resetTearStart = 0
  }

  private func startIntro() {
    isIntro = true
    let now = Date()
    introStartTime = now
    timelineNow = now
    introRotStart = Float.random(in: -Float.pi...Float.pi)
  }

  private func finishIntro() {
    guard isIntro else { return }
    isIntro = false
    introStartTime = nil
    introRotStart = 0
  }

  private func throwProgress(at now: Date?) -> Float {
    guard isThrowing, let start = throwStartTime, let now else { return 0 }
    let elapsed = Float(now.timeIntervalSince(start))
    return min(1, max(0, elapsed / Float(throwDuration)))
  }

  private func resetProgress(at now: Date?) -> Float {
    guard isResetting, let start = resetStartTime, let now else { return 0 }
    let elapsed = Float(now.timeIntervalSince(start))
    return min(1, max(0, elapsed / Float(resetDuration)))
  }

  private func introProgress(at now: Date?) -> Float {
    guard isIntro, let start = introStartTime, let now else { return 0 }
    let elapsed = Float(now.timeIntervalSince(start)) - Float(introDelay)
    if elapsed <= 0 { return 0 }
    return min(1, max(0, elapsed / Float(introDuration)))
  }

  private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
    a + (b - a) * t
  }

  private func easeIn(_ t: Float) -> Float {
    t * t
  }

  private func easeOut(_ t: Float) -> Float {
    1 - (1 - t) * (1 - t)
  }

  private func easeInOut(_ t: Float) -> Float {
    if t < 0.5 { return 2 * t * t }
    return 1 - pow(-2 * t + 2, 2) * 0.5
  }
}
