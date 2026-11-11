import SwiftUI
import AppKit
import CryptoKit

struct HashToolsView: View {
    let service: DevToolkitService

    @State private var input: String = ""
    @State private var hmacKey: String = ""
    @State private var showHMACKey = false
    @State private var uppercaseOutput = false
    @State private var sha1 = ""
    @State private var sha256 = ""
    @State private var sha512 = ""
    @State private var md5 = ""
    @State private var hmac = ""

    var body: some View {
        VStack(spacing: 10) {
            DevCard(title: "Input", icon: "text.cursor") {
                VStack(spacing: 7) {
                    DevMonoEditor(title: "Text to Hash", text: $input, minHeight: 60, maxHeight: 100)

                    HStack(spacing: 6) {
                        Toggle("Uppercase output", isOn: $uppercaseOutput)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 9))

                        Spacer()

                        DevSmallButton(title: "Clear", icon: "xmark") {
                            input = ""
                            hmacKey = ""
                            clearHashes()
                        }
                    }
                }
            }

            DevCard(title: "Digests", icon: "number") {
                VStack(spacing: 6) {
                    hashRow(algorithm: "SHA-256", hash: sha256, badge: "Secure")
                    hashRow(algorithm: "SHA-512", hash: sha512, badge: "Secure")
                    hashRow(algorithm: "SHA-1", hash: sha1, badge: "Legacy", isWarning: true)
                    hashRow(algorithm: "MD5", hash: md5, badge: "Legacy", isWarning: true)
                }
            }

            DevCard(title: "HMAC-SHA256", icon: "key") {
                VStack(spacing: 7) {
                    HStack(spacing: 6) {
                        Group {
                            if showHMACKey {
                                TextField("Secret key...", text: $hmacKey)
                            } else {
                                SecureField("Secret key...", text: $hmacKey)
                            }
                        }
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.055))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Button {
                            showHMACKey.toggle()
                        } label: {
                            Image(systemName: showHMACKey ? "eye.slash" : "eye")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(showHMACKey ? "Hide key" : "Show key")

                        DevSmallButton(title: "Generate", icon: "arrow.clockwise", prominent: true) {
                            calculateHashes()
                        }
                    }

                    hashRow(algorithm: "HMAC", hash: hmac, badge: "Keyed")
                }
            }
        }
        .onAppear(perform: calculateHashes)
        .onChange(of: input) { calculateHashes() }
        .onChange(of: hmacKey) { calculateHashes() }
    }

    private func hashRow(
        algorithm: String,
        hash: String,
        badge: String,
        isWarning: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(algorithm)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(isWarning ? Color.orange : Color.primary)

                Text(badge.uppercased())
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(isWarning ? Color.orange : Color.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background((isWarning ? Color.orange : Color.secondary).opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                if !hash.isEmpty {
                    DevCopyButton(text: displayHash(hash), compact: false)
                }
            }

            Text(hash.isEmpty ? "—" : displayHash(hash))
                .font(.system(size: 9, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .padding(7)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func displayHash(_ hash: String) -> String {
        uppercaseOutput ? hash.uppercased() : hash
    }

    private func calculateHashes() {
        guard !input.isEmpty else {
            clearHashes()
            return
        }

        sha1 = service.hashSHA1(input)
        sha256 = service.hashSHA256(input)
        sha512 = service.hashSHA512(input)
        md5 = service.hashMD5(input)

        if hmacKey.isEmpty {
            hmac = ""
        } else {
            hmac = service.hmacSHA256(input, secretKey: hmacKey)
        }
    }

    private func clearHashes() {
        sha1 = ""
        sha256 = ""
        sha512 = ""
        md5 = ""
        hmac = ""
    }
}
