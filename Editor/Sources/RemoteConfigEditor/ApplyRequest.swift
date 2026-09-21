import Foundation

struct ApplyRequest {
    var reason = ""
    var scope = ""
    var action = ""
    var title = ""
    var body = ""
    var applyTiming = "즉시"
    var expectedEnd = ""
    var endUnknown = false

    var isComplete: Bool {
        let required = [reason, scope, action, title, body, applyTiming]
            + (endUnknown ? [] : [expectedEnd])
        return required.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var markdown: String {
        [
            ("요청 사유", reason),
            ("대상 범위", scope),
            ("요청 작업", action),
            ("안내 제목", title),
            ("안내 본문", body),
            ("적용 시점", applyTiming),
            ("종료 예상 시점", endUnknown ? "종료 시점 미정" : expectedEnd),
        ].map { "### \($0.0)\n\n\($0.1.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n\n")
            + "\n\n점검이 끝나면 해제 요청도 꼭 전달해주세요."
    }
}
