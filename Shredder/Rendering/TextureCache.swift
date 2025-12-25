//
//  TextureCache.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import Foundation
import MetalKit

final class TextureCache {
  private let loader: MTKTextureLoader
  private let options: [MTKTextureLoader.Option: Any]
  private var cache: [String: MTLTexture] = [:]
  private let lock = NSLock()

  init(device: MTLDevice, options: [MTKTextureLoader.Option: Any]) {
    self.loader = MTKTextureLoader(device: device)
    self.options = options
  }

  func texture(named name: String) -> MTLTexture? {
    guard !name.isEmpty else { return nil }

    lock.lock()
    if let cached = cache[name] {
      lock.unlock()
      return cached
    }
    lock.unlock()

    let texture = try? loader.newTexture(name: name, scaleFactor: 1.0, bundle: .main, options: options)
    if let texture {
      lock.lock()
      cache[name] = texture
      lock.unlock()
    }
    return texture
  }

  func prewarm(names: [String], onUpdate: @MainActor @escaping () -> Void) {
    let uniqueNames = Array(Set(names)).filter { !$0.isEmpty }
    guard !uniqueNames.isEmpty else { return }

    Task.detached(priority: .utility) { [weak self] in
      guard let self else { return }
      for name in uniqueNames {
        _ = await self.texture(named: name)
      }
      await MainActor.run {
        onUpdate()
      }
    }
  }
}
