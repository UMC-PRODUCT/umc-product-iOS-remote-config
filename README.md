# umc-product-iOS-remote-config

[umc-product-iOS](https://github.com/UMC-PRODUCT/umc-product-iOS) 앱이 **원격으로 읽어가는 설정 저장소**입니다.

앱을 새로 배포하지 않아도 특정 화면에 안내를 켜거나 끄고, 문구를 바꾸고, 강제 업데이트 기준 버전을 올릴 수 있습니다.
App Store 심사와 사용자 업데이트를 기다릴 필요가 없습니다.

> **현재 상태:** iOS 앱 연동 작업은 아직 진행 중입니다([UMC-PRODUCT/umc-product-iOS#1389](https://github.com/UMC-PRODUCT/umc-product-iOS/issues/1389)). 이 저장소의 값을 바꿔도 지금은 앱 동작이 바뀌지 않습니다.

## 앱이 읽는 주소

```
https://umc-product.github.io/umc-product-iOS-remote-config/app-config.json
```

GitHub Pages 로 서빙되며 캐시가 10분입니다. **머지 후 최대 10분 뒤에 앱에 반영**됩니다.

- 주소를 읽지 못하면 앱은 마지막으로 받은 값을 그대로 씁니다
- 한 번도 받은 적이 없으면 아무것도 막지 않습니다. 점검 안내와 강제 업데이트가 모두 꺼진 것으로 봅니다

## 파일

| 파일 | 설명 |
|---|---|
| `app-config.json` | 실제 설정. 이것만 고치면 됩니다 |
| `schema.json` | 값의 규칙. 오타·잘못된 값을 걸러냅니다 |
| `.github/workflows/validate.yml` | PR 마다 위 규칙으로 검사 |

## 고치는 방법

1. `app-config.json` 을 열고 오른쪽 위 **연필 아이콘** 클릭
2. 값 수정
3. 아래에서 **Create a new branch for this commit and start a pull request** 선택 → **Propose changes**
4. `validate` 검사가 통과하면 머지
5. 10분 안에 앱에 반영

되돌리려면 그 PR 페이지의 **Revert** 버튼을 누르면 됩니다.

> 저장소 화면에서 키보드 `.` 을 누르면 브라우저에 편집기가 열립니다. 자동완성과 오류 표시가 있어 실수를 줄일 수 있습니다.

## 설정 값

```json
{
  "$schema": "./schema.json",
  "version": 1,
  "minimumVersion": "",
  "notices": [
    {
      "screen": "pendingApproval",
      "enabled": false,
      "template": "INFO",
      "title": "가입 승인이 늦어지고 있어요",
      "body": "지금 가입 신청이 많아 승인까지 시간이 더 걸릴 수 있어요. 승인되면 바로 이용할 수 있으니 조금만 기다려주세요.",
      "until": "2026-12-31"
    }
  ]
}
```

`$schema` 줄은 편집기 자동완성에 쓰입니다. 건드리지 마세요.

| 필드 | 필수 | 설명 |
|---|---|---|
| `version` | O | 설정 형식 번호. **항상 `1`** 입니다. 앱이 모르는 값이면 설정 전체를 무시합니다 |
| `minimumVersion` | O | 강제 업데이트 기준 버전. 아래 설명 참고 |
| `notices` | O | 화면 안내 목록. 안내가 하나도 없으면 `[]` |

`notices` 안의 안내 하나하나는 아래 필드로 적습니다.

| 필드 | 필수 | 설명 |
|---|---|---|
| `screen` | O | 어느 화면에 띄울지 |
| `enabled` | O | `true` 면 노출, `false` 면 숨김. **평소에는 `false` 로 두고 필요할 때만 켭니다** |
| `template` | O | 안내 모양 |
| `title` | O | 제목 (40자 이내) |
| `body` | O | 본문 (200자 이내) |
| `until` | X | `YYYY-MM-DD`. **이 날짜 당일까지** 뜨고, 그 뒤로는 자동으로 안 뜹니다 |

- `until` 형식이 틀리면(`2026/09/20` 등) `validate` 검사에서 막힙니다. 혹시 그대로 반영되더라도 앱은 그 안내를 띄우지 않습니다

### `minimumVersion` 에 쓸 수 있는 값

이 버전보다 낮은 앱은 **업데이트 화면으로 막힙니다.**

| 값 | 동작 |
|---|---|
| `""` (빈 값) | 강제 업데이트를 하지 않습니다 |
| `2.3.0` 또는 `2.3` | 이 버전보다 낮은 앱을 막습니다 |

- 패치 자리(`2.3.1` 의 마지막 `1`)까지 비교합니다. `2.3.1` 로 올리면 `2.3.0` 앱이 막힙니다
- `v2.3.0` 처럼 숫자와 점 말고 다른 글자가 섞이면 `validate` 검사에서 막힙니다
- 앱은 App Store 최신 버전과 앞 두 자리(`2.3` 같은 Major.Minor)가 다르면 **이 값과 상관없이** 업데이트를 요구합니다. 그러니 이 값은 **패치 업데이트(`2.3.0` → `2.3.1`)를 강제할 때만** 올리면 됩니다

### `screen` 에 쓸 수 있는 값

대소문자까지 표와 똑같이 적어야 합니다. `ALL` 만 대문자이고 나머지는 소문자로 시작합니다(`Home` 이 아니라 `home`).

| 구분 | 값 | 화면 |
|---|---|---|
| 전체 | `ALL` | **모든 화면**. 앱을 켜는 순간부터 적용됩니다 |
| 시작 | `login` | 로그인 |
| | `signUp` | 회원가입 |
| | `pendingApproval` | 가입 승인 대기 |
| 탭 | `home` | 홈 탭 |
| | `notice` | 공지 탭 |
| | `activity` | 활동 탭 |
| | `community` | 커뮤니티 탭 |
| | `mypage` | 마이페이지 탭 |

- 앱 시작 화면(로그인 상태를 확인하는 화면)은 금방 지나가서 쓸 수 없습니다. 앱을 켜자마자 띄우려면 `ALL` 을 쓰세요
- 탭 안에서 들어간 화면(공지 상세, 글 작성 등)은 따로 지정할 수 없습니다. **그 탭 전체**로 봅니다. 예를 들어 `notice` 는 공지 상세·작성 화면에서도 적용됩니다

### `template` 에 쓸 수 있는 값

| 값 | 모양 |
|---|---|
| `INFO` | 제목 + 본문 + 확인 버튼. 닫으면 앱을 다시 켜기 전까지 또 뜨지 않습니다 |
| `BLOCKING` | 탭바까지 덮는 전체 화면. **닫을 수 없고, 버튼 없이 안내 문구만** 보입니다. 점검처럼 이용을 막아야 할 때 씁니다 |

- iOS 앱은 스스로 종료할 수 없어서 Android 판과 달리 "앱 종료" 버튼이 없습니다
- `ALL` + `BLOCKING` 조합이 **서비스 점검(킬스위치)** 입니다
- 같은 화면에 `BLOCKING` 과 `INFO` 가 함께 걸리면 `BLOCKING` 이 먼저 뜹니다
- `BLOCKING` 은 사용자가 풀 수 없습니다. **점검이 끝나면 반드시 `enabled` 를 `false` 로 되돌리거나 `until` 을 걸어두세요**
- 앱은 다시 열거나 백그라운드에서 돌아올 때 설정을 새로 확인합니다. 점검을 끝내도 이미 막힌 사용자는 앱을 다시 열거나 백그라운드에 갔다 돌아와야 풀립니다

#### 예시: 점검 안내

`app-config.json` 에 아래 안내가 꺼진 상태로 이미 들어 있습니다. 점검할 때는 `enabled` 를 `true` 로 바꾸고 필요하면 `until` 을 추가하세요.

```json
{
  "screen": "ALL",
  "enabled": true,
  "template": "BLOCKING",
  "title": "서비스 점검 중이에요",
  "body": "더 나은 서비스를 위해 점검하고 있어요. 잠시 후 다시 이용해주세요.",
  "until": "2026-09-20"
}
```

## Firebase 에서 옮기는 동안

이미 배포된 구버전 앱은 이 저장소가 아니라 **Firebase Remote Config** 를 계속 읽습니다.
새 버전 사용자 비율이 충분해질 때까지는 점검·최소 버전을 바꿀 때 **Firebase 콘솔과 이 저장소를 둘 다** 고치세요.

| 이 저장소 | Firebase 콘솔 키 |
|---|---|
| `ALL` + `BLOCKING` 안내의 `enabled` | `maintenance_enabled` |
| 같은 안내의 `title` | `maintenance_title` |
| 같은 안내의 `body` | `maintenance_message` |
| `minimumVersion` | `ios_min_version` |

- Firebase 에는 `until` 이 없습니다. 점검이 끝나면 `maintenance_enabled` 를 직접 `false` 로 꺼야 합니다
- 구버전이 정리되면 Firebase 콘솔에서 위 키를 삭제하고 이 섹션도 지웁니다

## 주의

- **비밀값을 넣지 마세요.** 공개 저장소라 누구나 읽을 수 있습니다. 토큰·비밀번호·내부 주소는 금지입니다
- 위 표에 없는 값을 쓰면 `validate` 검사에서 막힙니다
- `main` 은 보호돼 있어 직접 커밋할 수 없습니다. 항상 PR 로 올라갑니다

<!-- HUMANIZE-SUMMARY v1.6.1
run_id: 2026-09-17-001
metrics:
  char_in: 4642
  char_out: 4638
  change_rate: 0.1%
  self_check: 6/6
  grade: B
categories:  # before → after
  C-11 연결어미 뒤 쉼표 (산문·목록 문장): 8 → 4
  A-10 '~할 수 있다' (긍정형): 2 → 2 (남발 아님, 보존)
  J-1 볼드 강조: 보존 (운영 가이드의 경고 강조, 구조 보존 지침)
  C-2 연속 불릿: 보존 (README 목록 구조, 구조 보존 지침)
  D·H·I·G 카테고리: 0 → 0
self_check:
  - 고유명사·수치·인용 100% 보존: ✅
  - 변경률 30% 이하: ✅
  - 장르 이탈 없음: ✅
  - register 보존: ✅ (~습니다/~세요 유지)
  - S1 잔존 0건: ✅ (C-11 잔존 4건은 트리거 기준 6회 미만, 의도적 보존)
  - 인공 표현 추가 없음: ✅ (쉼표 삭제만 수행, 어휘 변경 0)
highlights:
  - id: C-11
    before: "`ALL` 만 대문자이고, 나머지는 소문자로 시작합니다"
    after: "`ALL` 만 대문자이고 나머지는 소문자로 시작합니다"
  - id: C-11
    before: "iOS 앱은 스스로 종료할 수 없어서, Android 판과 달리"
    after: "iOS 앱은 스스로 종료할 수 없어서 Android 판과 달리"
  - id: C-11
    before: "`enabled` 를 `true` 로 바꾸고, 필요하면 `until` 을 추가하세요."
    after: "`enabled` 를 `true` 로 바꾸고 필요하면 `until` 을 추가하세요."
  - id: C-11
    before: "Firebase 콘솔에서 위 키를 삭제하고, 이 섹션도 지웁니다"
    after: "Firebase 콘솔에서 위 키를 삭제하고 이 섹션도 지웁니다"
residual_findings:
  - C-11 (S1, 트리거 미달): "켜거나 끄고, 문구를 바꾸고," 3항 나열 쉼표 2건 — 나열 가독성용이라 보존
  - C-11 (S1, 트리거 미달): "**닫을 수 없고, 버튼 없이 안내 문구만**" — 볼드 구간 내부라 보존
  - C-11 (S1, 트리거 미달): until 행 "뜨고, 그 뒤로는" — 표 셀이라 구조 보존 지침에 따라 보존
grade_reason: "B — S1 0건(트리거 기준), 자체검증 6항 통과. 원문이 이미 깔끔해(risk_band low) 변경률 0.1%로 A 구간(10~25%) 미달. 마크다운 구조·필드명·URL·버전 숫자 무변경."
-->
