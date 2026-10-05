import SwiftUI

enum TextSubtool: String, CaseIterable, Identifiable {
    case regex = "Regex"
    case cases = "Case"
    case stats = "Count"
    case escape = "Escape"

    var id: String { rawValue }
}

struct TextToolsView: View {
    let service: DevToolkitService

    @State private var selectedSubtool: TextSubtool = .regex
    @State private var input: String = ""
    @State private var regexPattern: String = ""
    @State private var isCaseInsensitive: Bool = false
    @State private var regexMatches: [String] = []
    @State private var regexError: String?
    @State private var escapeType: String = "JSON"
    @State private var escapeOutput: String = ""

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $selectedSubtool) {
                ForEach(TextSubtool.allCases) { tool in
                    Text(tool.rawValue).tag(tool)
                }
            }
            .pickerStyle(.segmented)

            switch selectedSubtool {
            case .regex:
                regexSection
            case .cases:
                caseSection
            case .stats:
                statsSection
            case .escape:
                escapeSection
            }
        }
    }

    private var regexSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                TextField("Pattern (e.g. [a-zA-Z0-9]+)...", text: $regexPattern)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(5)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                Toggle("i", isOn: $isCaseInsensitive)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 10, design: .monospaced))
                    .help("Case Insensitive")

                Button("Test") {
                    let res = service.testRegex(pattern: regexPattern, text: input, isCaseInsensitive: isCaseInsensitive)
                    regexMatches = res.matches
                    regexError = res.error
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            TextEditor(text: $input)
                .scrollContentBackground(.hidden)
                .font(.system(size: 10, design: .monospaced))
                .frame(minHeight: 50, maxHeight: 70)
                .padding(4)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            if let err = regexError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                    Spacer()
                }
            } else {
                HStack {
                    Text("\(regexMatches.count) match\(regexMatches.count == 1 ? "" : "es")")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                if !regexMatches.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(regexMatches.prefix(20).enumerated()), id: \.offset) { _, m in
                                Text(m)
                                    .font(.system(size: 9, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary.opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
            }
        }
    }

    private var caseSection: some View {
        VStack(spacing: 6) {
            TextField("Type or paste text...", text: $input)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(5)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 5))

            VStack(spacing: 4) {
                caseRow(name: "camelCase", converted: service.convertCase(input, to: "camelCase"))
                caseRow(name: "PascalCase", converted: service.convertCase(input, to: "PascalCase"))
                caseRow(name: "snake_case", converted: service.convertCase(input, to: "snake_case"))
                caseRow(name: "kebab-case", converted: service.convertCase(input, to: "kebab-case"))
                caseRow(name: "CONSTANT_CASE", converted: service.convertCase(input, to: "CONSTANT_CASE"))
                caseRow(name: "Title Case", converted: service.convertCase(input, to: "Title Case"))
            }
        }
    }

    private func caseRow(name: String, converted: String) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 85, alignment: .leading)

            Text(converted.isEmpty ? "-" : converted)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if !converted.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(converted, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var statsSection: some View {
        let stats = service.calculateTextStats(input)
        return VStack(spacing: 6) {
            TextEditor(text: $input)
                .scrollContentBackground(.hidden)
                .font(.system(size: 10))
                .frame(minHeight: 60, maxHeight: 80)
                .padding(4)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 6) {
                statTile(label: "Characters", value: "\(stats.chars)")
                statTile(label: "No Spaces", value: "\(stats.charsNoSpaces)")
                statTile(label: "Words", value: "\(stats.words)")
                statTile(label: "Lines", value: "\(stats.lines)")
                statTile(label: "Bytes", value: "\(stats.bytes)")
            }
        }
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var escapeSection: some View {
        VStack(spacing: 6) {
            HStack {
                Picker("", selection: $escapeType) {
                    Text("JSON").tag("JSON")
                    Text("HTML").tag("HTML")
                    Text("URL").tag("URL")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

                Spacer()

                Button("Escape") {
                    escapeOutput = service.escapeText(input, type: escapeType)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Unescape") {
                    escapeOutput = service.unescapeText(input, type: escapeType)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            TextEditor(text: $input)
                .scrollContentBackground(.hidden)
                .font(.system(size: 10, design: .monospaced))
                .frame(minHeight: 45, maxHeight: 60)
                .padding(4)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            if !escapeOutput.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Output")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(escapeOutput, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    TextEditor(text: .constant(escapeOutput))
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(minHeight: 45, maxHeight: 60)
                        .padding(4)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .disabled(true)
                }
            }
        }
    }
}
