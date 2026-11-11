import SwiftUI

struct KeyboardCleanerOverlay: View {
    let endDate: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remaining = max(0, Int(endDate.timeIntervalSince(context.date)))

            ZStack {
                Color.black.opacity(0.92)

                VStack(spacing: 24) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 56, weight: .thin))
                        .foregroundStyle(.white.opacity(0.4))

                    Text("Keyboard Cleaning Mode")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("\(remaining)")
                        .font(.system(size: 72, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                        .contentTransition(.numericText())

                    Text("Click anywhere to exit")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .ignoresSafeArea()
    }
}
