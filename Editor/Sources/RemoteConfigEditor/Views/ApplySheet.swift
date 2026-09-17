//
//  ApplySheet.swift
//  RemoteConfigEditor
//
//  Created by euijjang97 on 9/17/26.
//

import SwiftUI

fileprivate enum Constants {
    static let width: CGFloat = 480
    static let padding: CGFloat = 24
    static let boxCornerRadius: CGFloat = 10
    static let finishedSymbolSize: CGFloat = 56
}

struct ApplySheet: View {

    // MARK: - Property

    @Bindable var model: EditorModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // MARK: - Body

    var body: some View {
        Group {
            switch model.applyPhase {
            case .confirming:
                confirmation
            case .running, .failed:
                progress
            case .finished:
                finished
            }
        }
        .padding(Constants.padding)
        .frame(width: Constants.width)
        .interactiveDismissDisabled(model.applyPhase == .running)
    }

    private var confirmation: some View {
        let isDangerous = model.isDangerous
        return VStack(alignment: .leading, spacing: 16) {
            Text("변경 사항 적용")
                .font(.title2.bold())

            if isDangerous {
                Label(
                    "모든 화면을 막는 차단 안내가 켜져요. 적용 후 최대 10분 안에 모든 사용자가 앱을 쓸 수 없게 돼요.",
                    systemImage: "exclamationmark.octagon.fill"
                )
                .foregroundStyle(.red)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.12), in: .rect(cornerRadius: Constants.boxCornerRadius))
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(model.changes.enumerated()), id: \.offset) { _, change in
                    Label {
                        Text(change.text)
                    } icon: {
                        Image(systemName: change.kind.symbolName)
                            .foregroundStyle(change.kind.color)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .quaternary.opacity(0.5),
                in: .rect(cornerRadius: Constants.boxCornerRadius)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("커밋 메시지")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField("커밋 메시지", text: $model.commitMessage)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
            }

            HStack {
                Spacer()
                Button("취소", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isDangerous ? "앱 막기 적용" : "적용") {
                    Task { await model.apply() }
                }
                .buttonStyle(.glassProminent)
                .tint(isDangerous ? .red : nil)
                .keyboardShortcut(isDangerous ? nil : .defaultAction)
                .disabled(model.commitMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.applyPhase == .failed ? "적용하지 못했어요" : "적용하는 중…")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 6) {
                ForEach(ApplyStep.allCases) { step in
                    StepRow(title: step.title, state: model.state(of: step))
                }
            }

            HStack {
                if let url = model.pullRequestURL {
                    Link("PR 보기", destination: url)
                }
                Spacer()
                if model.applyPhase == .failed {
                    Button("닫기") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private var finished: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: Constants.finishedSymbolSize))
                .foregroundStyle(.green)
            Text("배포됐어요")
                .font(.title2.bold())
            Text("앱에는 캐시 때문에 최대 10분 뒤에 반영돼요.")
                .foregroundStyle(.secondary)
            HStack {
                if let url = model.pullRequestURL {
                    Button("PR 보기") { openURL(url) }
                }
                Button("닫기") { dismiss() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StepRow: View {

    // MARK: - Property

    let title: String
    let state: StepState

    private var isFailed: Bool {
        if case .failed = state { true } else { false }
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            icon
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(isFailed ? .semibold : .regular)
                    .foregroundStyle(state == .waiting ? .secondary : .primary)
                if case .failed(let message) = state {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            isFailed ? Color.red.opacity(0.1) : .clear,
            in: .rect(cornerRadius: Constants.boxCornerRadius)
        )
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .waiting:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

fileprivate extension EditorModel.Change.Kind {
    var symbolName: String {
        switch self {
        case .added: "plus.circle"
        case .removed: "minus.circle"
        case .enabled: "eye.circle"
        case .disabled: "eye.slash.circle"
        case .modified: "pencil.circle"
        }
    }

    var color: Color {
        switch self {
        case .added: .green
        case .removed: .red
        case .enabled: .green
        case .disabled: .secondary
        case .modified: .blue
        }
    }
}
