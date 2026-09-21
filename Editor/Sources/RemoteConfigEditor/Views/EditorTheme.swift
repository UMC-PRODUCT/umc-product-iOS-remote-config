//
//  EditorTheme.swift
//  RemoteConfigEditor
//

import AppKit
import SwiftUI

enum EditorTheme {

    static let ink = adaptive(light: 0x141414, dark: 0xF4F4F4)
    static let canvas = adaptive(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let canvasSoft = adaptive(light: 0xF3F3F3, dark: 0x2C2C2E)
    static let field = adaptive(light: 0xF0F0F0, dark: 0x3A3A3C)
    static let hairlineSoft = adaptive(light: 0xF0F0F0, dark: 0x38383A)
    static let hairline = adaptive(light: 0xE0E0E0, dark: 0x48484A)
    static let textMuted = adaptive(light: 0x707070, dark: 0xA0A0A0)
    static let textFaint = adaptive(light: 0xADADAD, dark: 0x777777)

    static let radiusSmall: CGFloat = 16
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
                return NSColor(
                    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1
                )
            }
        )
    }
}

struct InkPillButtonStyle: ButtonStyle {

    var fill: Color = EditorTheme.ink
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(EditorTheme.canvas)
            .padding(.horizontal, 16)
            .frame(minHeight: 36)
            .background(
                fill.opacity(configuration.isPressed ? 0.78 : 1),
                in: Capsule()
            )
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Capsule())
    }
}

struct OutlinePillButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(EditorTheme.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 36)
            .background(
                configuration.isPressed ? EditorTheme.canvasSoft : EditorTheme.canvas,
                in: Capsule()
            )
            .overlay(Capsule().stroke(EditorTheme.hairline, lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Capsule())
    }
}
