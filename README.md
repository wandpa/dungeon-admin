# dungeon-admin

던전우상향 관리자 웹 화면입니다 (Flutter Web). 회원 관리, 회원 모니터링, 종목 마스터, 푸시 알림, 공지사항, 관리자 활동 기록을 다룹니다.

## 저장소

| 구분 | 주소 | 브랜치 |
| --- | --- | --- |
| 관리자 웹 (이 저장소) | https://github.com/wandpa/dungeon-admin | `main` (작업 브랜치 `feature/member-monitoring`) |
| 관리자 API (.NET) | https://github.com/wandpa/dungeon-admin-api | `main` |

```sh
git clone https://github.com/wandpa/dungeon-admin.git
git clone https://github.com/wandpa/dungeon-admin-api.git
```

API 실행 방법은 API 저장소의 `README.md`, 요청·응답 형식은 `docs/API_DESIGN.md`에 있습니다. 개발 요청 체크리스트는 [노션 「던전 관리자 요구사항 분석」](https://app.notion.com/p/410c997e54ef80e9a866f5a468e3a3f2)에 있습니다.

## 실행

```sh
flutter pub get
flutter run -d web-server --web-port 8081 --web-hostname localhost
```

- 브라우저에서 `http://localhost:8081/`을 엽니다.
- 관리자 API가 먼저 떠 있어야 합니다. 기본 주소는 `http://localhost:5185/api/admin`입니다.
- API 주소를 바꾸려면 `--dart-define=ADMIN_API=https://…/api/admin`을 붙입니다.
- 웹 배포용 빌드: `flutter build web --dart-define=ADMIN_API=<운영 주소>`

## 로그인

로그인 화면의 계정 버튼을 누르면 아이디가 채워지고, 비밀번호는 직접 입력합니다. 모든 샘플 계정의 비밀번호는 `11111111`입니다.

| 아이디 | 이름 | 역할 |
| --- | --- | --- |
| `admin` | 김대표 | 최고 관리자 (모든 권한) |
| `operator` | 이운영 | 운영자 |
| `cs` | 박상담 | 상담 |
| `cs2` | 최퇴사 | 상담 (사용 중지) |

- 지금 계정과 비밀번호는 화면 코드에 있는 샘플입니다(`lib/mock_admin.dart`). 화면은 같은 아이디로 API에서 토큰을 받는데, 이때 API의 고정 비밀번호를 씁니다(`lib/live_api.dart`).
- 실제 관리자 로그인은 `admin_users` 테이블이 생긴 뒤 바꿉니다(체크리스트 B-2, C-1).
- 토큰이 만료되면 자동으로 다시 로그인하지 않습니다. 로그인 화면으로 돌아가고 안내 문구가 나옵니다. 로그인 요청이 너무 많으면 API가 주는 안내(429)를 그대로 보여 줍니다.

## 데이터

앱을 실행하면 테스트 DB 조회 모드로 시작합니다(`lib/main.dart`의 `useLiveData`).

| 구분 | 데이터 | 화면 |
| --- | --- | --- |
| 테스트 DB 조회 | API `/api/admin/live` → `signaltoday_dev` | 대시보드, 회원 목록·상세, 회원 모니터링, 전체 회원, 종목 마스터, 푸시 알림 이력 |
| 샘플 | 화면 메모리 (`lib/mock_*.dart`) | 공지사항, 관리자 계정·활동 기록, 상담 |

- 테스트 DB는 **조회만** 합니다. 저장 버튼과 입력칸은 "저장 API 연결 전" 안내만 하거나 비활성입니다. DB 쓰기는 서버 관리자 승인 뒤에 엽니다(체크리스트 G-1).
- 샘플 화면은 위쪽에 샘플 안내가 나옵니다. 값은 새로고침하면 사라집니다.
- 실서버 DB(`signal`)에는 연결하지 않습니다.
- 개인정보는 API가 가려서 줍니다(이메일, 이름, 계좌번호). 이메일 전체 보기와 엑셀 내보내기는 API가 기록을 남깁니다.

## 주요 화면

| 메뉴 | 파일 | 내용 |
| --- | --- | --- |
| 대시보드 | `pages/dashboard_live.dart`, `dashboard_page.dart` | 회원·매매 현황, 확인이 필요한 회원, 주문 금액 |
| 회원 관리 › 회원 목록 | `pages/members_page.dart`, `member_edit_panel.dart` | 검색, 상태 필터, 상세, 엑셀 내보내기 |
| 회원 관리 › 회원 모니터링 | `pages/member_monitor_*.dart` | 회원 한 명의 워커·잡·거래·포지션·로그·계좌·알림. 사용자 앱과 같은 항목으로 보여 줍니다 |
| 회원 관리 › 전체 회원 | `pages/live_workers_table.dart` | 전체 회원의 워커·알람·거래·포지션·로그·계좌·신호 등을 서버 페이지로 조회 |
| 종목 마스터 | `pages/live_symbol_page.dart`, `live_market_hours.dart` | 국내·해외선물 종목, 거래소별 장 시간 |
| 푸시 알림 | `pages/live_notifications_page.dart` | 회원이 받은 알림 이력. 발송은 API 연결 전 |
| 공지사항, 관리자 | `pages/notices_page.dart`, `admin_users_page.dart` | 샘플 |

그 밖의 파일:

- `lib/live_api.dart`: API 호출과 응답 변환. 로그인 토큰, 페이지 조회, 실전·모의·알람 구분, 손익 표시
- `lib/admin_shell.dart`: 상단 메뉴, 열린 탭, 하단 상태줄
- `lib/view_store*.dart`: 화면 설정 저장(브라우저 localStorage). 예: 회원 모니터링의 실전·모의·알람 체크

## 화면 규칙

- 실전·모의·알람은 **계좌 종류** 기준으로 나눕니다. 알람 계좌는 주문을 내지 않으므로 실전 합계에서 뺍니다.
- DB에 없는 값은 `-`로 둡니다. 추정한 값을 채우지 않습니다.
- 자동 갱신은 하지 않습니다. 화면의 재조회 버튼으로 다시 불러옵니다.
- 목록은 서버에서 페이지를 나눠 받습니다(한 쪽 50건). 합계는 현재 쪽이 아니라 조건 전체 기준입니다.

## 테스트

```sh
flutter analyze
flutter test
```

테스트는 API를 흉내 낸 응답으로 돌아가므로 API 서버 없이 실행됩니다.

## 남은 일

체크리스트에 담당별로 정리되어 있습니다. 화면 쪽에서는 아래가 API를 기다리고 있습니다.

- 관리자 계정·실제 로그인, 활동 기록 저장 (C-1, B-1)
- 회원 처리(승인·정지·차단), 회원 정보·등급 저장, 상담 저장 (B, C-2)
- 공지·푸시 발송 (D-4, D-5)
- 장 시간 저장 (B, E-1)
- 현재가와 평가손익 (D-6)
