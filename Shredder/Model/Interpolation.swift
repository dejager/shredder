//
//  Interpolation.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

extension Duration {
  var seconds: Double {
    let parts = components
    return Double(parts.seconds) + Double(parts.attoseconds) / 1_000_000_000_000_000_000
  }
}

func clamp(_ value: Float, min minValue: Float, max maxValue: Float) -> Float {
  Swift.min(maxValue, Swift.max(minValue, value))
}

func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
  a + (b - a) * t
}

func easeIn(_ t: Float) -> Float {
  t * t
}

func easeOut(_ t: Float) -> Float {
  1 - (1 - t) * (1 - t)
}

func easeInOut(_ t: Float) -> Float {
  if t < 0.5 { return 2 * t * t }
  let p = -2 * t + 2
  return 1 - (p * p) * 0.5
}
