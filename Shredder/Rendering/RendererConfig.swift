//
//  RendererConfig.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

struct RendererConfig {
  var fullWidth: Float = 3.0
  var sheetHeight: Float = 2.0
  var tearWidth: Float = 0.4
  var xSegments: Int = 30
  var ySegments: Int = 50
  var leftShadeBase: Float = 0.2
  var rightShadeBase: Float = 0.3

  var planeWidth: Float {
    (fullWidth / 2.0) + (tearWidth / 2.0)
  }
}
