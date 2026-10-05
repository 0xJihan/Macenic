import SwiftUI

enum DataSubtool: String, CaseIterable, Identifiable {
    case json = "JSON"
    case base64 = "Base64"
    case url = "URL"
    case jwt = "JWT"

    var id: String { rawValue }
}

struct DataToolsView: View {
    let service: DevToolkitService

    @State private var selectedSubtool: DataSubtool = .json
    @State private var input: String = ""
    @State private var output: String = ""
    @State private var secondaryOutput: String = ""
    @State private var statusMessage: String?
    @State private var copiedFeedback = false

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $selectedSubtool) {
                ForEach(DataSubtool.allCases) { tool in
                    Text(tool.rawValue).tag(tool)
                }
            }
            .pickerStyle(.segmented)
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

    private var jsonSection: some View {
        VStack(spacing: 6) {
            editorBox(title: "Input JSON", text: $input)

            HStack(spacing: 6) {
                Button("Format (2 Spaces)") {
                    let res = service.formatJSON(input, indentSpaces: 2)
                    output = res.result ?? ""
                    statusMessage = res.error
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Minify") {
                    let res = service.minifyJSON(input)
                    output = res.result ?? ""
                    statusMessage = res.error
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Validate") {
                    let res = service.validateJSON(input)
                    statusMessage = res.message
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                copyButton(text: output)
            }

            if let msg = statusMessage {
                HStack(spacing: 4) {
                    Image(systemName: msg.hasPrefix("Valid") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(msg.hasPrefix("Valid") ? .green : .orange)
                    Text(msg)
                        .font(.system(size: 10))
                        .foregroundStyle(msg.hasPrefix("Valid") ? .green : .orange)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            if !output.isEmpty {
                editorBox(title: "Formatted / Minified Output", text: .constant(output), isReadOnly: true)
            }
        }
    }

    private var base64Section: some View {
        VStack(spacing: 6) {
            editorBox(title: "Input Text or Base64", text: $input)

            HStack(spacing: 6) {
                Button("Encode to Base64") {
                    output = service.base64Encode(input)
                    statusMessage = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Decode Base64") {
                    let res = service.base64Decode(input)
                    output = res.result ?? ""
                    statusMessage = res.error
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
                copyButton(text: output)
            }

            if let msg = statusMessage {
                errorMessage(msg)
            }

            editorBox(title: "Result", text: .constant(output), isReadOnly: true)
        }
    }

    private var urlSection: some View {
        VStack(spacing: 6) {
            editorBox(title: "Input URL or Text", text: $input)

            HStack(spacing: 6) {
                Button("URL Encode") {
                    output = service.urlEncode(input)
                    statusMessage = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("URL Decode") {
                    output = service.urlDecode(input)
                    statusMessage = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
                copyButton(text: output)
            }

            editorBox(title: "Result", text: .constant(output), isReadOnly: true)
        }
    }

    private var jwtSection: some View {
        VStack(spacing: 6) {
            editorBox(title: "Paste JWT (Header.Payload.Signature)", text: $input)

            HStack {
                Button("Decode JWT") {
                    let res = service.decodeJWT(input)
                    output = res.header ?? ""
                    secondaryOutput = res.payload ?? ""
                    statusMessage = res.error
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "shield")
                        .font(.system(size: 9))
                    Text("Decoded only (not verified)")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.tertiary)
            }

            if let msg = statusMessage {
                errorMessage(msg)
            }

            if !output.isEmpty {
                editorBox(title: "JWT Header (Decoded)", text: .constant(output), isReadOnly: true)
            }
            if !secondaryOutput.isEmpty {
                editorBox(title: "JWT Payload (Decoded)", text: .constant(secondaryOutput), isReadOnly: true)
            }
        }
    }

    private func editorBox(title: String, text: Binding<String>, isReadOnly: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !text.wrappedValue.isEmpty && isReadOnly {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text.wrappedValue, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .font(.system(size: 10, design: .monospaced))
                .frame(minHeight: 50, maxHeight: 75)
                .padding(4)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .disabled(isReadOnly)
        }
    }

    private func copyButton(text: String) -> some View {
        Button {
            guard !text.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copiedFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                copiedFeedback = false
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9))
                Text(copiedFeedback ? "Copied" : "Copy")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(text.isEmpty)
    }

    private func errorMessage(_ msg: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.orange)
            Text(msg)
                .font(.system(size: 9))
                .foregroundStyle(.orange)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func clearAll() {
        input = ""
        output = ""
        secondaryOutput = ""
        statusMessage = nil
    }
}
