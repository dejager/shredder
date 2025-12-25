//
//  MetalContext.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import Metal
import MetalKit

final class MetalContext {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue
  let pipelineState: MTLRenderPipelineState
  let mesh: Mesh
  let textureCache: TextureCache
  let config: RendererConfig
  let pixelFormat: MTLPixelFormat

  var onTexturesUpdated: (() -> Void)?

  init?(config: RendererConfig = .init(), pixelFormat: MTLPixelFormat = .bgra8Unorm_srgb) {
    guard let device = MTLCreateSystemDefaultDevice() else { return nil }
    guard let commandQueue = device.makeCommandQueue() else { return nil }
    guard let library = device.makeDefaultLibrary() else { return nil }

    self.device = device
    self.commandQueue = commandQueue
    self.config = config
    self.pixelFormat = pixelFormat

    self.textureCache = TextureCache(
      device: device,
      options: [
        .origin: MTKTextureLoader.Origin.bottomLeft,
        .SRGB: true
      ]
    )

    self.mesh = MeshBuilder.makePlane(
      device: device,
      width: config.planeWidth,
      height: config.sheetHeight,
      xSegments: config.xSegments,
      ySegments: config.ySegments
    )

    do {
      self.pipelineState = try PipelineBuilder.makePipeline(
        device: device,
        library: library,
        pixelFormat: pixelFormat
      )
    } catch {
      return nil
    }
  }

  func prewarmTextures(names: [String]) {
    textureCache.prewarm(names: names) { [weak self] in
      self?.onTexturesUpdated?()
    }
  }
}
