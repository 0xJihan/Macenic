import SwiftUI
import AppKit

struct GeneratorsView: View {
    let service: DevToolkitService

    @State private var uuidv4 = ""
    @State private var uuidv7 = ""
    @State private var ulid = ""
    @State private var randomString = ""
    @State private var stringLength: Double = 24
    @State private var includeSymbols = false
    @State private var includeDigits = true
    @State private var excludeAmbiguous = false
    @State private var secureToken = ""
    @State private var tokenFormat = "hex"
    @State private var tokenBytes: Double = 32
    @State private var timestampInput = ""
    @State private var convertedDateResult = ""

    var body: some View {
        VStack(spacing: 10) {
            DevCard(title: "Identifiers", icon: "number") {
                VStack(spacing: 7) {
                    generatorRow(
                        title: "UUID v4",
                        subtitle: "Random",
                        value: uuidv4,
                        onGenerate: { uuidv4 = service.generateUUIDv4() }
                    )

                    Divider()
                        .opacity(0.25)

                    generatorRow(
                        title: "UUID v7",
                        subtitle: "Time-ordered",
                        value: uuidv7,
                        onGenerate: { uuidv7 = service.generateUUIDv7() }
                    )

                    Divider()
                        .opacity(0.25)

                    generatorRow(
                        title: "ULID",
                        subtitle: "Sortable",
                        value: ulid,
                        onGenerate: { ulid = service.generateULID() }
                    )
                }
            }

            DevCard(title: "Random String", icon: "textformat.abc") {
                VStack(spacing: 7) {
                    HStack {
                        Text("Length")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                        Slider(value: $stringLength, in: 8...64, step: 1)
                            .tint(.accentColor)
                        Text("\(Int(stringLength))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .frame(width: 22, alignment: .trailing)
                    }

                    HStack(spacing: 10) {
                        Toggle("Digits", isOn: $includeDigits)
                        Toggle("Symbols", isOn: $includeSymbols)
                        Toggle("No 0/O/1/I", isOn: $excludeAmbiguous)
                    }
                    .toggleStyle(.checkbox)
                    .font(.system(size: 9))

                    HStack(spacing: 6) {
                        DevSmallButton(title: "Generate", icon: "arrow.clockwise", prominent: true) {
                            regenerateRandomString()
                        }
                        Spacer()
                        Text("A-Z\(includeDigits ? " · 0-9" : "")\(includeSymbols ? " · symbols" : "")")
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    DevOutputField(text: randomString, lineLimit: 2, truncationMode: .tail)
                }
            }

            DevCard(title: "Secure Token", icon: "key.horizontal") {
                VStack(spacing: 7) {
                    HStack(spacing: 6) {
                        Picker("", selection: $tokenFormat) {
                            Text("Hex").tag("hex")
                            Text("Base64").tag("base64")
                            Text("URL-Safe").tag("urlSafe")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Spacer(minLength: 4)

                        Picker("", selection: $tokenBytes) {
                            Text("16 B").tag(16.0)
                            Text("32 B").tag(32.0)
                            Text("64 B").tag(64.0)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 118)
                    }

                    HStack(spacing: 6) {
                        DevSmallButton(title: "Generate", icon: "arrow.clockwise", prominent: true) {
                            regenerateToken()
                        }
                        Spacer()
                        Text(tokenFormat == "hex" ? "Uppercase hex" : "Case-preserving")
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    DevOutputField(text: secureToken, lineLimit: 2, truncationMode: .middle)
                }
            }

            DevCard(title: "Timestamps", icon: "clock") {
                VStack(spacing: 8) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                timestampBadge(label: "Seconds", value: "\(Int(context.date.timeIntervalSince1970))")
                                timestampBadge(label: "Milliseconds", value: "\(Int(context.date.timeIntervalSince1970 * 1000))")
                            }

                            DevOutputField(text: ISO8601DateFormatter().string(from: context.date), lineLimit: 1, truncationMode: .middle)
                        }
                    }

                    Divider()
                        .opacity(0.25)

                    HStack(spacing: 6) {
                        TextField("Paste epoch seconds or milliseconds...", text: $timestampInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, design: .monospaced))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.055))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        DevSmallButton(title: "Convert", icon: "arrow.right", prominent: true) {
                            convertTimestamp()
                        }
                    }

                    if !convertedDateResult.isEmpty {
                        Text(convertedDateResult)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
            }
        }
        .onAppear(perform: regenerateDefaults)
        .onChange(of: stringLength) { regenerateRandomString() }
        .onChange(of: includeSymbols) { regenerateRandomString() }
        .onChange(of: includeDigits) { regenerateRandomString() }
        .onChange(of: excludeAmbiguous) { regenerateRandomString() }
        .onChange(of: tokenFormat) { regenerateToken() }
        .onChange(of: tokenBytes) { regenerateToken() }
    }

    private func generatorRow(
        title: String,
        subtitle: String,
        value: String,
        onGenerate: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)
                Spacer()
                DevSmallButton(title: "Generate", icon: "arrow.clockwise", action: onGenerate)
            }
            DevOutputField(text: value)
        }
    }

    private func timestampBadge(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8.5))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            DevCopyButton(text: value, compact: true)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func regenerateDefaults() {
        if uuidv4.isEmpty { uuidv4 = service.generateUUIDv4() }
        if uuidv7.isEmpty { uuidv7 = service.generateUUIDv7() }
        if ulid.isEmpty { ulid = service.generateULID() }
        if randomString.isEmpty { regenerateRandomString() }
        if secureToken.isEmpty { regenerateToken() }
    }

    private func regenerateRandomString() {
        randomString = service.generateRandomString(
            length: Int(stringLength),
            includeSymbols: includeSymbols,
            includeDigits: includeDigits,
            excludeAmbiguous: excludeAmbiguous
        )
    }

    private func regenerateToken() {
        secureToken = service.generateSecureToken(byteCount: Int(tokenBytes), format: tokenFormat)
    }

    private func convertTimestamp() {
        let trimmed = timestampInput.trimmingCharacters(in: .whitespaces)
        guard let number = Double(trimmed) else {
            convertedDateResult = "Invalid timestamp"
            return
        }

        let epochSeconds = number > 9_999_999_999 ? number / 1000.0 : number
        let date = Date(timeIntervalSince1970: epochSeconds)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium

        formatter.timeZone = .current
        let localString = formatter.string(from: date)

        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let utcString = formatter.string(from: date)

        let isoString = ISO8601DateFormatter().string(from: date)
        convertedDateResult = "Local: \(localString)\nUTC: \(utcString)\nISO: \(isoString)"
    }
}
