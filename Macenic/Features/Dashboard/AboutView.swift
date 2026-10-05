import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
                    .padding(.top, 24)

                Text("Macenic")
                    .font(.system(size: 18, weight: .bold))

                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.vertical, 12)
                .padding(.horizontal, 24)

            VStack(spacing: 4) {
                Text("Developed by")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("Md Rahadul Islam")
                    .font(.system(size: 13, weight: .semibold))
            }

            Divider()
                .padding(.vertical, 12)
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                linkButton(icon: "envelope", title: "apkrahad@gmail.com", url: "mailto:apkrahad@gmail.com")
                linkButton(icon: "globe", title: "rahadul.com", url: "https://rahadul.com/")
                linkButton(icon: "chevron.left.forwardslash.chevron.right", title: "github.com/0xRahad", url: "https://github.com/0xRahad")
            }
            .padding(.horizontal, 24)

            Divider()
                .padding(.vertical, 12)
                .padding(.horizontal, 24)

            Button {
                if let url = URL(string: "https://www.supportkori.com/apkrahad") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                    Text("Support This Project")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
                .background(.pink.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 4) {
                Text("Open Source - MIT License")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text("Built with Swift & SwiftUI")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
            .padding(.bottom, 16)
        }
        .frame(width: 280, height: 420)
    }

    private func linkButton(icon: String, title: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) {
                NSWorkspace.shared.open(link)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 16)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
