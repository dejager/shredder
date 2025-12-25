//
//  MetalShredView.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import MetalKit
import SwiftUI

struct MetalShredView: UIViewRepresentable {
  let metalContext: MetalContext
  let renderState: RenderState

  func makeCoordinator() -> Coordinator {
    Coordinator(metalContext: metalContext)
  }

  func makeUIView(context: Context) -> MTKView {
    let view = MTKView(frame: .zero, device: context.coordinator.metalContext.device)
    view.colorPixelFormat = context.coordinator.metalContext.pixelFormat
    view.framebufferOnly = true
    view.isOpaque = false
    view.backgroundColor = .clear
    view.clearColor = MTLClearColorMake(0, 0, 0, 0)
    view.isPaused = true
    view.enableSetNeedsDisplay = true
    view.preferredFramesPerSecond = 120

    let renderer = Renderer(context: context.coordinator.metalContext)
    context.coordinator.renderer = renderer
    view.delegate = renderer

    context.coordinator.metalContext.onTexturesUpdated = { [weak view, weak renderer] in
      guard let view, let renderer else { return }
      if renderer.refreshTextures() {
        view.setNeedsDisplay()
      }
    }

    _ = renderer.update(state: renderState)
    view.setNeedsDisplay()

    return view
  }

  func updateUIView(_ uiView: MTKView, context: Context) {
    guard let renderer = context.coordinator.renderer else { return }
    let changed = renderer.update(state: renderState)
    if changed || !context.coordinator.hasDrawn {
      uiView.setNeedsDisplay()
      context.coordinator.hasDrawn = true
    }
  }

  final class Coordinator {
    let metalContext: MetalContext
    var renderer: Renderer?
    var hasDrawn = false

    init(metalContext: MetalContext) {
      self.metalContext = metalContext
    }
  }
}
