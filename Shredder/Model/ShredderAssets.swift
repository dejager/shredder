//
//  ShredderAssets.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

struct ShredderAssets {
  var photos: [String] = ["banana", "mango"]
  var ripName: String = "rip"

  var textureNames: [String] {
    photos + [ripName]
  }
}
