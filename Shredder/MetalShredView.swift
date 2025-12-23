//
//  MetalShredView.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import SwiftUI
import MetalKit

struct MetalShredView: UIViewRepresentable, Animatable {
  var tearAmount: Float
  var throwProgress: Float
  var throwLeft: ThrowSide
  var throwRight: ThrowSide
  var groupY: Float
  var groupRotZ: Float
  var photoName: String
  var ripName: String

  var animatableData: AnimatablePair<Float, Float> {
    get { AnimatablePair(tearAmount, throwProgress) }
    set {
      tearAmount = newValue.first
      throwProgress = newValue.second
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> MTKView {
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("Metal not supported on this device.")
    }

    let view = MTKView(frame: .zero, device: device)
    view.colorPixelFormat = .bgra8Unorm_srgb
    view.framebufferOnly = true
    view.isOpaque = false
    view.backgroundColor = .clear
    view.clearColor = MTLClearColorMake(0, 0, 0, 0)
    view.isPaused = true
    view.enableSetNeedsDisplay = true
    view.preferredFramesPerSecond = 120

    let renderer = Renderer(mtkView: view)
    context.coordinator.renderer = renderer
    view.delegate = renderer

    _ = renderer?.setTextures(photoName: photoName, ripName: ripName)
    _ = renderer?.setTearAmount(tearAmount)
    _ = renderer?.setThrow(progress: throwProgress, left: throwLeft, right: throwRight)
    _ = renderer?.setGroup(y: groupY, rotZ: groupRotZ)
    view.setNeedsDisplay()

    return view
  }

  func updateUIView(_ uiView: MTKView, context: Context) {
    guard let renderer = context.coordinator.renderer else { return }

    let tearChanged = renderer.setTearAmount(tearAmount)
    let texChanged  = renderer.setTextures(photoName: photoName, ripName: ripName)
    let throwChanged = renderer.setThrow(progress: throwProgress, left: throwLeft, right: throwRight)
    let groupChanged = renderer.setGroup(y: groupY, rotZ: groupRotZ)

    if tearChanged || texChanged || throwChanged || groupChanged || !context.coordinator.hasDrawn {
      uiView.setNeedsDisplay()
      context.coordinator.hasDrawn = true
    }
  }

  final class Coordinator {
    var renderer: Renderer?
    var hasDrawn: Bool = false
  }
}
