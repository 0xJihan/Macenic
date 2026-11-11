import Foundation
import AppKit

struct GitHubRelease: Decodable {
    let tagName: String
    let body: String?
    let htmlURL: String
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case htmlURL = "html_url"
        case draft
        case prerelease
        case assets
    }
}

struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

@MainActor
@Observable
final class AppUpdateService {
    static let repository = "0xJihan/Macenic"
    static let repositoryURL = "https://github.com/0xJihan/Macenic"

    var isChecking = false
    var isUpdateAvailable = false
    var latestVersion = ""
    var releaseNotes = ""
    var downloadURL = ""

    var statusMessage = ""
    var isShowingStatus = false

    private let endpoint = "https://api.github.com/repos/0xJihan/Macenic/releases/latest"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func checkForUpdates(showResult: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Macenic/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return }

            if httpResponse.statusCode == 404 {
                if showResult {
                    presentStatus("No releases were found for \(Self.repository).\n\nPublish a release on GitHub to enable update checks.")
                }
                return
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                if showResult {
                    presentStatus("Update check failed (HTTP \(httpResponse.statusCode)).")
                }
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard !release.draft, !release.prerelease else {
                if showResult {
                    presentStatus("The latest release is a draft or pre-release.")
                }
                return
            }

            let latest = Self.normalizedVersion(from: release.tagName)
            guard !latest.isEmpty else {
                if showResult {
                    presentStatus("The latest release has an invalid tag name.")
                }
                return
            }

            guard latest.compare(currentVersion, options: .numeric) == .orderedDescending else {
                if showResult {
                    presentStatus("You're up to date.\n\nMacenic \(currentVersion) is the latest version.")
                }
                return
            }

            let dmgAsset = release.assets.first { $0.name.lowercased().hasSuffix(".dmg") }
            let zipAsset = release.assets.first { $0.name.lowercased().hasSuffix(".zip") }
            let resolvedURL = (dmgAsset ?? zipAsset)?.browserDownloadURL ?? release.htmlURL

            latestVersion = latest
            releaseNotes = release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            downloadURL = resolvedURL
            isUpdateAvailable = true
        } catch {
            if showResult {
                presentStatus("Update check failed.\n\n\(error.localizedDescription)")
            }
        }
    }

    func dismissUpdate() {
        isUpdateAvailable = false
    }

    func dismissStatus() {
        isShowingStatus = false
    }

    func openDownload() {
        guard let url = URL(string: downloadURL) else { return }
        NSWorkspace.shared.open(url)
        isUpdateAvailable = false
    }

    func openRepository() {
        guard let url = URL(string: Self.repositoryURL) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func normalizedVersion(from tag: String) -> String {
        var version = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if version.lowercased().hasPrefix("v") {
            version.removeFirst()
        }
        return version
    }

    private func presentStatus(_ message: String) {
        statusMessage = message
        isShowingStatus = true
    }
}
