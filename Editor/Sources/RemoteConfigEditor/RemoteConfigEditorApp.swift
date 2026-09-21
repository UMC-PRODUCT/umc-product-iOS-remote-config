//
//  RemoteConfigEditorApp.swift
//  RemoteConfigEditor
//
//  Created by euijjang97 on 9/17/26.
//

import AppKit
import SwiftUI

@main
struct RemoteConfigEditorApp: App {

    // MARK: - Property

    // 릴리즈 태그(v1.0.0)와 맞춘다. SwiftPM 실행 파일은 Info.plist 가 없어 여기서 관리한다
    static let version = "1.1.0"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // MARK: - Init

    // 앱 번들이 없어 메뉴 막대 앱 이름이 실행 파일 이름(RemoteConfigEditor)으로 뜬다. 메뉴를 만들기 전에 바꾼다
    init() {
        ProcessInfo.processInfo.processName = "UMC Launchpad"
    }

    // MARK: - Body

    var body: some Scene {
        Window("UMC Launchpad", id: "editor") {
            ContentView(model: appDelegate.model)
                .frame(minWidth: 900, minHeight: 600)
                .environment(\.locale, Locale(identifier: "ko_KR"))
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("UMC Launchpad에 관하여") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "UMC Launchpad",
                        .applicationVersion: Self.version,
                    ])
                }
                Button("업데이트 확인…") {
                    Task { await Updater.checkForUpdates(model: appDelegate.model, userInitiated: true) }
                }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Property

    let model = EditorModel()

    // MARK: - Function

    // SwiftPM 실행 파일은 앱 번들이 없어 직접 일반 앱으로 올려야 Dock 에 뜨고 창이 앞으로 온다
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate()
        Task { await Updater.checkForUpdates(model: model, userInitiated: false) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // 적용 도중 끝나면 브랜치·PR·머지 사이에서 멈춰 저장소에 반쯤 된 상태가 남는다
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.applyPhase == .running else { return .terminateNow }
        NSSound.beep()
        return .terminateCancel
    }
}
