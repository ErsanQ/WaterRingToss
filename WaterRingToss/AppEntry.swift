// AppEntry.swift
import SwiftUI
import SpriteKit

@main
struct WaterRingTossApp: App {
    var body: some Scene {
        WindowGroup {
            GameRootView()
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
        }
    }
}
