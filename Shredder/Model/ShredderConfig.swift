//
//  ShredderConfig.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

struct ShredderConfig {
  var completeThreshold: Float = 1.10
  var maxTear: Float = 2.0
  var throwStartThreshold: Float = 1.5
  var dragDistance: Float = 400.0
  var throwTearTargetRange: ClosedRange<Float> = 1.5...3.0
  var introStartY: Float = 10.0

  var throwDuration: Duration = .seconds(0.7)
  var resetDuration: Duration = .seconds(0.2)
  var introDelay: Duration = .seconds(0.1)
  var introDuration: Duration = .seconds(1.1)
}
