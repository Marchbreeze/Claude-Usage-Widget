# Claude Usage Widget

macOS 메뉴바에서 Claude 사용량을 실시간으로 확인하는 경량 앱입니다.  
아이콘 + 진행 막대 + 퍼센트로 한눈에 현황을 파악할 수 있습니다.

<!-- 스크린샷 자리 -->

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

## 구독 모드 (기본값)

Claude Code의 OAuth 세션을 읽어 **5시간 세션 사용률**을 표시합니다.

**요구사항**

- [Claude Code](https://claude.ai/code) 설치 후 `claude` 명령으로 로그인되어 있어야 합니다.
- 최초 실행 시 키체인 접근 허용 다이얼로그가 표시됩니다.  
  **"항상 허용"** 을 선택하면 이후 매번 묻지 않습니다.

---

## API 모드

Anthropic Admin API 키를 사용해 **이번 달 API 지출**을 예산 대비 퍼센트로 표시합니다.

**설정 방법**

1. 메뉴바 아이콘 클릭 → **설정…**
2. "표시할 사용량"을 **API (Admin 키)** 로 변경합니다.
3. [Anthropic Console](https://console.anthropic.com/settings/admin-keys) 에서 Admin API 키를 발급한 뒤 입력합니다.
4. 월 예산(USD)을 입력합니다 (기본값: $200).
5. **저장** 버튼을 누릅니다.

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
