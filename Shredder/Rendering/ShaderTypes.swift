//
//  ShaderTypes.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import simd

struct ShredderUniforms {
  var mvp: simd_float4x4

  var tearAmount: Float
  var tearWidth: Float
  var tearOffset: Float
  var uvOffset: Float

  var ripSide: Float
  var xDirection: Float

  var tearXAngle: Float
  var tearYAngle: Float
  var tearZAngle: Float
  var tearXOffset: Float

  var shadeColor: SIMD3<Float>
  var shadeAmount: Float

  var whiteThreshold: Float

  var sheetHalfWidth: Float
  var sheetFullWidth: Float
  var sheetHeight: Float
  var zOffset: Float
  var groupY: Float
  var groupRotZ: Float
  var throwProgress: Float
  var throwX: Float
  var throwY: Float
  var throwZ: Float
  var throwRotZ: Float

  var _padding: SIMD3<Float> = .zero
}
