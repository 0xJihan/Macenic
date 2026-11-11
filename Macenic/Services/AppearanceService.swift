import SwiftUI

@Observable
final class AppearanceService {
    static let shared = AppearanceService()

    var glassOpacity: Double {
        didSet {
            UserDefaults.standard.set(glassOpacity, forKey: "glassOpacity")
        }
    }

    init() {
        let saved = UserDefaults.standard.double(forKey: "glassOpacity")
        // Default to 0.75 (75% glass intensity) if not set
        self.glassOpacity = (saved == 0 && UserDefaults.standard.object(forKey: "glassOpacity") == nil) ? 0.75 : saved
    }
}

struct GlassmorphicBackground: ViewModifier {
    var opacity: Double
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(max(0.2, opacity))

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14 * opacity),
                            Color.white.opacity(0.02 * opacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                    Color.black.opacity(0.22 * (1.0 - opacity))
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.32 * opacity),
                                Color.white.opacity(0.08 * opacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.24 * opacity), radius: 14, x: 0, y: 7)
    }
}

extension View {
    func glassmorphic(opacity: Double = AppearanceService.shared.glassOpacity, cornerRadius: CGFloat = 14) -> some View {
        self.modifier(GlassmorphicBackground(opacity: opacity, cornerRadius: cornerRadius))
    }
}
