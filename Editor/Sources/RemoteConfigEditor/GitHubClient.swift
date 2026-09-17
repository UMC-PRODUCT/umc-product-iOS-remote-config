//
//  GitHubClient.swift
//  RemoteConfigEditor
//
//  Created by euijjang97 on 9/17/26.
//

import Foundation

enum GitHubError: LocalizedError {
    case ghNotInstalled
    case notLoggedIn
    case http(status: Int, message: String)
    case invalidResponse
    case conflict
    case validationFailed(conclusion: String)
    case pagesFailed(message: String?)
    case timedOut(step: String)

    var errorDescription: String? {
        switch self {
        case .ghNotInstalled:
            "gh CLI가 필요해요."
        case .notLoggedIn:
            "GitHub에 로그인해 주세요."
        case .http(let status, let message):
            message.isEmpty
                ? "GitHub 요청이 실패했어요 (\(status))."
                : "GitHub 요청이 실패했어요 (\(status)): \(message)"
        case .invalidResponse:
            "GitHub 응답을 읽지 못했어요."
        case .conflict:
            "불러온 뒤 다른 사람이 먼저 바꿨어요. 새로 불러온 뒤 다시 적용하세요."
        case .validationFailed(let conclusion):
            "validate 검사를 통과하지 못했어요 (\(conclusion)). PR에서 원인을 확인하세요."
        case .pagesFailed(let message):
            "GitHub Pages 배포가 실패했어요." + (message.map { " \($0)" } ?? "")
        case .timedOut(let step):
            "\(step) 결과를 5분 안에 받지 못했어요."
        }
    }
}

struct GitHubClient: Sendable {

    // MARK: - Property

    static let owner = "UMC-PRODUCT"
    static let repository = "umc-product-iOS-remote-config"
    static let repositoryURL = URL(string: "https://github.com/\(owner)/\(repository)")!

    private static let apiRoot = "https://api.github.com/repos/\(owner)/\(repository)"
    private static let configPath = "app-config.json"
    private static let baseBranch = "main"
    private static let pollingTimeout = Duration.seconds(300)

    private let token: String

    // MARK: - Function

    static func authenticated() async throws -> GitHubClient {
        // Finder 로 띄우면 PATH 가 /usr/bin:/bin 정도라 흔한 설치 위치를 뒤에 덧붙인다
        let pathDirectories = ProcessInfo.processInfo.environment["PATH", default: ""]
            .split(separator: ":")
            .map(String.init)
        let fallbackDirectories = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/opt/local/bin",
            NSHomeDirectory() + "/.local/share/mise/shims",
        ]
        let candidates = (pathDirectories + fallbackDirectories).map { $0 + "/gh" }
        let fileManager = FileManager.default
        guard let path = candidates.first(where: fileManager.isExecutableFile(atPath:)) else {
            throw GitHubError.ghNotInstalled
        }

        let process = Process()
        process.executableURL = URL(filePath: path)
        process.arguments = ["auth", "token"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw GitHubError.notLoggedIn
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let token = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, !token.isEmpty else { throw GitHubError.notLoggedIn }
        return GitHubClient(token: token)
    }

    func fetchConfigFile() async throws -> (sha: String, content: Data) {
        let file: FileResponse = try await send(
            "GET", "/contents/\(Self.configPath)?ref=\(Self.baseBranch)"
        )
        guard let content = Data(base64Encoded: file.content, options: .ignoreUnknownCharacters)
        else { throw GitHubError.invalidResponse }
        return (file.sha, content)
    }

    func createBranch(_ branch: String) async throws {
        let base: ReferenceResponse = try await send("GET", "/git/ref/heads/\(Self.baseBranch)")
        let _: ReferenceResponse = try await send(
            "POST", "/git/refs",
            body: ["ref": "refs/heads/\(branch)", "sha": base.object.sha]
        )
    }

    func commitConfig(
        _ content: Data,
        message: String,
        fileSHA: String,
        branch: String
    ) async throws -> (commitSHA: String, fileSHA: String) {
        do {
            let response: CommitResponse = try await send(
                "PUT", "/contents/\(Self.configPath)",
                body: [
                    "message": message,
                    "content": content.base64EncodedString(),
                    "sha": fileSHA,
                    "branch": branch,
                ]
            )
            return (response.commit.sha, response.content.sha)
        } catch GitHubError.http(let status, _) where status == 409 || status == 422 {
            throw GitHubError.conflict
        }
    }

    func openPullRequest(
        title: String,
        body: String,
        branch: String
    ) async throws -> (number: Int, url: URL) {
        let response: PullRequestResponse = try await send(
            "POST", "/pulls",
            body: ["title": title, "body": body, "head": branch, "base": Self.baseBranch]
        )
        return (response.number, response.htmlURL)
    }

    func waitForValidation(commitSHA: String) async throws {
        try await poll(every: .seconds(3), step: "validate 검사") {
            let response: CheckRunsResponse = try await send(
                "GET", "/commits/\(commitSHA)/check-runs?check_name=validate"
            )
            guard let run = response.checkRuns.first, run.status == "completed" else {
                return false
            }
            guard run.conclusion == "success" else {
                throw GitHubError.validationFailed(conclusion: run.conclusion ?? run.status)
            }
            return true
        }
    }

    func merge(pullRequest number: Int, title: String) async throws -> String {
        let response: ShaResponse = try await send(
            "PUT", "/pulls/\(number)/merge",
            body: ["merge_method": "squash", "commit_title": title]
        )
        return response.sha
    }

    func closePullRequest(_ number: Int) async {
        _ = try? await sendRequest("PATCH", "/pulls/\(number)", body: ["state": "closed"])
    }

    func deleteBranch(_ branch: String) async {
        _ = try? await sendRequest("DELETE", "/git/refs/heads/\(branch)", body: nil)
    }

    func waitForPages(commitSHA: String) async throws {
        try await poll(every: .seconds(5), step: "GitHub Pages 배포") {
            let build: PagesBuildResponse = try await send("GET", "/pages/builds/latest")
            guard build.commit == commitSHA else { return false }
            if build.status == "errored" {
                throw GitHubError.pagesFailed(message: build.error?.message)
            }
            return build.status == "built"
        }
    }

    private func poll(
        every interval: Duration,
        step: String,
        until isDone: () async throws -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + Self.pollingTimeout
        while ContinuousClock.now < deadline {
            if try await isDone() { return }
            try await Task.sleep(for: interval)
        }
        throw GitHubError.timedOut(step: step)
    }

    private func send<Response: Decodable>(
        _ method: String,
        _ path: String,
        body: [String: String]? = nil
    ) async throws -> Response {
        let data = try await sendRequest(method, path, body: body)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw GitHubError.invalidResponse
        }
    }

    private func sendRequest(
        _ method: String,
        _ path: String,
        body: [String: String]?
    ) async throws -> Data {
        var request = URLRequest(url: URL(string: Self.apiRoot + path)!)
        request.httpMethod = method
        // GitHub 응답은 max-age=60 이라 캐시를 타면 충돌 확인·폴링이 옛 값을 본다
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(MessageResponse.self, from: data))?.message
            throw GitHubError.http(status: status, message: message ?? "")
        }
        return data
    }
}

// MARK: - Response

private struct MessageResponse: Decodable {
    let message: String
}

private struct ShaResponse: Decodable {
    let sha: String
}

private struct FileResponse: Decodable {
    let sha: String
    let content: String
}

private struct ReferenceResponse: Decodable {
    let object: ShaResponse
}

private struct CommitResponse: Decodable {
    let content: ShaResponse
    let commit: ShaResponse
}

private struct PullRequestResponse: Decodable {
    let number: Int
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case number
        case htmlURL = "html_url"
    }
}

private struct CheckRunsResponse: Decodable {
    struct CheckRun: Decodable {
        let status: String
        let conclusion: String?
    }

    let checkRuns: [CheckRun]

    enum CodingKeys: String, CodingKey {
        case checkRuns = "check_runs"
    }
}

private struct PagesBuildResponse: Decodable {
    struct BuildError: Decodable {
        let message: String?
    }

    let status: String
    let commit: String?
    let error: BuildError?
}
