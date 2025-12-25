//
//  ShredderView.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import SwiftUI

struct ShredderView: View {
  @State private var model = ShredderModel()
  @State private var metalContext: MetalContext? = MetalContext()

  var body: some View {
    Group {
      if let metalContext {
        shredderContent(using: metalContext)
      } else {
        Text("Metal is not supported on this device.")
      }
    }
    .onAppear {
      model.onAppear()
      metalContext?.prewarmTextures(names: model.textureNames)
    }
  }

  private func shredderContent(using metalContext: MetalContext) -> some View {
    let renderState = model.renderState

    return ZStack {
      Color(renderState.photoName)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: renderState.photoName)

      MetalShredView(
        metalContext: metalContext,
        renderState: renderState
      )
      .ignoresSafeArea()
      .contentShape(Rectangle())
      .gesture(dragGesture)
    }
    .overlay {
      if model.isAnimating {
        TimelineView(.animation) { timeline in
          Color.clear
            .onAppear {
              model.tick()
            }
            .onChange(of: timeline.date) { _, _ in
              model.tick()
            }
        }
        .allowsHitTesting(false)
      }
    }
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        model.dragChanged(translationY: value.translation.height)
      }
      .onEnded { _ in
        model.dragEnded()
      }
  }
}

#Preview {
  ShredderView()
}
