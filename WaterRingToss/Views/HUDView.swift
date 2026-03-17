// Views/HUDView.swift
import SwiftUI

struct HUDView: View {
    @ObservedObject var model:    GameModel
    @ObservedObject var pressure: PressureEngine

    var body: some View {
        VStack(spacing: 10) {
            // Stats row – score + rings only (no moves)
            HStack(spacing: 0) {
                StatPill(icon: "⭐", label: "نقاط",
                         value: "\(model.score)",
                         color: Color(red: 1, green: 0.84, blue: 0))
                Spacer()
                StatPill(icon: "🎯", label: "حلقات",
                         value: "\(model.onPegCount)/\(model.totalRings)",
                         color: Color(red: 0, green: 0.76, blue: 0.66))
            }

            // Pressure gauge
            PressureGauge(value: pressure.currentPressure)
        }
    }
}

// MARK: - Stat Pill
struct StatPill: View {
    let icon: String, label: String, value: String, color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(icon).font(.system(size: 17))
            Text(value)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.38))
        }
        .frame(minWidth: 72)
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.07))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(color.opacity(0.28), lineWidth: 1))
    }
}

// MARK: - Pressure Gauge
struct PressureGauge: View {
    let value: Double   // 0..1

    private var gaugeColor: Color {
        switch value {
        case 0..<0.35:   return Color(red: 0.48, green: 0.36, blue: 0.94)
        case 0.35..<0.70: return Color(red: 0, green: 0.76, blue: 0.66)
        default:          return Color(red: 1, green: 0.3, blue: 0.43)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("💨").font(.system(size: 13))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(gaugeColor)
                        .frame(width: geo.size.width * CGFloat(value), height: 8)
                        .animation(.linear(duration: 0.04), value: value)
                }
            }
            .frame(height: 8)

            Text(pressureLabel)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 36, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private var pressureLabel: String {
        switch value {
        case 0:          return "—"
        case 0..<0.35:   return "خفيف"
        case 0.35..<0.7: return "متوسط"
        default:          return "قوي!"
        }
    }
}
