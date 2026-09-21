//
//  SidebarView.swift
//  RemoteConfigEditor
//
//  Created by euijjang97 on 9/17/26.
//

import SwiftUI

struct SidebarView: View {

    // MARK: - Property

    @Bindable var model: EditorModel

    // MARK: - Body

    var body: some View {
        List(selection: $model.selection) {
            Section("앱") {
                minimumVersionRow
                    .tag(SidebarItem.minimumVersion)
            }
            Section {
                ForEach(model.draft.notices) { notice in
                    NoticeRow(notice: notice)
                        .tag(SidebarItem.notice(notice.id))
                        .contextMenu {
                            Button("복제", systemImage: "plus.square.on.square") {
                                model.duplicateNotice(notice.id)
                            }
                            Button("삭제", systemImage: "trash", role: .destructive) {
                                model.deleteNotice(notice.id)
                            }
                        }
                }
                if model.draft.notices.isEmpty {
                    Text("안내가 없어요. + 를 눌러 추가하세요.")
                        .font(.callout)
                        .foregroundStyle(EditorTheme.textMuted)
                }
            } header: {
                HStack {
                    Text("화면 안내")
                    Spacer()
                    Button("안내 추가", systemImage: "plus") { model.addNotice() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(OutlinePillButtonStyle())
                        .help("안내 추가")
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(EditorTheme.canvasSoft)
    }

    private var minimumVersionRow: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("강제 업데이트")
                    if model.draft.minimumVersionError != nil {
                        WarningIcon()
                    }
                }
                Text(model.draft.minimumVersion.isEmpty ? "꺼짐" : model.draft.minimumVersion)
                    .font(.caption)
                    .foregroundStyle(EditorTheme.textMuted)
            }
        } icon: {
            Image(systemName: "arrow.down.app")
        }
    }
}

private struct NoticeRow: View {

    // MARK: - Property

    let notice: Notice

    private var statusColor: Color {
        switch notice.status {
        case .live: .green
        case .off: .secondary
        case .expired: .orange
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(notice.displayTitle)
                        .lineLimit(1)
                    if !notice.errors.isEmpty {
                        WarningIcon()
                    }
                }
                HStack(spacing: 3) {
                    if notice.template == .blocking {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundStyle(.red)
                            .imageScale(.small)
                    }
                    Text("\(notice.screen.label) · \(notice.template.label)")
                        .foregroundStyle(EditorTheme.textMuted)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct WarningIcon: View {

    // MARK: - Body

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.yellow)
            .imageScale(.small)
    }
}
