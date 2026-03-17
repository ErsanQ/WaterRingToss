// Models/GameModel.swift
import SwiftUI
import Combine

final class GameModel: ObservableObject {

    // ── Published state ───────────────────────────────────────────────────────
    @Published var score:       Int  = 0
    @Published var onPegCount:  Int  = 0
    @Published var isGameOver:  Bool = false
    @Published var lastPressure: Double = 0   // 0..1 – shown in HUD gauge

    let totalRings = 6

    // Track pending game-over so we can cancel it if rings fall off
    private var gameOverTask: DispatchWorkItem?

    // ── Actions ───────────────────────────────────────────────────────────────
    func ringScored() {
        onPegCount += 1
        score      += 10
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        if onPegCount >= totalRings { scheduleGameOver() }
    }

    /// Called when a ring is ejected from a peg (flip / strong pump).
    func ringRemoved() {
        onPegCount = max(0, onPegCount - 1)
        // Cancel pending game-over — game continues
        gameOverTask?.cancel()
        gameOverTask = nil
    }

    func reset() {
        gameOverTask?.cancel()
        gameOverTask  = nil
        score         = 0
        onPegCount    = 0
        isGameOver    = false
        lastPressure  = 0
    }

    // ── Private ───────────────────────────────────────────────────────────────
    private func scheduleGameOver() {
        gameOverTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.isGameOver = true
        }
        gameOverTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: task)
    }
}
