//
//  AppConfig.swift
//  RemoteConfigEditor
//
//  Created by euijjang97 on 9/17/26.
//

import Foundation

struct AppConfig: Decodable, Equatable {

    // MARK: - Property

    static let empty = AppConfig(version: 1, minimumVersion: "", notices: [])

    var version: Int
    var minimumVersion: String
    var notices: [Notice]
}

struct Notice: Decodable, Equatable, Identifiable {

    enum Status {
        case live
        case off
        case expired
    }

    // MARK: - Property

    static let titleLimit = 40
    static let bodyLimit = 200

    var id = UUID()
    var screen: Screen = .all
    var enabled = false
    var template: Template = .info
    var title = ""
    var body = ""
    var until: String?

    private enum CodingKeys: String, CodingKey {
        case screen, enabled, template, title, body, until
    }

    // MARK: - Function

    static func == (lhs: Notice, rhs: Notice) -> Bool {
        lhs.screen == rhs.screen
            && lhs.enabled == rhs.enabled
            && lhs.template == rhs.template
            && lhs.title == rhs.title
            && lhs.body == rhs.body
            && lhs.until == rhs.until
    }
}

enum Screen: String, Decodable, CaseIterable, Identifiable {
    // schema.json 의 screen enum 과 같은 순서·값을 유지해야 한다
    case all = "ALL"
    case login
    case signUp
    case pendingApproval
    case home
    case notice
    case activity
    case community
    case mypage

    enum Category: String, CaseIterable, Identifiable {
        case all = "전체"
        case start = "시작"
        case tab = "탭"

        var id: Self { self }
        var screens: [Screen] { Screen.allCases.filter { $0.category == self } }
    }

    var id: Self { self }

    var category: Category {
        switch self {
        case .all: .all
        case .login, .signUp, .pendingApproval: .start
        case .home, .notice, .activity, .community, .mypage: .tab
        }
    }

    var label: String {
        switch self {
        case .all: "모든 화면"
        case .login: "로그인"
        case .signUp: "회원가입"
        case .pendingApproval: "가입 승인 대기"
        case .home: "홈 탭"
        case .notice: "공지 탭"
        case .activity: "활동 탭"
        case .community: "커뮤니티 탭"
        case .mypage: "마이페이지 탭"
        }
    }
}

enum Template: String, Decodable, CaseIterable, Identifiable {
    case info = "INFO"
    case blocking = "BLOCKING"

    var id: Self { self }

    var label: String {
        switch self {
        case .info: "안내"
        case .blocking: "차단"
        }
    }

    var summary: String {
        switch self {
        case .info: "확인 버튼이 있어요. 닫으면 앱을 다시 켜기 전까지 뜨지 않아요."
        case .blocking: "닫을 수 없는 전체 화면이에요. 버튼 없이 문구만 보여요."
        }
    }
}

// MARK: - Validation

extension AppConfig {

    var minimumVersionError: String? {
        guard minimumVersion.wholeMatch(of: /([0-9]+(\.[0-9]+){0,2})?/) == nil else { return nil }
        return "최소 버전은 2.3 이나 2.3.0 처럼 숫자와 점만 써요"
    }

    var validationErrors: [String] {
        let noticeErrors = notices.flatMap { notice in
            notice.errors.map { "\(notice.displayTitle): \($0)" }
        }
        return [minimumVersionError].compactMap { $0 } + noticeErrors
    }
}

extension Notice {

    private static let dayStyle = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()

    var displayTitle: String { title.isEmpty ? "제목 없음" : title }

    // validate 워크플로의 jsonschema maxLength 는 글자가 아닌 코드 포인트 수로 세므로 unicodeScalars 로 맞춘다
    var errors: [String] {
        var errors: [String] = []
        if title.isEmpty {
            errors.append("제목을 입력하세요")
        } else if title.unicodeScalars.count > Notice.titleLimit {
            errors.append("제목은 \(Notice.titleLimit)자 이내로 써 주세요")
        }
        if body.isEmpty {
            errors.append("본문을 입력하세요")
        } else if body.unicodeScalars.count > Notice.bodyLimit {
            errors.append("본문은 \(Notice.bodyLimit)자 이내로 써 주세요")
        }
        if let untilError {
            errors.append(untilError)
        }
        return errors
    }

    var untilError: String? {
        guard let until, Notice.date(from: until) == nil else { return nil }
        return "종료일 '\(until)' 이 yyyy-MM-dd 형식의 날짜가 아니에요"
    }

    var status: Status {
        guard enabled else { return .off }
        guard let until, until < Notice.dayString(from: .now) else { return .live }
        return .expired
    }

    var blocksEveryScreen: Bool {
        screen == .all && template == .blocking && status == .live
    }

    static func dayString(from date: Date) -> String {
        date.formatted(dayStyle)
    }

    static func date(from dayString: String) -> Date? {
        guard let date = try? dayStyle.parse(dayString),
              self.dayString(from: date) == dayString else { return nil }
        return date
    }
}

// MARK: - Serialization

extension AppConfig {

    func serialized() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        func quoted(_ value: String) -> String {
            String(decoding: try! encoder.encode(value), as: UTF8.self)
        }

        let noticeBlocks = notices.map { notice in
            var fields: [(key: String, value: String)] = [
                ("screen", quoted(notice.screen.rawValue)),
                ("enabled", String(notice.enabled)),
                ("template", quoted(notice.template.rawValue)),
                ("title", quoted(notice.title)),
                ("body", quoted(notice.body)),
            ]
            if let until = notice.until {
                fields.append(("until", quoted(until)))
            }
            let lines = fields.map { "      \"\($0.key)\": \($0.value)" }
            return "    {\n" + lines.joined(separator: ",\n") + "\n    }"
        }
        let noticesValue = noticeBlocks.isEmpty
            ? "[]"
            : "[\n" + noticeBlocks.joined(separator: ",\n") + "\n  ]"

        return """
            {
              "$schema": "./schema.json",
              "version": \(version),
              "minimumVersion": \(quoted(minimumVersion)),
              "notices": \(noticesValue)
            }

            """
    }
}
