import SwiftUI
import AppKit

enum TextSubtool: String, CaseIterable, Identifiable {
    case regex = "Regex"
    case cases = "Case"
    case transform = "Clean"
    case stats = "Count"
    case escape = "Escape"

    var id: String { rawValue }
}

struct TextToolsView: View {
    let service: DevToolkitService

    @State private var selectedSubtool: TextSubtool = .regex
    @State private var input: String = ""
    @State private var regexPattern: String = ""
    @State private var replacement: String = ""
    @State private var isCaseInsensitive: Bool = false
    @State private var regexMatches: [String] = []
    @State private var regexError: String?
    @State private var regexOutput: String = ""
    @State private var transformOutput: String = ""
    @State private var escapeType: String = "JSON"
    @State private var escapeOutput: String = ""

    private let transformOperations = [
        "Trim",
        "Remove Empty Lines",
        "Remove Duplicates",
        "Reverse",
        "Sort A-Z",
        "Sort Z-A",
        "UPPERCASE",
        "lowercase"
    ]

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $selectedSubtool) {
                ForEach(TextSubtool.allCases) { tool in
                    Text(tool.rawValue).tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch selectedSubtool {
            case .regex:
                regexSection
            case .cases:
                caseSection
            case .transform:
                transformSection
            case .stats:
                statsSection
            case .escape:
                escapeSection
            }
        }
    }

    // MARK: - Regex

    private var regexSection: some View {
        DevCard(title: "Regex Tester", icon: "text.magnifyingglass") {
            VStack(spacing: 7) {
                HStack(spacing: 6) {
                    TextField("Pattern, e.g. [A-Z0-9]+", text: $regexPattern)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.055))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Toggle("i", isOn: $isCaseInsensitive)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 10, design: .monospaced))
                        .help("Case insensitive")

                    DevSmallButton(title: "Test", icon: "play.fill", prominent: true) {
                        runRegex()
                    }
                }

                DevMonoEditor(title: "Test Text", text: $input, minHeight: 65, maxHeight: 105)

                if let regexError {
                    DevStatusBanner(message: regexError, isError: true)
                } else if !regexPattern.isEmpty {
                    HStack {
                        Text("\(regexMatches.count) match\(regexMatches.count == 1 ? "" : "es")")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    if !regexMatches.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Array(regexMatches.prefix(20).enumerated()), id: \.offset) { _, match in
                                    Text(match.isEmpty ? "∅" : match)
                                        .font(.system(size: 9, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 6) {
                    TextField("Replacement (supports $1 groups)", text: $replacement)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.055))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    DevSmallButton(title: "Replace", icon: "arrow.2.squarepath") {
                        let result = service.replaceRegex(
                            pattern: regexPattern,
                            replacement: replacement,
                            text: input,
                            isCaseInsensitive: isCaseInsensitive
                        )
                        regexOutput = result.result ?? ""
                        regexError = result.error
                    }
                }

                if !regexOutput.isEmpty {
                    DevMonoEditor(title: "Replaced Output", text: .constant(regexOutput), isReadOnly: true, minHeight: 60, maxHeight: 100)
                }
            }
        }
    }

    // MARK: - Case

    private var caseSection: some View {
        DevCard(title: "Case Converter", icon: "textformat") {
            VStack(spacing: 7) {
                DevMonoEditor(title: "Input", text: $input, minHeight: 60, maxHeight: 90)

                VStack(spacing: 4) {
                    caseRow(name: "lowercase", converted: service.convertCase(input, to: "lowercase"))
                    caseRow(name: "UPPERCASE", converted: service.convertCase(input, to: "UPPERCASE"))
                    caseRow(name: "camelCase", converted: service.convertCase(input, to: "camelCase"))
                    caseRow(name: "PascalCase", converted: service.convertCase(input, to: "PascalCase"))
                    caseRow(name: "snake_case", converted: service.convertCase(input, to: "snake_case"))
                    caseRow(name: "kebab-case", converted: service.convertCase(input, to: "kebab-case"))
                    caseRow(name: "CONSTANT_CASE", converted: service.convertCase(input, to: "CONSTANT_CASE"))
                    caseRow(name: "Title Case", converted: service.convertCase(input, to: "Title Case"))
                }
            }
        }
    }

    private func caseRow(name: String, converted: String) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 8.5))
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)

            Text(converted.isEmpty ? "—" : converted)
                .font(.system(size: 9.5, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .foregroundStyle(converted.isEmpty ? Color.secondary : Color.primary)

            Spacer(minLength: 4)

            DevCopyButton(text: converted, compact: true)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Transform

    private var transformSection: some View {
        DevCard(title: "Text Cleanup", icon: "wand.and.rays") {
            VStack(spacing: 7) {
                DevMonoEditor(title: "Input", text: $input, minHeight: 70, maxHeight: 110)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 5) {
                    ForEach(transformOperations, id: \.self) { operation in
                        Button {
                            transformOutput = service.transformLines(input, operation: operation)
                        } label: {
                            Text(operation)
                                .font(.system(size: 9.5, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(Color.primary.opacity(0.055))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !transformOutput.isEmpty {
                    DevMonoEditor(title: "Output", text: .constant(transformOutput), isReadOnly: true, minHeight: 70, maxHeight: 120)
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        let stats = service.calculateTextStats(input)

        return DevCard(title: "Text Statistics", icon: "chart.bar") {
            VStack(spacing: 7) {
                DevMonoEditor(title: "Input", text: $input, minHeight: 80, maxHeight: 130)

                HStack(spacing: 5) {
                    statTile(label: "Chars", value: "\(stats.chars)")
                    statTile(label: "No Spaces", value: "\(stats.charsNoSpaces)")
                    statTile(label: "Words", value: "\(stats.words)")
                    statTile(label: "Lines", value: "\(stats.lines)")
                    statTile(label: "Bytes", value: "\(stats.bytes)")
                }
            }
        }
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 7.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Escape

    private var escapeSection: some View {
        DevCard(title: "Escape / Unescape", icon: "chevron.left.forwardslash.chevron.right") {
            VStack(spacing: 7) {
                HStack {
                    Picker("", selection: $escapeType) {
                        Text("JSON").tag("JSON")
                        Text("HTML").tag("HTML")
                        Text("URL").tag("URL")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 165)

                    Spacer()

                    DevSmallButton(title: "Clear", icon: "xmark") {
                        input = ""
                        escapeOutput = ""
                    }
                }

                DevMonoEditor(title: "Input", text: $input, minHeight: 65, maxHeight: 100)

                HStack(spacing: 6) {
                    DevSmallButton(title: "Escape", icon: "arrow.right", prominent: true) {
                        escapeOutput = service.escapeText(input, type: escapeType)
                    }

                    DevSmallButton(title: "Unescape", icon: "arrow.left") {
                        escapeOutput = service.unescapeText(input, type: escapeType)
                    }

                    Spacer()
                }

                if !escapeOutput.isEmpty {
                    DevMonoEditor(title: "Output", text: .constant(escapeOutput), isReadOnly: true, minHeight: 65, maxHeight: 100)
                }
            }
        }
    }

    private func runRegex() {
        let result = service.testRegex(
            pattern: regexPattern,
            text: input,
            isCaseInsensitive: isCaseInsensitive
        )
        regexMatches = result.matches
        regexError = result.error
    }
}
