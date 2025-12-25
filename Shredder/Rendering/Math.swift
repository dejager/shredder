//
//  Math.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import simd

func radians(_ deg: Float) -> Float {
  deg * .pi / 180
}

func makeTranslation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
  simd_float4x4(
    SIMD4(1, 0, 0, 0),
    SIMD4(0, 1, 0, 0),
    SIMD4(0, 0, 1, 0),
    SIMD4(x, y, z, 1)
  )
}

func makePerspectiveRH(
  fovyRadians fovy: Float,
  aspect: Float,
  nearZ: Float,
  farZ: Float
) -> simd_float4x4 {
  let y = 1 / tan(fovy * 0.5)
  let x = y / aspect
  let z = farZ / (nearZ - farZ)
  return simd_float4x4(
    SIMD4(x, 0, 0, 0),
    SIMD4(0, y, 0, 0),
    SIMD4(0, 0, z, -1),
    SIMD4(0, 0, z * nearZ, 0)
  )
}
