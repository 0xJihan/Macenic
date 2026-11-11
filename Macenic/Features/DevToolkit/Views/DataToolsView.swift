import SwiftUI
import AppKit

enum DataSubtool: String, CaseIterable, Identifiable {
    case json = "JSON"
    case base64 = "Base64"
    case url = "URL"
    case jwt = "JWT"

    var id: String { rawValue }
}

private enum DevStatusKind {
    case info
    case success
    case error
}

struct DataToolsView: View {
    let service: DevToolkitService

    @State private var selectedSubtool: DataSubtool = .json
    @State private var input: String = ""
    @State private var output: String = ""
    @State private var secondaryOutput: String = ""
    @State private var statusMessage: String?
    @State private var statusKind: DevStatusKind = .info
    @State private var jsonIndent: String = "2"
    @State private var base64URLSafe = false
    @State private var jwtMetadata: JWTMetadata?

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $selectedSubtool) {
                ForEach(DataSubtool.allCases) { tool in
                    Text(tool.rawValue).tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: selectedSubtool) {
                clearAll()
            }

            switch selectedSubtool {
            case .json:
                jsonSection
            case .base64:
                base64Section
            case .url:
                urlSection
            case .jwt:
                jwtSection
            }
        }
    }

    // MARK: - JSON

    private var jsonSection: some View {
        DevCard(title: "JSON Formatter", icon: "curlybraces") {
            VStack(spacing: 7) {
                DevMonoEditor(title: "Input JSON", text: $input, minHeight: 70, maxHeight: 110)

                HStack(spacing: 6) {
                    Picker("", selection: $jsonIndent) {
                        Text("2 Spaces").tag("2")
                        Text("4 Spaces").tag("4")
                        Text("Tabs").tag("tab")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 185)

                    Spacer(minLength: 0)

                    DevSmallButton(title: "Clear", icon: "xmark") {
                        clearAll()
                    }
                }

                HStack(spacing: 6) {
                    DevSmallButton(title: "Format", icon: "text.alignleft", prominent: true) {
                        let result = service.formatJSON(input, indentStyle: jsonIndent)
                        output = result.result ?? ""
                        setStatus(result.error, kind: .error)
                    }

                    DevSmallButton(title: "Minify", icon: "arrow.down.right.and.arrow.up.left") {
                        let result = service.minifyJSON(input)
                        output = result.result ?? ""
                        setStatus(result.error, kind: .error)
                    }

                    DevSmallButton(title: "Validate", icon: "checkmark.seal") {
                        let result = service.validateJSON(input)
                        setStatus(result.message, kind: result.isValid ? .success : .error)
                    }

                    Spacer(minLength: 0)
                }

                statusBanner

                if !output.isEmpty {
                    DevMonoEditor(title: "Output", text: .constant(output), isReadOnly: true, minHeight: 70, maxHeight: 120)
                }
            }
        }
    }

    // MARK: - Base64

    private var base64Section: some View {
        DevCard(title: "Base64 Encoder / Decoder", icon: "b.circle") {
            VStack(spacing: 7) {
                HStack {
                    Picker("", selection: $base64URLSafe) {
                        Text("Standard").tag(false)
                        Text("URL-Safe").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 160)

                    Spacer()

                    DevSmallButton(title: "Clear", icon: "xmark") {
                        clearAll()
                    }
                }

                DevMonoEditor(title: "Input", text: $input, minHeight: 70, maxHeight: 110)

                HStack(spacing: 6) {
                    DevSmallButton(title: "Encode", icon: "arrow.right", prominent: true) {
                        output = service.base64Encode(input, urlSafe: base64URLSafe)
                        setStatus(nil)
                    }

                    DevSmallButton(title: "Decode", icon: "arrow.left") {
                        let result = service.base64Decode(input, urlSafe: base64URLSafe)
                        output = result.result ?? ""
                        setStatus(result.error, kind: .error)
                    }

                    DevSmallButton(title: "Swap", icon: "arrow.up.arrow.down") {
                        guard !output.isEmpty else { return }
                        input = output
                        output = ""
                        setStatus(nil)
                    }

                    Spacer(minLength: 0)
                }

                statusBanner

                if !output.isEmpty {
                    DevMonoEditor(title: "Output", text: .constant(output), isReadOnly: true, minHeight: 70, maxHeight: 120)
                }
            }
        }
    }

    // MARK: - URL

    private var urlSection: some View {
        DevCard(title: "URL Encoder / Decoder", icon: "link") {
            VStack(spacing: 7) {
                DevMonoEditor(title: "Input URL or Text", text: $input, minHeight: 70, maxHeight: 110)

                HStack(spacing: 6) {
                    DevSmallButton(title: "Encode Value", icon: "arrow.right", prominent: true) {
                        output = service.urlEncode(input, keepURLReserved: false)
                        setStatus(nil)
                    }

                    DevSmallButton(title: "Encode URL", icon: "link") {
                        output = service.urlEncode(input, keepURLReserved: true)
                        setStatus(nil)
                    }

                    DevSmallButton(title: "Decode", icon: "arrow.left") {
                        output = service.urlDecode(input)
                        setStatus(nil)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    DevSmallButton(title: "Parse Query Params", icon: "list.bullet.rectangle") {
                        let parameters = service.parseQueryParameters(input)
                        guard !parameters.isEmpty else {
                            output = ""
                            setStatus("No query parameters found", kind: .error)
                            return
                        }
                        output = parameters
                            .map { "\($0.name) = \($0.value)" }
                            .joined(separator: "\n")
                        setStatus("\(parameters.count) parameter\(parameters.count == 1 ? "" : "s")", kind: .success)
                    }

                    Spacer()

                    DevSmallButton(title: "Clear", icon: "xmark") {
                        clearAll()
                    }
                }

                statusBanner

                if !output.isEmpty {
                    DevMonoEditor(title: "Output", text: .constant(output), isReadOnly: true, minHeight: 70, maxHeight: 120)
                }
            }
        }
    }

    // MARK: - JWT

    private var jwtSection: some View {
        DevCard(title: "JWT Decoder", icon: "shield.lefthalf.filled") {
            VStack(spacing: 7) {
                DevMonoEditor(title: "Paste JWT (Header.Payload.Signature)", text: $input, minHeight: 70, maxHeight: 110)

                HStack(spacing: 6) {
                    DevSmallButton(title: "Decode", icon: "lock.open", prominent: true) {
                        let result = service.decodeJWT(input)
                        output = result.header ?? ""
                        secondaryOutput = result.payload ?? ""
                        jwtMetadata = result.payload.map { service.jwtMetadata(from: $0) }
                        setStatus(result.error, kind: .error)
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "shield")
                            .font(.system(size: 8.5))
                        Text("Decoded, not verified")
                            .font(.system(size: 8.5))
                    }
                    .foregroundStyle(.tertiary)

                    DevSmallButton(title: "Clear", icon: "xmark") {
                        clearAll()
                    }
                }

                statusBanner

                if let metadata = jwtMetadata {
                    jwtMetadataBanner(metadata)
                }

                if !output.isEmpty {
                    DevMonoEditor(title: "Header", text: .constant(output), isReadOnly: true, minHeight: 55, maxHeight: 90)
                }
                if !secondaryOutput.isEmpty {
                    DevMonoEditor(title: "Payload", text: .constant(secondaryOutput), isReadOnly: true, minHeight: 80, maxHeight: 140)
                }
            }
        }
    }

    private func jwtMetadataBanner(_ metadata: JWTMetadata) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let issuedAt = metadata.issuedAt {
                metadataRow(label: "Issued", value: formattedDate(issuedAt))
            }
            if let expiresAt = metadata.expiresAt {
                metadataRow(
                    label: "Expires",
                    value: "\(formattedDate(expiresAt))\(metadata.isExpired ? " (expired)" : "")",
                    isError: metadata.isExpired
                )
            }
            if metadata.issuedAt == nil, metadata.expiresAt == nil {
                Text("No iat or exp claims")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func metadataRow(label: String, value: String, isError: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(isError ? Color.orange : Color.primary)
            Spacer()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let statusMessage {
            DevStatusBanner(
                message: statusMessage,
                isError: statusKind == .error,
                isSuccess: statusKind == .success
            )
        }
    }

    private func setStatus(_ message: String?, kind: DevStatusKind = .info) {
        statusMessage = message
        statusKind = kind
    }

    private func clearAll() {
        input = ""
        output = ""
        secondaryOutput = ""
        statusMessage = nil
        statusKind = .info
        jwtMetadata = nil
    }
}
