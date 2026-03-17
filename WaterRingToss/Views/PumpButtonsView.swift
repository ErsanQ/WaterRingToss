// Views/PumpButtonsView.swift
import SwiftUI

struct PumpButtonsView: View {
    @ObservedObject var model:    GameModel
    @ObservedObject var pressure: PressureEngine
    let scene: GameScene

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {

                // ── ◀ Left button ─────────────────────────────────────────────
                // Controls.md: left button pushes rings LEFT → right nozzle → goLeft: true
                CircularPressureButton(
                    symbol: "◀",
                    color:  Color(red: 0.48, green: 0.36, blue: 0.94),
                    pressure: pressure
                ) {
                    scene.pump(goLeft: true)   // right nozzle → pushes left ✓
                }
                .accessibilityLabel("نفخ يسار")

                // ── Reset ─────────────────────────────────────────────────────
                ResetButton {
                    model.reset()
                    scene.resetScene()
                }

                // ── ▶ Right button ────────────────────────────────────────────
                // Controls.md: right button pushes rings RIGHT → left nozzle → goLeft: false
                CircularPressureButton(
                    symbol: "▶",
                    color:  Color(red: 1, green: 0.30, blue: 0.43),
                    pressure: pressure
                ) {
                    scene.pump(goLeft: false)   // left nozzle → pushes right ✓
                }
                .accessibilityLabel("نفخ يمين")
            }
        }
    }
}

// MARK: - Circular Pressure Button
struct CircularPressureButton: View {
    let symbol:   String
    let color:    Color
    @ObservedObject var pressure: PressureEngine
    let onRelease: () -> Void

    @State private var isHeld = false

    var body: some View {
        Text(symbol)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 72, height: 72)
            .background(
                Circle()
                    .fill(color.opacity(isHeld ? 0.70 : 1.0))
                    .shadow(color: color.opacity(isHeld ? 0.20 : 0.55),
                            radius: isHeld ? 6 : 16, y: isHeld ? 2 : 6)
            )
            .scaleEffect(isHeld ? 0.92 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.55), value: isHeld)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHeld {
                            isHeld = true
                            pressure.beginPress()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        isHeld = false
                        onRelease()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
            )
    }
}

// MARK: - Reset Button
struct ResetButton: View {
    let action: () -> Void
    @State private var spinning = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { spinning.toggle() }
            action()
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white.opacity(0.75))
                .frame(width: 56, height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.white.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1))
                )
                .rotationEffect(.degrees(spinning ? 360 : 0))
        }
        .buttonStyle(.plain)
    }
}
