// Views/GameOverView.swift
import SwiftUI

struct GameOverView: View {
    @ObservedObject var model: GameModel
    let scene: GameScene

    private var trophy: String {
        switch model.onPegCount {
        case 6:    return "🏆"
        case 4...5: return "🥇"
        case 2...3: return "🥈"
        default:   return "💧"
        }
    }
    private var title: String {
        switch model.onPegCount {
        case 6:    return "أسطوري!"
        case 4...5: return "ممتاز!"
        case 2...3: return "جيد"
        default:   return "حاول مجدداً"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()

            VStack(spacing: 22) {
                Text(trophy).font(.system(size: 52))

                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 1, green: 0.84, blue: 0))

                // Scores
                VStack(spacing: 10) {
                    ScoreRow(label: "النتيجة",  value: "\(model.score) نقطة")
                    ScoreRow(label: "الحلقات",  value: "\(model.onPegCount) / \(model.totalRings)")
                }
                .padding(16)
                .background(Color.white.opacity(0.07))
                .cornerRadius(16)

                // Restart
                Button {
                    model.reset()
                    scene.resetScene()
                } label: {
                    Text("العب مجدداً 🔄")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 42)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.48, green: 0.36, blue: 0.94),
                                    Color(red: 1, green: 0.30, blue: 0.43)
                                ],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .cornerRadius(30)
                            .shadow(color: Color(red: 0.48, green: 0.36, blue: 0.94).opacity(0.5),
                                    radius: 16)
                        )
                }
                .buttonStyle(BounceButtonStyle())
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.07, green: 0.07, blue: 0.16))
                    .overlay(RoundedRectangle(cornerRadius: 28)
                        .stroke(Color(red: 0.48, green: 0.36, blue: 0.94).opacity(0.55),
                                lineWidth: 1.5))
                    .shadow(color: Color(red: 0.48, green: 0.36, blue: 0.94).opacity(0.38),
                            radius: 30)
            )
            .padding(24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.88)))
        .animation(.spring(response: 0.38), value: model.isGameOver)
    }
}

// MARK: - Helpers
struct ScoreRow: View {
    let label: String, value: String
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.55))
                .font(.system(size: 13))
            Spacer()
            Text(value)
                .foregroundColor(Color(red: 1, green: 0.84, blue: 0))
                .font(.system(size: 14, weight: .bold))
        }
    }
}

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5),
                       value: configuration.isPressed)
    }
}
