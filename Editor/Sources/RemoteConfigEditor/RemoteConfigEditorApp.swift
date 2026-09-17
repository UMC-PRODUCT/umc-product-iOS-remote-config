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

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // MARK: - Body

    var body: some Scene {
        Window("iOS 원격 설정", id: "editor") {
            ContentView(model: appDelegate.model)
                .frame(minWidth: 900, minHeight: 600)
                .environment(\.locale, Locale(identifier: "ko_KR"))
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
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
