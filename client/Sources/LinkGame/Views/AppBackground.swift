import SwiftUI

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.40, green: 0.50, blue: 0.91), location: 0),
                .init(color: Color(red: 0.55, green: 0.40, blue: 0.85), location: 0.4),
                .init(color: Color(red: 0.94, green: 0.58, blue: 0.73), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}
