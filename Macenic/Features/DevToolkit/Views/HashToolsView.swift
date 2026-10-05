import SwiftUI

struct HashToolsView: View {
    let service: DevToolkitService

    @State private var input: String = ""
    @State private var hmacKey: String = ""
    @State private var sha256 = ""
    @State private var sha512 = ""
    @State private var md5 = ""
    @State private var hmac = ""

    var body: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Input Text to Hash")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Enter string to hash...", text: $input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(5)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .onChange(of: input) {
                        calculateHashes()
                    }
            }

            VStack(spacing: 5) {
                hashRow(algorithm: "SHA-256", hash: sha256)
                hashRow(algorithm: "SHA-512", hash: sha512)
                hashRow(algorithm: "MD5 (Legacy)", hash: md5, isWarning: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 3) {
                Text("HMAC-SHA256 (with Secret Key)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    SecureField("Secret Key...", text: $hmacKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(5)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .onChange(of: hmacKey) {
                            calculateHashes()
                        }

                    Button("Generate") {
                        calculateHashes()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if !hmac.isEmpty {
                    hashRow(algorithm: "HMAC", hash: hmac)
                }
            }
        }
    }

    private func hashRow(algorithm: String, hash: String, isWarning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(algorithm)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isWarning ? .orange : .secondary)

                if isWarning {
                    Text("(Non-secure)")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                }

                Spacer()

                if !hash.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(hash, forType: .string)
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 8))
                            Text("Copy")
                                .font(.system(size: 8))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(hash.isEmpty ? "—" : hash)
                .font(.system(size: 9, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(6)
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func calculateHashes() {
        guard !input.isEmpty else {
            sha256 = ""
            sha512 = ""
            md5 = ""
            hmac = ""
            return
        }

        sha256 = service.hashSHA256(input)
        sha512 = service.hashSHA512(input)
        md5 = service.hashMD5(input)

        if !hmacKey.isEmpty {
            hmac = service.hmacSHA256(input, secretKey: hmacKey)
        } else {
            hmac = ""
        }
    }
}
