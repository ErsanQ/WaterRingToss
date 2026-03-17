// Views/GameRootView.swift
import SwiftUI
import SpriteKit

struct GameRootView: View {

    @StateObject private var model    = GameModel()
    @StateObject private var pressure = PressureEngine()
    @State       private var scene:   GameScene? = nil

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.13).ignoresSafeArea()

            VStack(spacing: 0) {

                // ── HUD ───────────────────────────────────────────────────────
                HUDView(model: model, pressure: pressure)
                    .padding(.top, 58)
                    .padding(.horizontal, 18)

                // ── Water chamber ─────────────────────────────────────────────
                if let scene {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .frame(maxWidth: .infinity)
                        .frame(height: chamberHeight)
                        .cornerRadius(22)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                } else {
                    Spacer().frame(height: chamberHeight + 14)
                }

                Spacer()

                // ── Buttons ───────────────────────────────────────────────────
                if let scene {
                    PumpButtonsView(model: model, pressure: pressure, scene: scene)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 42)
                }
            }

            // ── Game Over overlay ─────────────────────────────────────────────
            if model.isGameOver, let scene {
                GameOverView(model: model, scene: scene)
            }
        }
        .onAppear { buildScene() }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private var chamberHeight: CGFloat {
        UIScreen.main.bounds.height * 0.50
    }

    private func buildScene() {
        guard scene == nil else { return }
        let s = GameScene(model: model, pressure: pressure)
        s.size = CGSize(
            width:  UIScreen.main.bounds.width - 28,
            height: chamberHeight
        )
        s.scaleMode       = .resizeFill
        s.backgroundColor = .clear
        scene = s
    }
}
