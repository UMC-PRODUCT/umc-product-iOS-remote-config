import Foundation
import Testing
@testable import RemoteConfigEditor

struct ApplyRequestTests {
    @Test("필수 입력과 종료 미정 선택을 검증하고 요청 내용을 보존한다")
    @MainActor func requestValidationAndBody() {
        var request = ApplyRequest()
        #expect(!request.isComplete)
        request.reason = "DB 점검"
        request.scope = "앱 전체"
        request.action = "이용 차단"
        request.title = "점검 중"
        request.body = "잠시 기다려 주세요.\n다시 안내할게요."
        request.applyTiming = "즉시"
        #expect(!request.isComplete)
        request.endUnknown = true
        #expect(request.isComplete)
        #expect(request.markdown.contains("종료 시점 미정"))
        #expect(request.markdown.contains(request.body))
        request.endUnknown = false
        request.expectedEnd = "오늘 18시"
        #expect(request.isComplete)
        #expect(request.markdown.contains("오늘 18시"))
        for field in [\ApplyRequest.reason, \.scope, \.action, \.title, \.body, \.applyTiming, \.expectedEnd] {
            var incomplete = request
            incomplete[keyPath: field] = " \n "
            #expect(!incomplete.isComplete)
        }
    }

    @Test("최종 확인은 변경한 안내만 미리 채우고 배포를 시작하지 않는다")
    @MainActor func beginsWithRequest() {
        let model = EditorModel()
        model.draft.notices = [Notice(screen: .home, enabled: true, template: .blocking,
                                      title: "홈 점검", body: "잠시 기다려 주세요")]
        model.beginApply()
        #expect(model.isApplySheetPresented)
        #expect(model.applyPhase == .confirming)
        #expect(model.applyRequest.scope == "홈 탭")
        #expect(model.applyRequest.action.contains("이용 차단"))
        #expect(model.applyRequest.title == "홈 점검")
        #expect(!model.applyRequest.isComplete)
        model.applyRequest.reason = "점검"
        model.beginApply()
        #expect(model.applyRequest.reason == "점검")
        model.draft = AppConfig(version: 1, minimumVersion: "2.3", notices: [])
        model.beginApply()
        #expect(model.applyRequest.scope == "앱 전체")
        #expect(model.applyRequest.action.contains("최소 버전 변경: 2.3"))
        #expect(model.applyRequest.reason.isEmpty)
        #expect(model.applyRequest.title.contains("해당 없음"))
    }
}
