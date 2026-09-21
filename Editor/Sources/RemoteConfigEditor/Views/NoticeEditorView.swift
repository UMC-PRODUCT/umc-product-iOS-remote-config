//
//  NoticeEditorView.swift
//  RemoteConfigEditor
//
//  Created by euijjang97 on 9/17/26.
//

import SwiftUI

fileprivate enum Constants {
    static let previewPanelWidth: CGFloat = 320
    static let bodyEditorHeight: CGFloat = 100

    static let phoneWidth: CGFloat = 240
    static let phoneAspectRatio: CGFloat = 9 / 19.5
    static let bezelWidth: CGFloat = 6
    static let screenCornerRadius: CGFloat = 32
    static let islandSize = CGSize(width: 62, height: 18)

    static let alertWidth: CGFloat = 176
    static let alertCornerRadius: CGFloat = 16
    static let alertTitleSize: CGFloat = 11
    static let alertBodySize: CGFloat = 9

    static let blockingSymbolSize: CGFloat = 34
    static let blockingTitleSize: CGFloat = 14
    static let blockingBodySize: CGFloat = 10
}

struct NoticeEditorView: View {

    // MARK: - Property

    @Binding var notice: Notice
    let onDelete: () -> Void

    private var hasEndDate: Binding<Bool> {
        Binding {
            notice.until != nil
        } set: { isOn in
            notice.until = isOn ? Notice.dayString(from: .now) : nil
        }
    }

    private var endDate: Binding<Date> {
        Binding {
            notice.until.flatMap(Notice.date(from:)) ?? .now
        } set: { date in
            notice.until = Notice.dayString(from: date)
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            form
            Divider()
            NoticePreview(notice: notice)
                .frame(width: Constants.previewPanelWidth)
        }
    }

    private var form: some View {
        Form {
            Section {
                Toggle("켜기", isOn: $notice.enabled)
            } header: {
                Text("노출")
            } footer: {
                if notice.status == .expired {
                    caption("종료일이 지나 앱에 뜨지 않아요", color: .orange)
                }
            }

            Section {
                Picker("화면", selection: $notice.screen) {
                    ForEach(Screen.Category.allCases) { category in
                        Section(category.rawValue) {
                            ForEach(category.screens) { screen in
                                Text(screen.label).tag(screen)
                            }
                        }
                    }
                }
                Picker("모양", selection: $notice.template) {
                    ForEach(Template.allCases) { template in
                        Text(template.label).tag(template)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("대상")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    caption(notice.template.summary)
                    if notice.template == .blocking {
                        caption("닫을 수 없는 화면이에요. 끝나면 꼭 꺼 주세요", color: .red)
                    }
                }
            }

            Section("문구") {
                LabeledContent("제목") {
                    HStack(spacing: 8) {
                        TextField(
                            "제목",
                            text: $notice.title,
                            prompt: Text("서비스 점검 중이에요").foregroundStyle(EditorTheme.textFaint)
                        )
                            .labelsHidden()
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(EditorTheme.field, in: .rect(cornerRadius: EditorTheme.radiusSmall))
                        CharacterCounter(text: notice.title, limit: Notice.titleLimit)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("본문")
                        Spacer()
                        CharacterCounter(text: notice.body, limit: Notice.bodyLimit)
                    }
                    TextEditor(text: $notice.body)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(height: Constants.bodyEditorHeight)
                        .padding(12)
                        .background(EditorTheme.field, in: .rect(cornerRadius: EditorTheme.radiusSmall))
                }
            }

            Section {
                Toggle("종료일", isOn: hasEndDate)
                if notice.until != nil {
                    DatePicker("날짜", selection: endDate, displayedComponents: .date)
                }
            } header: {
                Text("기간")
            } footer: {
                if let error = notice.untilError {
                    caption(error, color: .red)
                } else if notice.until != nil {
                    caption("이 날짜 당일까지 떠요")
                }
            }

            Section {
                Button("안내 삭제", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(EditorTheme.canvas)
        .tint(EditorTheme.ink)
    }

    // MARK: - Function

    private func caption(_ text: String, color: Color = .secondary) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
    }
}

private struct CharacterCounter: View {

    // MARK: - Property

    let text: String
    let limit: Int

    private var count: Int { text.unicodeScalars.count }

    // MARK: - Body

    var body: some View {
        Text("\(count)/\(limit)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(count > limit ? Color.red : EditorTheme.textMuted)
    }
}

private struct NoticePreview: View {

    // MARK: - Property

    let notice: Notice

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            Text("iPhone 미리보기")
                .font(.caption)
                .foregroundStyle(EditorTheme.textMuted)
            phone
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EditorTheme.canvasSoft)
    }

    private var phone: some View {
        screen
            .clipShape(.rect(cornerRadius: Constants.screenCornerRadius, style: .continuous))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.black)
                    .frame(width: Constants.islandSize.width, height: Constants.islandSize.height)
                    .padding(.top, 8)
            }
            .padding(Constants.bezelWidth)
            .background(
                .black,
                in: .rect(
                    cornerRadius: Constants.screenCornerRadius + Constants.bezelWidth,
                    style: .continuous
                )
            )
            .aspectRatio(Constants.phoneAspectRatio, contentMode: .fit)
            .frame(maxWidth: Constants.phoneWidth)
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }

    @ViewBuilder
    private var screen: some View {
        switch notice.template {
        case .info:
            ZStack {
                fakeApp
                    .blur(radius: 1.5)
                    .overlay(Color.black.opacity(0.2))
                alert
            }
        case .blocking:
            blocking
        }
    }

    private var fakeApp: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .frame(width: 90, height: 16)
            RoundedRectangle(cornerRadius: 12)
                .frame(height: 88)
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 12)
                RoundedRectangle(cornerRadius: 12)
            }
            .frame(height: 70)
            RoundedRectangle(cornerRadius: 12)
                .frame(height: 110)
            Spacer(minLength: 0)
            Capsule()
                .frame(height: 36)
        }
        .foregroundStyle(Color.gray.opacity(0.22))
        .padding(.horizontal, 14)
        .padding(.top, 44)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var alert: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                text(notice.title, placeholder: "제목")
                    .font(.system(size: Constants.alertTitleSize, weight: .semibold))
                text(notice.body, placeholder: "본문")
                    .font(.system(size: Constants.alertBodySize))
            }
            .multilineTextAlignment(.center)
            .padding(12)
            Divider()
            Text("확인")
                .font(.system(size: Constants.alertTitleSize, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .frame(width: Constants.alertWidth)
        .background(
            Color(nsColor: .textBackgroundColor),
            in: .rect(cornerRadius: Constants.alertCornerRadius, style: .continuous)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private var blocking: some View {
        VStack(spacing: 10) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: Constants.blockingSymbolSize))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            text(notice.title, placeholder: "제목")
                .font(.system(size: Constants.blockingTitleSize, weight: .bold))
            text(notice.body, placeholder: "본문", style: .secondary)
                .font(.system(size: Constants.blockingBodySize))
        }
        .multilineTextAlignment(.center)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Function

    private func text(
        _ value: String,
        placeholder: String,
        style: HierarchicalShapeStyle = .primary
    ) -> Text {
        value.isEmpty
            ? Text(placeholder).foregroundStyle(.tertiary)
            : Text(value).foregroundStyle(style)
    }
}
