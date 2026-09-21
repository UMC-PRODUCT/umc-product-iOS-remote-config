//
//  EditorModel.swift
//  RemoteConfigEditor
//
//  Created by euijjang97 on 9/17/26.
//

import Foundation
import Observation

enum SidebarItem: Hashable {
    case minimumVersion
    case notice(Notice.ID)
}

enum ApplyStep: CaseIterable, Identifiable {
    case conflictCheck
    case branch
    case commit
    case pullRequest
    case validation
    case merge
    case deploy

    var id: Self { self }

    var title: String {
        switch self {
        case .conflictCheck: "충돌 확인"
        case .branch: "브랜치 만들기"
        case .commit: "커밋"
        case .pullRequest: "PR 열기"
        case .validation: "검사 (validate)"
        case .merge: "머지"
        case .deploy: "배포 (GitHub Pages)"
        }
    }
}

enum StepState: Equatable {
    case waiting
    case running
    case done
    case failed(String)
}

@Observable
@MainActor
final class EditorModel {

    enum LoadState {
        case loading
        case loaded
        case failed(any Error)
    }

    enum ApplyPhase {
        case confirming
        case running
        case finished
        case failed
    }

    struct Change {
        enum Kind {
            case added
            case removed
            case enabled
            case disabled
            case modified
        }

        let kind: Kind
        let text: String
    }

    // MARK: - Property

    private(set) var loadState: LoadState = .loading
    private(set) var original = AppConfig.empty
    var draft = AppConfig.empty
    private(set) var loadedAt: Date?
    var selection: SidebarItem?

    var isApplySheetPresented = false
    var commitMessage = ""
    var applyRequest = ApplyRequest()
    private var requestConfig: AppConfig?
    private(set) var applyPhase: ApplyPhase = .confirming
    private(set) var pullRequestURL: URL?
    private var stepStates: [ApplyStep: StepState] = [:]

    private var client: GitHubClient?
    private var loadedFileSHA = ""

    var isLoading: Bool {
        if case .loading = loadState { true } else { false }
    }

    var hasChanges: Bool { draft != original }

    var applyBlockedReason: String? {
        guard hasChanges else { return "바뀐 내용이 없어요" }
        let errors = draft.validationErrors
        return errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    var changes: [Change] {
        var changes: [Change] = []
        if draft.minimumVersion != original.minimumVersion {
            let before = original.minimumVersion.isEmpty ? "없음" : original.minimumVersion
            let after = draft.minimumVersion.isEmpty ? "없음" : draft.minimumVersion
            changes.append(Change(kind: .modified, text: "최소 버전 \(before) → \(after)"))
        }

        let originalNotices = originalNoticesByID
        let draftIDs = Set(draft.notices.map(\.id))
        for notice in original.notices where !draftIDs.contains(notice.id) {
            changes.append(Change(kind: .removed, text: "안내 삭제 · \(notice.displayTitle)"))
        }
        for notice in draft.notices {
            guard var before = originalNotices[notice.id] else {
                changes.append(Change(kind: .added, text: "안내 추가 · \(notice.displayTitle)"))
                continue
            }
            if before.enabled != notice.enabled {
                changes.append(notice.enabled
                    ? Change(kind: .enabled, text: "안내 켜짐 · \(notice.displayTitle)")
                    : Change(kind: .disabled, text: "안내 꺼짐 · \(notice.displayTitle)"))
                before.enabled = notice.enabled
            }
            if before != notice {
                changes.append(Change(kind: .modified, text: "안내 수정 · \(notice.displayTitle)"))
            }
        }
        return changes
    }

    var isDangerous: Bool {
        let originalNotices = originalNoticesByID
        return draft.notices.contains { notice in
            notice.blocksEveryScreen && originalNotices[notice.id]?.blocksEveryScreen != true
        }
    }

    // MARK: - Function

    func load() async {
        let selectedIndex = selectedNoticeIndex
        loadState = .loading
        do {
            let client = try await GitHubClient.authenticated()
            let file = try await client.fetchConfigFile()
            let config = try JSONDecoder().decode(AppConfig.self, from: file.content)
            self.client = client
            original = config
            draft = config
            loadedFileSHA = file.sha
            loadedAt = .now
            loadState = .loaded
            restoreSelection(noticeIndex: selectedIndex)
        } catch {
            loadState = .failed(error)
        }
    }

    func revert() {
        let selectedIndex = selectedNoticeIndex
        draft = original
        if selectedNoticeIndex == nil {
            restoreSelection(noticeIndex: selectedIndex)
        }
    }

    func addNotice() {
        let notice = Notice()
        draft.notices.append(notice)
        selection = .notice(notice.id)
    }

    func duplicateNotice(_ id: Notice.ID) {
        guard let index = draft.notices.firstIndex(where: { $0.id == id }) else { return }
        var copy = draft.notices[index]
        copy.id = UUID()
        draft.notices.insert(copy, at: index + 1)
        selection = .notice(copy.id)
    }

    func deleteNotice(_ id: Notice.ID) {
        guard let index = draft.notices.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = selection == .notice(id)
        if wasSelected {
            selection = nil
        }
        draft.notices.remove(at: index)
        if wasSelected {
            restoreSelection(noticeIndex: index)
        }
    }

    func state(of step: ApplyStep) -> StepState {
        stepStates[step] ?? .waiting
    }

    func beginApply() {
        guard applyBlockedReason == nil else { return }
        if requestConfig != draft {
            applyRequest = ApplyRequest()
            let changed = draft.notices.filter { originalNoticesByID[$0.id] != $0 }
            let removed = original.notices.filter { old in !draft.notices.contains { $0.id == old.id } }
            let affected = changed + removed
            applyRequest.scope = affected.map { $0.screen == .all ? "앱 전체" : $0.screen.label }
                .joined(separator: " / ")
            applyRequest.action = affected.map { notice in
                let action = notice.template == .blocking ? "이용 차단" : "안내 메시지 표시"
                return "\(notice.screen.label): \(action)"
                    + (removed.contains { $0.id == notice.id } || !notice.enabled ? " 해제" : "")
            }.joined(separator: "\n")
            applyRequest.title = affected.map(\.title).joined(separator: "\n")
            applyRequest.body = affected.map(\.body).joined(separator: "\n\n")
            if draft.minimumVersion != original.minimumVersion {
                applyRequest.scope += affected.isEmpty ? "앱 전체" : " / 앱 전체"
                applyRequest.action += "\n최소 버전 변경: \(draft.minimumVersion.isEmpty ? "해제" : draft.minimumVersion)"
                if affected.isEmpty {
                    applyRequest.title = "해당 없음 (최소 버전 변경)"
                    applyRequest.body = "해당 없음 (최소 버전 변경)"
                }
            }
            requestConfig = draft
        }
        let changes = self.changes
        let summary = changes.first?.text ?? "변경"
        let others = changes.count > 1 ? " 외 \(changes.count - 1)건" : ""
        commitMessage = "원격 설정: \(summary)\(others)"
        applyPhase = .confirming
        stepStates = [:]
        pullRequestURL = nil
        isApplySheetPresented = true
    }

    func apply() async {
        guard let client, applyPhase == .confirming,
              applyBlockedReason == nil, applyRequest.isComplete,
              !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        applyPhase = .running

        let config = draft
        let title = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = applyRequest.markdown + "\n\n### 변경 사항\n\n"
            + changes.map { "- \($0.text)" }.joined(separator: "\n") + "\n\n편집 앱에서 적용"
        let branch = "config/" + Self.branchTimestamp()
        let fileSHA = loadedFileSHA
        var isBranchCreated = false
        var pullRequestNumber: Int?
        var isMerged = false

        do {
            try await run(.conflictCheck) {
                guard try await client.fetchConfigFile().sha == fileSHA else {
                    throw GitHubError.conflict
                }
            }
            try await run(.branch) {
                try await client.createBranch(branch)
            }
            isBranchCreated = true
            let commit = try await run(.commit) {
                try await client.commitConfig(
                    Data(config.serialized().utf8),
                    message: title,
                    fileSHA: fileSHA,
                    branch: branch
                )
            }
            let pullRequest = try await run(.pullRequest) {
                try await client.openPullRequest(title: title, body: body, branch: branch)
            }
            pullRequestURL = pullRequest.url
            pullRequestNumber = pullRequest.number
            try await run(.validation) {
                try await client.waitForValidation(commitSHA: commit.commitSHA)
            }
            let mergeSHA = try await run(.merge) {
                try await client.merge(
                    pullRequest: pullRequest.number,
                    title: "\(title) (#\(pullRequest.number))"
                )
            }
            isMerged = true
            // main 은 이미 바뀌었으니 배포가 실패해도 원본은 머지 결과로 맞춘다
            original = config
            loadedFileSHA = commit.fileSHA
            await client.deleteBranch(branch)
            try await run(.deploy) {
                try await client.waitForPages(commitSHA: mergeSHA)
            }
            applyPhase = .finished
        } catch {
            // 재시도마다 브랜치·PR 이 쌓이지 않게 치운다. 닫힌 PR 에서도 검사 로그는 볼 수 있다
            if !isMerged {
                if let pullRequestNumber {
                    await client.closePullRequest(pullRequestNumber)
                }
                if isBranchCreated {
                    await client.deleteBranch(branch)
                }
            }
            applyPhase = .failed
        }
    }

    private func run<Value>(
        _ step: ApplyStep,
        _ work: () async throws -> Value
    ) async throws -> Value {
        stepStates[step] = .running
        do {
            let value = try await work()
            stepStates[step] = .done
            return value
        } catch {
            stepStates[step] = .failed(error.localizedDescription)
            throw error
        }
    }

    private var originalNoticesByID: [Notice.ID: Notice] {
        Dictionary(uniqueKeysWithValues: original.notices.map { ($0.id, $0) })
    }

    private var selectedNoticeIndex: Int? {
        draft.notices.firstIndex { selection == .notice($0.id) }
    }

    private func restoreSelection(noticeIndex: Int?) {
        guard selection != .minimumVersion else { return }
        guard !draft.notices.isEmpty else {
            selection = .minimumVersion
            return
        }
        let index = min(noticeIndex ?? 0, draft.notices.count - 1)
        selection = .notice(draft.notices[index].id)
    }

    private static func branchTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: .now)
    }
}
