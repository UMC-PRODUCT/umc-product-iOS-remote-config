//
//  ContentView.swift
//  RemoteConfigEditor
//
//  Created by euijjang97 on 9/17/26.
//

import SwiftUI

struct ContentView: View {

    // MARK: - Property

    @Bindable var model: EditorModel
    @State private var isDiscardAlertPresented = false
    @Environment(\.openURL) private var openURL

    // MARK: - Body

    var body: some View {
        TimelineView(.everyMinute) { context in
            content
                .navigationTitle("UMC Launchpad")
                .navigationSubtitle(subtitle(now: context.date))
        }
        .tint(EditorTheme.ink)
        .background(EditorTheme.canvas)
        .toolbar { toolbar }
        .sheet(isPresented: $model.isApplySheetPresented) {
            ApplySheet(model: model)
        }
        .alert("변경 사항을 버릴까요?", isPresented: $isDiscardAlertPresented) {
            Button("버리고 새로고침", role: .destructive, action: reload)
            Button("취소", role: .cancel) {}
        } message: {
            Text("아직 적용하지 않은 변경 사항이 사라져요.")
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.loadState {
        case .loading:
            ProgressView("불러오는 중…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let error):
            failure(error)
        case .loaded:
            NavigationSplitView {
                SidebarView(model: model)
                    .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            } detail: {
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(EditorTheme.canvas)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection {
        case .minimumVersion:
            MinimumVersionView(config: $model.draft)
        case .notice(let id):
            if let notice = model.draft.notices.first(where: { $0.id == id }) {
                NoticeEditorView(notice: binding(for: notice)) {
                    model.deleteNotice(id)
                }
                .id(id)
            }
        case nil:
            ContentUnavailableView("왼쪽에서 항목을 고르세요", systemImage: "sidebar.left")
        }
    }

    @ViewBuilder
    private func failure(_ error: any Error) -> some View {
        switch error as? GitHubError {
        case .ghNotInstalled?:
            ContentUnavailableView {
                Label("gh CLI가 필요해요", systemImage: "terminal")
            } description: {
                Text("터미널에서 설치한 뒤 다시 시도하세요.")
            } actions: {
                CommandText(command: "brew install gh")
                Button("다시 시도", action: reload)
            }
        case .notLoggedIn?:
            ContentUnavailableView {
                Label("GitHub에 로그인해 주세요", systemImage: "person.crop.circle.badge.exclamationmark")
            } description: {
                Text("터미널에서 로그인한 뒤 다시 시도하세요.")
            } actions: {
                CommandText(command: "gh auth login")
                Button("다시 시도", action: reload)
            }
        default:
            ContentUnavailableView {
                Label("불러오지 못했어요", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("다시 시도", action: reload)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button("새로고침", systemImage: "arrow.clockwise", action: requestReload)
                .buttonStyle(OutlinePillButtonStyle())
                .help("main 에서 다시 불러오기")
                .disabled(model.isLoading)
        }
        ToolbarItem(placement: .primaryAction) {
            Button("GitHub", systemImage: "arrow.up.right.square") {
                openURL(GitHubClient.repositoryURL)
            }
            .buttonStyle(OutlinePillButtonStyle())
            .help("GitHub 저장소 열기")
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        if model.hasChanges {
            ToolbarItem(placement: .primaryAction) {
                Button("되돌리기") { model.revert() }
                    .buttonStyle(OutlinePillButtonStyle())
                    .help("불러온 상태로 되돌리기")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("적용") { model.beginApply() }
                .buttonStyle(InkPillButtonStyle())
                .keyboardShortcut("s")
                .disabled(model.applyBlockedReason != nil)
                .help(model.applyBlockedReason ?? "변경 사항을 main 에 적용해요 (⌘S)")
        }
    }

    // MARK: - Function

    private func subtitle(now: Date) -> String {
        guard let loadedAt = model.loadedAt else { return "" }
        let relative = now.timeIntervalSince(loadedAt) < 60
            ? "방금"
            : loadedAt.formatted(
                .relative(presentation: .named).locale(Locale(identifier: "ko_KR"))
            )
        return "main · \(relative) 불러옴"
    }

    private func binding(for notice: Notice) -> Binding<Notice> {
        Binding {
            model.draft.notices.first { $0.id == notice.id } ?? notice
        } set: { newValue in
            guard let index = model.draft.notices.firstIndex(where: { $0.id == notice.id })
            else { return }
            model.draft.notices[index] = newValue
        }
    }

    private func requestReload() {
        if model.hasChanges {
            isDiscardAlertPresented = true
        } else {
            reload()
        }
    }

    private func reload() {
        Task { await model.load() }
    }
}

private struct CommandText: View {

    // MARK: - Property

    let command: String

    // MARK: - Body

    var body: some View {
        Text(command)
            .font(.body.monospaced())
            .textSelection(.enabled)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(EditorTheme.field, in: .rect(cornerRadius: EditorTheme.radiusSmall))
    }
}
