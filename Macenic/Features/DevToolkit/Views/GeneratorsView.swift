import SwiftUI

struct GeneratorsView: View {
    let service: DevToolkitService

    @State private var uuidv4 = ""
    @State private var uuidv7 = ""
    @State private var randomString = ""
    @State private var stringLength: Double = 16
    @State private var includeSymbols = false
    @State private var secureToken = ""
    @State private var tokenFormat = "hex"
    @State private var currentTimestampSec = "\(Int(Date().timeIntervalSince1970))"
    @State private var currentTimestampMs = "\(Int(Date().timeIntervalSince1970 * 1000))"
    @State private var timestampInput = ""
    @State private var convertedDateResult = ""

    var body: some View {
        VStack(spacing: 8) {
            // UUID section
            generatorRow(
                title: "UUID v4 (Random)",
                value: uuidv4,
                onGenerate: { uuidv4 = service.generateUUIDv4() }
            )

            generatorRow(
                title: "UUID v7 (RFC 9562 Time-Ordered)",
                value: uuidv7,
                onGenerate: { uuidv7 = service.generateUUIDv7() }
            )

            // Random String
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Random String (\(Int(stringLength)) chars)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("Symbols", isOn: $includeSymbols)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 9))
                }

                HStack(spacing: 6) {
                    Slider(value: $stringLength, in: 8...64, step: 1)
                    Button("Generate") {
                        randomString = service.generateRandomString(length: Int(stringLength), includeSymbols: includeSymbols)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if !randomString.isEmpty {
                    outputField(randomString)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Secure Token
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Secure Token (CryptoKit / SecRandom)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $tokenFormat) {
                        Text("Hex").tag("hex")
                        Text("Base64").tag("base64")
                        Text("URL-Safe").tag("urlSafe")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

                HStack(spacing: 6) {
                    Button("Generate 32-Byte Token") {
                        secureToken = service.generateSecureToken(byteCount: 32, format: tokenFormat)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Spacer()
                }

                if !secureToken.isEmpty {
                    outputField(secureToken)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Unix Timestamp
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Current Epoch Timestamp")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") {
                        currentTimestampSec = "\(Int(Date().timeIntervalSince1970))"
                        currentTimestampMs = "\(Int(Date().timeIntervalSince1970 * 1000))"
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9))
                    .foregroundStyle(.tint)
                }

                HStack(spacing: 8) {
                    timestampBadge(label: "Seconds", value: currentTimestampSec)
                    timestampBadge(label: "Milliseconds", value: currentTimestampMs)
                }

                HStack(spacing: 6) {
                    TextField("Convert timestamp...", text: $timestampInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(4)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Button("Convert") {
                        convertTimestamp()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if !convertedDateResult.isEmpty {
                    Text(convertedDateResult)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .onAppear {
            if uuidv4.isEmpty { uuidv4 = service.generateUUIDv4() }
            if uuidv7.isEmpty { uuidv7 = service.generateUUIDv7() }
            if randomString.isEmpty { randomString = service.generateRandomString(length: 16) }
            if secureToken.isEmpty { secureToken = service.generateSecureToken(byteCount: 32) }
        }
    }

    private func generatorRow(title: String, value: String, onGenerate: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Generate", action: onGenerate)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            outputField(value)
        }
        .padding(8)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func outputField(_ value: String) -> some View {
        HStack {
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func timestampBadge(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func convertTimestamp() {
        guard let num = Double(timestampInput.trimmingCharacters(in: .whitespaces)) else {
            convertedDateResult = "Invalid number"
            return
        }
        let epochSeconds = num > 9999999999 ? (num / 1000.0) : num
        let date = Date(timeIntervalSince1970: epochSeconds)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.timeZone = .current
        let localStr = formatter.string(from: date)

        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let utcStr = formatter.string(from: date)
        convertedDateResult = "\(localStr) (Local) / \(utcStr) (UTC)"
    }
}
