//
//  MinimumVersionView.swift
//  RemoteConfigEditor
//
//  Created by euijjang97 on 9/17/26.
//

import SwiftUI

struct MinimumVersionView: View {

    // MARK: - Property

    @Binding var config: AppConfig

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("최소 버전", text: $config.minimumVersion, prompt: Text("예: 2.3.0"))
                        .font(.body.monospaced())
                    Button("지우기") { config.minimumVersion = "" }
                        .disabled(config.minimumVersion.isEmpty)
                }
            } header: {
                Text("강제 업데이트")
            } footer: {
                if let error = config.minimumVersionError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Label("비우면 강제 업데이트를 하지 않아요.", systemImage: "circle.slash")
                Label("이 버전보다 낮은 앱은 업데이트 화면으로 막혀요.", systemImage: "lock")
                Label {
                    Text("App Store 최신 버전과 Major.Minor(예: 2.3)가 다르면 이 값과 상관없이 업데이트를 요구해요. "
                        + "그래서 패치 업데이트(2.3.0 → 2.3.1)를 강제할 때만 올리면 돼요.")
                } icon: {
                    Image(systemName: "info.circle")
                }
            } header: {
                Text("동작")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
