//
//  AppConfigTests.swift
//  RemoteConfigEditorTests
//
//  Created by euijjang97 on 9/17/26.
//

import Foundation
import Testing
@testable import RemoteConfigEditor

struct AppConfigTests {

    @Test("저장소의 app-config.json 을 원문 바이트 그대로 다시 쓴다")
    func roundTripsRepositoryFile() throws {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "app-config.json")
        let original = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(AppConfig.self, from: original)

        #expect(Data(config.serialized().utf8) == original)
    }

    @Test("안내가 없으면 빈 배열, 종료일은 마지막 키, 슬래시는 이스케이프하지 않는다")
    func serializesEdgeShapes() throws {
        #expect(AppConfig.empty.serialized() == """
            {
              "$schema": "./schema.json",
              "version": 1,
              "minimumVersion": "",
              "notices": []
            }

            """)

        let notice = Notice(title: "점검 1/2", body: "줄\n바꿈 \"따옴표\"", until: "2026-12-31")
        let config = AppConfig(version: 1, minimumVersion: "2.3", notices: [notice])
        let serialized = config.serialized()

        #expect(serialized.contains("\"title\": \"점검 1/2\","))
        #expect(serialized.contains("\"until\": \"2026-12-31\"\n    }"))
        #expect(try JSONDecoder().decode(AppConfig.self, from: Data(serialized.utf8)) == config)
    }

    @Test("제목은 1~40자, 본문은 1~200자")
    func validatesLengths() {
        let fortyOne = String(repeating: "가", count: 41)
        #expect(!Notice(title: fortyOne, body: "본문").errors.isEmpty)
        #expect(Notice(title: String(fortyOne.dropLast()), body: "본문").errors.isEmpty)
        #expect(!Notice(title: "", body: "본문").errors.isEmpty)
        #expect(!Notice(title: "제목", body: String(repeating: "가", count: 201)).errors.isEmpty)
    }

    @Test("길이는 jsonschema 처럼 코드 포인트로 센다")
    func countsLengthsInCodePoints() {
        let family = String(repeating: "👨‍👩‍👧", count: 10)
        #expect(family.count == 10)
        #expect(!Notice(title: family, body: "본문").errors.isEmpty)
        #expect(Notice(title: String(repeating: "가", count: 40), body: "본문").errors.isEmpty)
    }

    @Test(
        "종료일은 실제 있는 yyyy-MM-dd 날짜만 허용",
        arguments: [
            ("2026-09-20", true),
            ("2026/09/20", false),
            ("2026-02-30", false),
            ("2026-9-20", false),
        ]
    )
    func validatesUntil(until: String, isValid: Bool) {
        #expect(Notice(title: "제목", body: "본문", until: until).errors.isEmpty == isValid)
    }

    @Test(
        "최소 버전은 비우거나 숫자와 점 세 자리까지",
        arguments: [
            ("", true),
            ("2.3", true),
            ("2.3.0", true),
            ("v2.3", false),
            ("2.3.0.1", false),
        ]
    )
    func validatesMinimumVersion(value: String, isValid: Bool) {
        let config = AppConfig(version: 1, minimumVersion: value, notices: [])
        #expect((config.minimumVersionError == nil) == isValid)
    }
}
