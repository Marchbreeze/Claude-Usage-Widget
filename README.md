# Claude Usage Widget

macOS 메뉴바에서 Claude 사용량을 실시간으로 확인하는 경량 앱입니다.  
아이콘 + 진행 막대 + 퍼센트로 한눈에 현황을 파악할 수 있습니다.

| 정상 (80% 이하) | 경고 (80% 초과) |
|:---:|:---:|
| ![normal](assets/screenshot-normal.png) | ![warning](assets/screenshot-warning.png) |

---

## 다운로드

1. [Releases](https://github.com/Marchbreeze/Claude-Usage-Widget/releases) 페이지에서 최신 `ClaudeUsageWidget.zip`을 내려받습니다.
2. 압축을 풀고 `ClaudeUsageWidget.app`을 `/Applications` 폴더로 이동합니다.

---

## 첫 실행 (무서명 앱 허용)

Apple 공증을 받지 않은 앱이므로 처음 실행 시  
"악성 코드가 없음을 확인할 수 없습니다"라는 경고와 함께 차단됩니다.

**방법 1 — 시스템 설정에서 허용 (권장)**

1. 앱을 더블클릭합니다. 경고 창이 뜨면 **"완료"** 를 클릭합니다 (휴지통으로 이동 ❌).
2. **시스템 설정 → 개인정보 보호 및 보안**으로 이동합니다.
3. 아래로 스크롤하면 *"ClaudeUsageWidget이(가) 차단되었습니다"* 항목이 보입니다.  
   옆의 **"그래도 열기(Open Anyway)"** 버튼을 클릭합니다.
4. Touch ID 또는 비밀번호로 확인한 뒤, 다시 **열기**를 클릭합니다.

**방법 2 — 터미널**

```bash
xattr -cr /Applications/ClaudeUsageWidget.app
open /Applications/ClaudeUsageWidget.app
```

이 과정은 컴퓨터당 최초 1회(또는 앱 업데이트 후 1회)만 필요합니다.  
실행하면 Dock에는 나타나지 않고 **메뉴바 우측 상단**에 아이콘이 생깁니다.

---

## 사용 방법

Claude Code의 OAuth 세션을 읽어 **5시간 세션 사용률**을 표시합니다.  
엔터프라이즈 계정처럼 세션 한도가 없는 경우에는 **추가 사용량(extra usage)** 을 예산 대비 퍼센트로 표시합니다.

**요구사항**

- [Claude Code](https://claude.ai/code) 설치 후 `claude` 명령으로 로그인되어 있어야 합니다.

별도의 API 키 입력이나 설정은 필요하지 않습니다. 로그인되어 있으면 자동으로 동작합니다.

### 키체인 접근 허용 (비밀번호 2번 입력)

이 앱은 사용량을 가져오기 위해 Claude Code가 macOS 키체인에 저장해 둔 로그인 토큰(`Claude Code-credentials` 항목)을 읽습니다. 토큰은 키체인 밖으로 나가지 않으며, 오직 `api.anthropic.com`에 사용량을 요청할 때만 사용됩니다.

최초 실행 시 비밀번호(또는 Touch ID) 입력 창이 **두 번** 뜨는데, 둘 다 정상입니다.

1. **첫 번째 — 읽기 허용**: ClaudeUsageWidget은 Claude Code와 서로 다른 앱(코드 서명이 다름)이라, macOS가 다른 앱이 만든 키체인 항목에 접근하려 할 때 보호 차원에서 허용 여부를 묻습니다.
2. **두 번째 — "항상 허용" 등록**: 창에서 **"항상 허용(Always Allow)"** 을 누르면 macOS가 해당 키체인 항목의 *접근 허용 목록(ACL)* 에 이 앱을 추가하는데, ACL을 수정하는 작업 자체가 다시 한 번 인증을 요구하기 때문에 비밀번호를 또 묻습니다.

두 번 모두 승인하면 이후 실행부터는 더 이상 묻지 않습니다. (**"허용"** 만 누르면 ACL에 등록되지 않아 다음 실행 때 다시 물어보니, **"항상 허용"** 을 권장합니다.)

---

## 색상 의미

| 색상 | 의미 |
|------|------|
| 주황 (`#D97757`) | 정상 범위 (0 – 80%) |
| 빨강 (`#E5484D`) | 80% 초과 |
| 회색 | 데이터 없음 또는 로딩 중 |

퍼센트가 흐릿하게 표시되면 마지막 데이터를 캐시에서 읽어 온 것입니다 (네트워크 오류 등).

---

## 직접 빌드

Xcode Command Line Tools와 Swift 5.9 이상이 필요합니다.

```bash
git clone https://github.com/Marchbreeze/Claude-Usage-Widget.git
cd Claude-Usage-Widget
bash scripts/make_app.sh
# → build/ClaudeUsageWidget.zip 생성
```

---

## 라이선스

MIT — 자세한 내용은 [LICENSE](LICENSE) 파일을 참고하세요.
