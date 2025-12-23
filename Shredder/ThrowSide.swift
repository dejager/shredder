//
//  ThrowSide.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

// MARK: - ThrowSide

struct ThrowSide: Equatable {
  var x: Float
  var y: Float
  var z: Float
  var rotZ: Float

  static let zero = ThrowSide(x: 0, y: 0, z: 0, rotZ: 0)
}
