//
//  Updater.swift
//  RemoteConfigEditor
//
//  Created by euijjang97 on 9/17/26.
//

import AppKit

enum UpdateError: LocalizedError {
    case notInstalled
    case applying
    case download(status: Int)
    case command(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            "앱을 응용 프로그램 폴더로 옮긴 뒤 다시 켜 주세요."
        case .applying:
            "적용이 끝난 뒤 다시 시도하세요."
        case .download(let status):
            "업데이트 파일을 받지 못했어요 (\(status))."
        case .command(let command):
            "\(command) 실행에 실패했어요."
        }
    }
}

// GitHub 최신 릴리즈의 DMG 로 앱 번들을 바꿔 끼우고 다시 켠다
// ad-hoc 서명이라 받은 앱의 서명은 검증하지 않고 GitHub HTTPS 를 믿는다. Developer ID 서명을 쓰게 되면 codesign 검증을 추가한다
enum Updater {

    // MARK: - Function

    @MainActor
    static func checkForUpdates(model: EditorModel, userInitiated: Bool) async {
        // swift run 으로 띄우면 바꿔 끼울 앱 번들이 없다
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            if userInitiated { showAlert("앱 번들로 실행할 때만 업데이트할 수 있어요", "build-app.sh 로 만든 앱에서 확인하세요.") }
            return
        }
        do {
            let release = try await latestRelease()
            let latest = String(release.tagName.trimmingPrefix("v"))
            let current = RemoteConfigEditorApp.version
            guard latest.compare(current, options: .numeric) == .orderedDescending,
                  let dmg = release.assets.first(where: { $0.name.hasSuffix(".dmg") })
            else {
                if userInitiated { showAlert("최신 버전을 쓰고 있어요", "UMC Launchpad \(current)") }
                return
            }

            let alert = NSAlert()
            alert.messageText = "UMC Launchpad \(latest) 이 나왔어요"
            alert.informativeText = "지금 버전은 \(current) 이에요. 업데이트를 받으면 앱이 다시 켜져요."
                + (model.hasChanges ? "\n적용하지 않은 변경 사항은 사라져요." : "")
            alert.addButton(withTitle: "업데이트")
            alert.addButton(withTitle: "나중에")
            guard alert.runModal() == .alertFirstButtonReturn else { return }

            let app = Bundle.main.bundleURL
            // 격리된 채로 실행(App Translocation)하거나 DMG 안에서 켜면 제자리를 바꿀 수 없다
            guard FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path) else {
                throw UpdateError.notInstalled
            }
            let staged = try await stage(dmg.browserDownloadURL, appName: app.lastPathComponent)
            guard model.applyPhase != .running else { throw UpdateError.applying }
            try relaunch(replacing: app, with: staged)
        } catch {
            if userInitiated { showAlert("업데이트하지 못했어요", error.localizedDescription) }
        }
    }

    private static func latestRelease() async throws -> Release {
        let url = URL(string: "https://api.github.com/repos/\(GitHubClient.owner)/\(GitHubClient.repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Release.self, from: data)
    }

    // URLSession 으로 받은 파일에는 격리 속성이 붙지 않아 다시 켤 때 Gatekeeper 확인 창이 뜨지 않는다
    private static func stage(_ url: URL, appName: String) async throws -> URL {
        let (dmg, response) = try await URLSession.shared.download(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw UpdateError.download(status: status) }

        let work = FileManager.default.temporaryDirectory.appending(path: "UMCTreeUpdate-\(UUID().uuidString)")
        let mount = work.appending(path: "mount")
        let staged = work.appending(path: appName)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)

        try await run("/usr/bin/hdiutil", "attach", dmg.path, "-nobrowse", "-readonly", "-mountpoint", mount.path)
        do {
            try await run("/usr/bin/ditto", mount.appending(path: "UMC Launchpad.app").path, staged.path)
        } catch {
            try? await run("/usr/bin/hdiutil", "detach", mount.path, "-force")
            throw error
        }
        try? await run("/usr/bin/hdiutil", "detach", mount.path, "-force")
        try? FileManager.default.removeItem(at: dmg)
        return staged
    }

    // 실행 중인 번들을 지우면 종료 처리 중에 리소스를 못 읽을 수 있어, 앱이 완전히 끝난 뒤 셸에서 바꾼다
    @MainActor
    private static func relaunch(replacing app: URL, with staged: URL) throws {
        let script = """
            while /bin/kill -0 "$3" 2>/dev/null; do /bin/sleep 0.2; done
            /bin/rm -rf "$1" && /bin/mv "$2" "$1" && /usr/bin/open "$1"
            """
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", script, "sh", app.path, staged.path, "\(ProcessInfo.processInfo.processIdentifier)"]
        try process.run()
        NSApplication.shared.terminate(nil)
    }

    private static func run(_ executable: String, _ arguments: String...) async throws {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
        guard status == 0 else { throw UpdateError.command(URL(filePath: executable).lastPathComponent) }
    }

    @MainActor
    private static func showAlert(_ message: String, _ information: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = information
        alert.runModal()
    }
}

// MARK: - Response

private struct Release: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}
