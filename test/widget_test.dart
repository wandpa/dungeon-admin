import 'package:dungeon_admin/admin_shell.dart';
import 'package:dungeon_admin/main.dart';
import 'package:dungeon_admin/mock_accounts.dart';
import 'package:dungeon_admin/mock_admin.dart';
import 'package:dungeon_admin/mock_consultations.dart';
import 'package:dungeon_admin/mock_data.dart';
import 'package:dungeon_admin/mock_symbols.dart';
import 'package:dungeon_admin/mock_system.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 회원 모니터링의 흐름 탭으로 옮긴다. 로그 화면의 같은 이름 칩보다 위쪽 탭이 먼저다.
Future<void> flowTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ChoiceChip, label).first);
  await tester.pumpAndSettle();
}

Future<void> pickAccount(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<String?>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    resetMockAdmins();
    resetMockMembers();
    resetMockNotices();
    resetSentPushes();
    resetMockConsultations();
    resetMockIncidents();
    resetMockSymbols();
    signIn('admin', samplePassword);
  });

  testWidgets('넓은 화면: 사이드바 메뉴로 모든 화면을 오갈 수 있다', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AdminApp());
    expect(find.text('오늘의 던전 현황과 회사 전체 전략·잡·주문을 한눈에 봅니다.'), findsOneWidget);

    const pages = {
      '회원 관리': 'risingkang',
      '푸시 알림': '오늘의 던전이 열렸습니다',
      '공지사항': '던전우상향 정식 출시 안내',
      '종목 마스터': '주문 가능',
      '관리자': '활동 기록',
      '대시보드': '오늘 발생 신호',
    };
    for (final MapEntry(key: menu, value: content) in pages.entries) {
      await tester.tap(find.widgetWithText(AdminMenuItem, menu));
      await tester.pumpAndSettle();
      expect(find.text(content), findsWidgets, reason: menu);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('모니터링: 뒤로 버튼으로 잡 내역에서 회원 목록까지 나오고 위치 표시로도 나온다', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(AdminMenuItem, '회원 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '회원 모니터링'));
    await tester.pumpAndSettle();

    Future<void> open() async {
      await tester.tap(find.text('MCLZ26'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('돌파 매수 전략'));
      await tester.pumpAndSettle();
      expect(find.text('돌파 매수 전략 상세'), findsOneWidget);
    }

    await open();
    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('마이크로 WTI 원유 12월물 잡'), findsOneWidget);
    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('risingkang 워커'), findsOneWidget);
    expect(find.text('MCLZ26'), findsOneWidget);

    // 워커 목록에서 뒤로 가면 회원 목록이다.
    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('뒤로'), findsNothing);
    expect(find.text('엑셀 내보내기'), findsOneWidget);
    expect(find.text('risingkang'), findsNWidgets(2)); // 보던 회원이 오른쪽 패널에 남는다
    await tester.tap(find.widgetWithText(ChoiceChip, '회원 모니터링'));
    await tester.pumpAndSettle();

    // 거래 탭에서는 워커 목록으로 돌아간다.
    await flowTab(tester, '거래');
    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('risingkang 워커'), findsOneWidget);

    // 위치 표시를 눌러도 빈 화면에 남지 않는다.
    await open();
    await tester.tap(find.widgetWithText(TextButton, '마이크로 WTI 원유 12월물'));
    await tester.pumpAndSettle();
    expect(find.text('마이크로 WTI 원유 12월물 잡'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '전체 워커'));
    await tester.pumpAndSettle();
    expect(find.text('MCLZ26'), findsOneWidget);
  });

  testWidgets('열린 화면 탭: 대시보드도 닫고, 끌어서 순서를 바꾸며, 다 닫으면 대시보드로 돌아간다', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    expect(find.byTooltip('대시보드 닫기'), findsNothing); // 대시보드 하나뿐이면 닫을 것이 없다

    await tester.tap(find.widgetWithText(AdminMenuItem, '공지사항'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AdminMenuItem, '회원 관리'));
    await tester.pumpAndSettle();

    double x(String tab) => tester.getTopLeft(find.byKey(ValueKey(tab))).dx;
    expect(x('대시보드'), lessThan(x('공지사항')));
    expect(x('공지사항'), lessThan(x('회원 관리')));

    // 맨 뒤 탭을 맨 앞으로 끈다.
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('회원 관리'))));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(x('회원 관리'), lessThan(x('대시보드')));

    await tester.tap(find.byTooltip('대시보드 닫기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('대시보드')), findsNothing);

    await tester.tap(find.byTooltip('회원 관리 닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('공지사항 닫기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('대시보드')), findsOneWidget);
    expect(find.byTooltip('대시보드 닫기'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('시작 화면: 로그인하면 던전 관리자를 1초 보여 주고 대시보드로 넘어간다', (tester) async {
    signOut();
    showStartScreen = true;
    addTearDown(() => showStartScreen = false);
    await tester.pumpWidget(const AdminApp());
    signIn('admin', samplePassword);
    await tester.pump();
    expect(find.text('던전 관리자'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('던전 관리자'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('던전 관리자'), findsNothing);
    expect(find.widgetWithText(AdminMenuItem, '대시보드'), findsOneWidget);
  });

  testWidgets('공지: 분류, 노출 대상, 앱 팝업을 정해 게시한다', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(AdminMenuItem, '공지사항'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('공지 작성'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '이벤트'));
    await tester.tap(find.widgetWithText(FilterChip, 'VIP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '제목'), 'VIP 이벤트');
    await tester.enterText(find.widgetWithText(TextField, '내용'), '내용');
    await tester.pumpAndSettle();
    expect(find.text('미리보기 · 이벤트'), findsOneWidget);
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(find.text('미리보기 · 이벤트 · 앱 팝업'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '임시저장'));
    await tester.pumpAndSettle();

    final saved = mockNotices.firstWhere((n) => n.title == 'VIP 이벤트');
    expect(saved.category, '이벤트');
    expect(saved.audience, 'VIP');
    expect(saved.popup, isTrue);
  });

  testWidgets('로그인: 계정 버튼은 아이디만 채우고 비밀번호를 넣어야 들어간다', (tester) async {
    signOut();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(ActionChip, '상담 직원'));
    await tester.pumpAndSettle();
    final password = tester.widget<TextField>(find.widgetWithText(TextField, '비밀번호'));
    expect(password.controller!.text, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(find.text('아이디 또는 비밀번호가 맞지 않습니다.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), '11111111');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(signedInAdmin.value?.role, AdminRole.consultant);
  });

  testWidgets('좁은 화면: 위쪽 메뉴를 밀어서 이동한다', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AdminApp());
    await tester.ensureVisible(find.widgetWithText(AdminMenuItem, '공지사항'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AdminMenuItem, '공지사항'));
    await tester.pumpAndSettle();

    expect(find.text('던전우상향 정식 출시 안내'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원 모니터링: 워커 → 잡 → 잡 내역 → 거래 → 포지션 → 로그 순서로 이어진다', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000); // 내용이 스크롤 없이 다 만들어지게
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(AdminMenuItem, '회원 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '회원 모니터링'));
    await tester.pumpAndSettle();

    // 처음에는 워커 목록만 크게 나온다. 승인 대기 회원은 목록에 없다.
    for (final label in ['워커', '잡', '잡 내역', '거래', '포지션', '로그', '계좌', '알림']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget, reason: label);
    }
    expect(find.text('risingkang 워커'), findsOneWidget);
    expect(find.text('newbie_slime'), findsNothing);
    expect(find.textContaining('실행 5 / 7'), findsOneWidget);
    expect(find.text('TSLA'), findsOneWidget);
    expect(find.textContaining('+7,000', findRichText: true), findsOneWidget); // 앱 카드처럼 줄 안에 손익이 있다
    expect(find.text('[계좌 해외선물 메인 외 1]'), findsOneWidget); // 잡마다 계좌가 달라도 어느 계좌인지 보인다
    expect(find.textContaining('+35T +\$70', findRichText: true), findsOneWidget);

    // 워커를 누르면 잡으로 넘어가고 위치가 표시된다. 워커 설정도 같이 나온다.
    await tester.tap(find.text('MCLZ26'));
    await tester.pumpAndSettle();
    expect(find.text('마이크로 WTI 원유 12월물 잡'), findsOneWidget);
    expect(find.text('마이크로 WTI 원유 12월물 워커 설정'), findsOneWidget);
    expect(find.text('전체 워커'), findsOneWidget);
    expect(find.text('마이크로 WTI 원유 12월물'), findsWidgets);
    expect(find.text('장 마감 시 자동 청산'), findsOneWidget);
    expect(find.text('누적 손익으로 워커 종료'), findsOneWidget);
    expect(find.text('일 · 매일 장 시작 10분 전'), findsOneWidget);
    expect(find.text('+\$500 이상'), findsOneWidget);
    expect(find.text('−\$300 이하'), findsOneWidget);
    expect(find.text('오늘 누적 손익 · 청산 2회'), findsOneWidget);
    expect(find.textContaining('평가 포함 +\$210'), findsOneWidget); // 실현 140 + 평가 70

    // 잡을 누르면 잡 내역으로 넘어간다. 팝업 없이 설정과 이력이 함께 나온다.
    await tester.tap(find.text('돌파 매수 전략'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('돌파 매수 전략 상세'), findsOneWidget);
    expect(find.text('· 돌파'), findsOneWidget);
    expect(find.text('진입설정'), findsOneWidget);
    expect(find.text('청산설정'), findsOneWidget);
    expect(find.text('현재가 대비'), findsOneWidget);
    expect(find.text('+10틱'), findsOneWidget);
    expect(find.text('지정가'), findsOneWidget);
    expect(find.text('체결 내역'), findsOneWidget);
    expect(find.text('주문 5건 · 체결 5건 · 거부 0건'), findsOneWidget);
    expect(find.text('+40'), findsOneWidget); // 체결 내역은 회차마다 한 줄이다
    expect(find.textContaining('· 청산 10/'), findsWidgets); // 진입·청산 시각이 초까지 나온다

    // 회차마다 상세를 누르면 그 회차의 로그가 펼쳐진다.
    await tester.ensureVisible(find.widgetWithText(TextButton, '상세').first);
    await tester.tap(find.widgetWithText(TextButton, '상세').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('회차 상세 로그'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '접기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('회차 상세 로그'), findsNothing);
    expect(find.text('1회차'), findsOneWidget);
    expect(find.text('실현손익 +\$100.00'), findsOneWidget); // 회차 손익 합이 잡 실현손익이다
    expect(find.text('실현손익 +\$40.00'), findsOneWidget);
    expect(find.text('체결 2계약 @\$100.75'), findsOneWidget); // 앱과 같은 표기
    expect(find.textContaining('10/30 10:02:41'), findsWidgets);
    expect(find.text('사이클 종료'), findsNWidgets(2));

    // 거래·포지션·로그는 고른 잡으로 좁혀진다.
    await flowTab(tester, '거래');
    expect(find.text('마이크로 WTI 원유 12월물 (MCLZ26)'), findsOneWidget);
    expect(find.text('삼성전자 (005930)'), findsNothing);
    await flowTab(tester, '포지션');
    expect(find.text('보유 포지션 1'), findsOneWidget);
    await flowTab(tester, '로그');
    expect(find.text('고객 로그 · 돌파 매수 전략'), findsOneWidget);
    expect(find.text('마이크로 WTI 원유 12월물 매수 2계약 체결 @100.75'), findsOneWidget);
    expect(find.text('고점 이탈 알람 감시 시작'), findsNothing);

    // 위치를 누르면 범위가 풀린다.
    await tester.tap(find.text('마이크로 WTI 원유 12월물'));
    await tester.pumpAndSettle();
    expect(find.text('고객 로그 · 마이크로 WTI 원유 12월물'), findsOneWidget);
    expect(find.text('마이크로 WTI 원유 12월물 워커 시작'), findsOneWidget);
    await tester.tap(find.text('전체 워커'));
    await tester.pumpAndSettle();
    expect(find.text('고객 로그 · 전체'), findsOneWidget);
    expect(find.text('삼성전자 워커 시작'), findsOneWidget);
    expect(find.text('Android 앱 로그인'), findsWidgets);

    // 알람 잡도 설정을 볼 수 있다.
    await flowTab(tester, '워커');
    await tester.tap(find.text('MCLZ26'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고점 이탈 알람'));
    await tester.pumpAndSettle();
    expect(find.text('신호 조건'), findsOneWidget);
    expect(find.text('AND 볼린저밴드(20, 2) 상단 이탈'), findsOneWidget);
    expect(find.text('아직 이력이 없어요'), findsOneWidget);

    // 끝난 잡은 종료된 전략 탭에 있고, 카드와 상세에서 거부 사유를 볼 수 있다.
    await flowTab(tester, '잡');
    await tester.tap(find.text('종료된 전략'));
    await tester.pumpAndSettle();
    expect(find.text('돌파 매수 전략'), findsNothing);
    expect(find.text('주문 가능 금액 부족'), findsOneWidget);
    await tester.tap(find.text('갭 상승 진입'));
    await tester.pumpAndSettle();
    expect(find.text('· 갭 트레이딩'), findsOneWidget);
    expect(find.text('매수 거부 · 주문 가능 금액 부족'), findsOneWidget);

    // 회원을 바꾸면 워커부터 다시 시작한다. 틱 기준과 비정상종료가 그대로 드러난다.
    await tester.tap(find.text('uptrend99'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('NQZ26'));
    await tester.pumpAndSettle();
    expect(find.text('−400틱 이하'), findsOneWidget);
    expect(find.textContaining('-125틱'), findsWidgets);
    expect(find.text('사용 안 함'), findsWidgets);
    await tester.tap(find.text('종료된 전략'));
    await tester.pumpAndSettle();
    expect(find.text('비정상종료'), findsOneWidget);
    await flowTab(tester, '로그');
    await tester.tap(find.widgetWithText(ChoiceChip, '오류').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('잔고 불일치 감지'), findsOneWidget);
    expect(find.text('Android 앱 로그인'), findsNothing);

    await tester.tap(find.text('f_rank_trader'));

    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(find.text('등록한 워커가 없습니다.'), findsOneWidget);
    await flowTab(tester, '잡');
    expect(find.text('워커를 선택하세요.'), findsNWidgets(2));
    await flowTab(tester, '잡 내역');
    expect(find.text('잡을 선택하세요.'), findsOneWidget);
    await flowTab(tester, '로그');
    expect(find.text('로그가 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원 모니터링: 모드와 포지션, 계좌, 알림을 탭으로 본다', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000); // 내용이 스크롤 없이 다 만들어지게
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(AdminMenuItem, '회원 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '회원 모니터링'));
    await tester.pumpAndSettle();

    expect(find.text('실매매'), findsOneWidget);

    // 포지션: 잡 포지션과 수동 포지션이 함께 나온다.
    await flowTab(tester, '포지션');
    expect(find.text('보유 포지션 5'), findsOneWidget);
    expect(find.text('수동'), findsOneWidget);
    expect(find.textContaining('LG에너지솔루션'), findsOneWidget);

    // 계좌: 잔고와 주문 내역.
    await flowTab(tester, '계좌');
    expect(find.text('계좌 5개'), findsOneWidget);
    expect(find.text('통화별 총자산'), findsOneWidget);
    expect(find.text('거부 1'), findsOneWidget);
    expect(find.text('미체결 0'), findsOneWidget);
    expect(find.text('주문 가능 금액 부족'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '거부 1'));
    await tester.pumpAndSettle();
    expect(find.text('체결완료'), findsNothing);
    expect(find.text('거부'), findsOneWidget);

    // 계좌를 고르면 그 계좌만 나오고 계좌번호는 가린다.
    expect(find.text('해외주식 · ****3404 · KIS'), findsOneWidget);
    await tester.tap(find.text('국내주식 연습'));
    await tester.pumpAndSettle();
    expect(find.text('주문 내역'), findsOneWidget);
    await flowTab(tester, '포지션');
    expect(find.text('보유 포지션 2'), findsOneWidget);

    // 알림: 진단에서 막힌 곳이 앱 문구로 보인다.
    await tester.tap(find.text('uptrend99'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await flowTab(tester, '알림');
    expect(find.text('푸시 알림 허용'), findsOneWidget);
    expect(find.text('푸시가 나갈 곳이 없습니다'), findsOneWidget);
    expect(find.text('읽지 않음 2'), findsOneWidget);
    expect(find.textContaining('나스닥100 12월물 매도 체결'), findsWidgets);

    await flowTab(tester, '워커');
    expect(find.text('uptrend99 워커'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원 모니터링: 계좌를 고르면 워커·잡·로그·알림이 그 계좌 기준으로 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000); // 내용이 스크롤 없이 다 만들어지게
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(AdminMenuItem, '회원 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '회원 모니터링'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MCLZ26'));
    await tester.pumpAndSettle();
    expect(find.text('돌파 매수 전략'), findsOneWidget);
    expect(find.text('눌림목 소액 매수'), findsOneWidget); // 한 워커에 계좌가 다른 잡이 섞여 있다

    // 서브 계좌: 그 계좌의 잡만 남는다. 워커 전체 기준인 누적 손익은 그대로다.
    await pickAccount(tester, '해외선물 서브 ****3405');
    expect(find.text('눌림목 소액 매수'), findsOneWidget);
    expect(find.text('돌파 매수 전략'), findsNothing);
    expect(find.textContaining('+\$140'), findsWidgets);
    expect(find.textContaining('평가 포함 +\$210'), findsOneWidget);
    await flowTab(tester, '워커');
    expect(find.text('005930'), findsNothing);
    expect(find.textContaining('실행 1 / 1'), findsOneWidget);
    await flowTab(tester, '로그');
    expect(find.text('Android 앱 로그인'), findsNothing);

    // 메인 계좌: 체결 로그가 나오고, 고른 계좌는 알림 탭에도 그대로 적용된다.
    await pickAccount(tester, '해외선물 메인 ****3401');
    expect(find.text('마이크로 WTI 원유 12월물 매수 2계약 체결 @100.75'), findsOneWidget);
    await flowTab(tester, '알림');
    expect(find.textContaining('삼성전자 매수 체결'), findsNothing);
    expect(find.textContaining('마이크로 금 12월물 매도 체결'), findsOneWidget);
    await pickAccount(tester, '전체 계좌');
    expect(find.textContaining('삼성전자 매수 체결'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원 모니터링: 문제 요약을 눌러 이동하고 상담 메모를 남긴다', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(AdminMenuItem, '회원 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '회원 모니터링'));
    await tester.pumpAndSettle();

    // 실전과 모의 손익은 합치지 않는다.
    expect(find.textContaining('실전 +360 USD · +225,000 KRW · +2,500 HKD · 모의 +7,000 KRW'), findsOneWidget);

    // 회원 목록에 문제가 보이고, 없는 회원은 없다고 나온다.
    expect(find.text('워커 4개 · 실행 2 · 문제 3', findRichText: true), findsOneWidget);
    await tester.tap(find.text('f_rank_trader'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(find.text('확인할 문제가 없습니다.'), findsOneWidget);

    // 오류 워커를 누르면 그 워커로 간다. 오류 워커는 목록 맨 위에 있다.
    await tester.tap(find.text('uptrend99'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(find.text('푸시 서버 미등록'), findsOneWidget);
    await tester.tap(find.text('오류 워커 1'));
    await tester.pumpAndSettle();
    expect(find.text('나스닥100 12월물 잡'), findsOneWidget);

    // 미체결을 누르면 계좌·주문 탭의 미체결로 간다.
    await tester.tap(find.text('미체결 주문 1'));
    await tester.pumpAndSettle();
    expect(find.text('주문 내역'), findsOneWidget);
    expect(find.text('접수'), findsNWidgets(2)); // 미체결 주문 + 접수 상태의 상담
    expect(find.text('체결완료'), findsNothing);

    await tester.tap(find.text('푸시 서버 미등록'));
    await tester.pumpAndSettle();
    expect(find.text('푸시가 나갈 곳이 없습니다'), findsOneWidget);

    // 상담은 보고 있던 워커와 함께 기록되고 회사 전체 상담 이력에도 나온다.
    await tester.enterText(find.widgetWithText(TextField, '상담 내용 입력'), '잔고 불일치 문의 접수');
    await tester.tap(find.byTooltip('상담 기록 추가'));
    await tester.pumpAndSettle();
    expect(find.text('잔고 불일치 문의 접수'), findsOneWidget);
    final added = mockConsultations.first;
    expect(added.content, '잔고 불일치 문의 접수');
    expect(added.username, 'uptrend99');
    expect(added.adminName, '김대표');
    expect(added.status, ConsultStatus.open);
    expect(added.channel, ConsultChannel.phone);
    expect(mockActivities.first.kind, ActivityKind.consult);
    expect(tester.takeException(), isNull);
  });

  testWidgets('푸시: 전체·그룹·사용자 검색으로 대상을 골라 보낸다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(AdminMenuItem, '푸시 알림'));
    await tester.pumpAndSettle();

    // 전체: 받을 수 없는 회원은 이유와 함께 제외한다.
    expect(find.text('6명에게 보내기'), findsOneWidget);
    expect(find.textContaining('quietbuyer(푸시 거부)'), findsOneWidget);
    expect(find.textContaining('uptrend99(푸시 서버 미등록)'), findsOneWidget);

    // 특정 그룹
    await tester.tap(find.widgetWithText(ChoiceChip, '특정 그룹'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '해외선물 사용 4'));
    await tester.pumpAndSettle();
    expect(find.text('3명에게 보내기'), findsOneWidget);

    // 사용자 검색: 찾아서 추가하고 뺄 수 있다.
    await tester.tap(find.widgetWithText(ChoiceChip, '사용자 검색'));
    await tester.pumpAndSettle();
    expect(find.text('0명에게 보내기'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '아이디·이메일 검색'), 'rising');
    await tester.pumpAndSettle();
    await tester.tap(find.text('risingkang'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '아이디·이메일 검색'), 'bottom');
    await tester.pumpAndSettle();
    await tester.tap(find.text('bottomhunter'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(find.text('2명에게 보내기'), findsOneWidget);

    // 제목과 내용이 있어야 보낼 수 있고, 확인 뒤 이력에 남는다.
    final send = find.widgetWithText(FilledButton, '2명에게 보내기');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, '제목'), '서버 점검 안내');
    await tester.enterText(find.widgetWithText(TextField, '내용'), '오늘 밤 점검합니다.');
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '보내기'));
    await tester.pumpAndSettle();
    expect(find.text('서버 점검 안내'), findsOneWidget);
    expect(find.text('risingkang 외 1명'), findsOneWidget);
    expect(find.text('2명에게 보냈습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('공지: 작성·수정·게시 중단·고정·삭제와 푸시 동시 발송', (tester) async {
    tester.view.physicalSize = const Size(2400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(AdminMenuItem, '공지사항'));
    await tester.pumpAndSettle();
    expect(find.text('게시 3'), findsOneWidget);
    expect(find.text('예약 1'), findsOneWidget);
    expect(find.text('임시저장 1'), findsOneWidget);

    // 작성: 패널이 화면 안에 열리고, 입력하면 미리보기에 바로 나온다. 팝업이 아니다.
    await tester.tap(find.text('공지 작성'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    final publish = find.widgetWithText(FilledButton, '게시하기');
    expect(tester.widget<FilledButton>(publish).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, '제목'), '새 공지 제목');
    await tester.enterText(find.widgetWithText(TextField, '내용'), '새 공지 내용');
    await tester.pumpAndSettle();
    expect(find.text('새 공지 제목'), findsNWidgets(2)); // 입력칸 + 미리보기

    // 게시하면서 푸시도 보낸다.
    final pushes = mockPushes.length;
    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();
    await tester.tap(publish);
    await tester.pumpAndSettle();
    expect(find.textContaining('6명에게 푸시도 보냅니다'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '게시'));
    await tester.pumpAndSettle();
    expect(find.text('게시 4'), findsOneWidget);
    expect(mockPushes.length, pushes + 1);
    expect(mockPushes.first.sentCount, 6);

    // 수정
    await tester.tap(find.text('새 공지 제목'));
    await tester.pumpAndSettle();
    expect(find.text('공지 수정 · #42'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '새 공지 제목').first, '고친 제목');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '수정 저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '게시'));
    await tester.pumpAndSettle();
    expect(find.text('고친 제목'), findsOneWidget);

    // 게시 중단: 임시저장으로 돌아간다.
    await tester.tap(find.byTooltip('게시 중단').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '게시 중단'));
    await tester.pumpAndSettle();
    expect(find.text('게시 3'), findsOneWidget);
    expect(find.text('임시저장 2'), findsOneWidget);

    // 상단 고정: 고정 공지가 맨 위로 온다.
    await tester.tap(find.byTooltip('상단 고정').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('고정 해제'), findsNWidgets(2));

    // 검색과 필터
    await tester.enterText(find.widgetWithText(TextField, '제목·내용 검색'), '정기 점검');
    await tester.pumpAndSettle();
    expect(find.text('11월 정기 점검 안내'), findsOneWidget);
    expect(find.text('고친 제목'), findsNothing);

    // 삭제
    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 공지가 없습니다.'), findsOneWidget);
    expect(mockNotices.where((n) => n.id == 37), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('대시보드: 전략·잡 수와 통화별 주문 금액을 보여 준다', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.pumpAndSettle();

    expect(find.text('전체 회원'), findsOneWidget); // 기존 지표는 그대로다
    expect(find.text('전체 전략'), findsOneWidget);
    expect(find.text('현재 잡'), findsOneWidget);
    expect(find.text('종목별 현재 잡'), findsOneWidget);
    expect(find.text('전략별 현재 잡'), findsOneWidget);
    expect(find.text('마이크로 WTI 원유 12월물'), findsOneWidget);

    // 오늘: 국내선물 113,025,000 + 현대차 1,247,500. 모의 삼성전자와 어제 체결은 빠진다.
    expect(find.text('KRW 체결 금액'), findsOneWidget);
    expect(find.text('USD 체결 금액'), findsOneWidget);
    expect(find.text('114,272,500'), findsOneWidget);

    // 전체 기간: 어제의 삼성전자 489,000 이 더해진다.
    await tester.tap(find.widgetWithText(ChoiceChip, '전체'));
    await tester.pumpAndSettle();
    expect(find.text('114,761,500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> openMenu(WidgetTester tester, String menu) async {
    tester.view.physicalSize = const Size(2400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.pumpAndSettle();
    if (menu == '회원 모니터링') {
      await tester.tap(find.widgetWithText(AdminMenuItem, '회원 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '회원 모니터링'));
    } else {
      await tester.tap(find.widgetWithText(AdminMenuItem, menu));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('대시보드: 문제 목록에서 그 회원의 문제 위치로 바로 간다', (tester) async {
    await openMenu(tester, '대시보드');
    expect(find.textContaining('확인이 필요한 회원'), findsOneWidget);
    expect(find.text('오류 워커 1'), findsOneWidget);

    await tester.tap(find.text('푸시 서버 미등록'));
    await tester.pumpAndSettle();
    expect(find.text('uptrend99 워커'), findsNothing); // 워커 탭이 아니라 알림 탭이 열린다
    expect(find.text('푸시가 나갈 곳이 없습니다'), findsOneWidget);
    expect(mockActivities.first.text, 'uptrend99 회원 모니터링 열람');
  });

  testWidgets('회원: 내보내기, 재설정 메일, 상세에서 푸시로 이어진다', (tester) async {
    await openMenu(tester, '회원 관리');
    await tester.tap(find.text('엑셀 내보내기'));
    await tester.pumpAndSettle();
    expect(mockActivities.first.text, '회원 12명 내보내기');

    await tester.tap(find.text('uptrend99'));

    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('비밀번호 재설정 메일'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '보내기'));
    await tester.pumpAndSettle();
    expect(mockMembers.firstWhere((m) => m.username == 'uptrend99').history.first.text, '비밀번호 재설정 메일 발송');

    await tester.tap(find.text('푸시 보내기'));
    await tester.pumpAndSettle();
    expect(find.text('새 알림 보내기'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'uptrend99'), findsOneWidget);
    expect(find.textContaining('uptrend99(푸시 서버 미등록)'), findsOneWidget);
  });

  testWidgets('회원 처리: 승인·정지·휴면 내역이 처리자·대상·상태 변화와 함께 남는다', (tester) async {
    await openMenu(tester, '회원 관리');
    await tester.tap(find.text('uptrend99'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('휴면 전환'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '휴면 전환'));
    await tester.pumpAndSettle();
    expect(find.text('휴면 해제'), findsOneWidget);
    expect(mockActivities.first.text, 'uptrend99 휴면 전환 (정상 → 휴면)');

    await tester.tap(find.text('휴면 해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이용 정지'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '정지 사유 (회원에게 안내됩니다)'), '약관 위반');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '정지'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AdminMenuItem, '관리자'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '회원 처리'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '관리자·회원·내용 검색'), 'uptrend99');
    await tester.pumpAndSettle();
    expect(find.text('uptrend99 이용 정지 7일 (약관 위반) (정상 → 정지)'), findsOneWidget);
    expect(find.text('uptrend99 휴면 해제 (휴면 → 정상)'), findsOneWidget);
    expect(find.text('uptrend99 휴면 전환 (정상 → 휴면)'), findsOneWidget);
    expect(find.text('김대표'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('상담 이력: 경로·유형·잡과 함께 기록하고 상태를 바꾸며 전체 목록에서 찾는다', (tester) async {
    await openMenu(tester, '회원 모니터링');

    // 과거 처리 이력은 지금 로그인한 사람이 아니라 실제 처리자로 나온다.
    expect(find.text('2026-10-29 21:30 · 이운영'), findsOneWidget);

    // 기존 상담의 연결을 누르면 그 잡으로 간다.
    await tester.tap(find.text('마이크로 WTI 원유 12월물 · 갭 상승 진입'));
    await tester.pumpAndSettle();
    expect(find.text('갭 상승 진입 상세'), findsOneWidget);
    expect(find.text('연결: 마이크로 WTI 원유 12월물 · 갭 상승 진입'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '상담 내용 입력'), '입금 후 재시도 안내');
    await tester.tap(find.byTooltip('상담 기록 추가'));
    await tester.pumpAndSettle();
    expect(find.text('입금 후 재시도 안내'), findsOneWidget);
    expect(mockConsultations.first.jobName, '갭 상승 진입');
    expect(mockConsultations.first.workerId, 501);

    // 상태를 완료로 바꾸면 처리자와 전후 상태가 남는다.
    await tester.tap(find.widgetWithText(ChoiceChip, '상담 이력'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AdminMenuItem, '상담 이력'), findsNothing); // 회원 관리 안에 있다
    expect(find.text('접수 2'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '회원·내용·담당자 검색'), '입금 후 재시도');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<ConsultStatus>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('완료').last);
    await tester.pumpAndSettle();
    expect(mockConsultations.first.status, ConsultStatus.done);
    expect(mockConsultations.first.handledBy, '김대표');
    expect(mockActivities.first.text, 'risingkang 상담 #6 (접수 → 완료)');

    // 회원을 누르면 모니터링으로 간다.
    await tester.tap(find.text('risingkang'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(find.text('risingkang 워커'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('잡: 앱처럼 실행 슬롯·중지됨·대기열로 나누고 전략별 설정을 보여 준다', (tester) async {
    await openMenu(tester, '회원 모니터링');
    await tester.tap(find.text('bottomhunter'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('000660'));
    await tester.pumpAndSettle();

    expect(find.text('완료 시 다음 잡 자동 시작'), findsOneWidget);
    expect(find.text('대기열'), findsNWidgets(3)); // 머리글 + 대기 잡 2개의 상태

    // 트레일링 진입: 앱 설정 항목과 트레일링 스탑 값이 나온다.
    await tester.tap(find.text('눌림목 반등'));
    await tester.pumpAndSettle();
    expect(find.text('· 트레일링 진입'), findsOneWidget);
    expect(find.text('진입 간격'), findsOneWidget);
    expect(find.text('추종 폭'), findsOneWidget);
    expect(find.text('1회차 2% · 2회차 4%'), findsOneWidget);

    // 꺼진 잡은 중지됨에 있고, 틱 단위 손절이 그대로 보인다.
    await tester.tap(find.text('risingkang'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('005930'));
    await tester.pumpAndSettle();
    expect(find.text('중지됨'), findsWidgets);
    expect(find.text('꺼져 있어 매매하지 않습니다'), findsOneWidget);
    await flowTab(tester, '워커');
    await tester.tap(find.text('MCLZ26'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('돌파 매수 전략'));
    await tester.pumpAndSettle();
    expect(find.text('-25'), findsOneWidget); // 앱처럼 손절은 음수, 단위는 Tick
    expect(find.text('Tick'), findsWidgets);
    expect(find.text('평가 시점'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('시스템 상태: 대시보드 경보에서 이동해 장애를 확인·해결한다', (tester) async {
    await openMenu(tester, '대시보드');
    expect(find.widgetWithText(AdminMenuItem, '시스템 상태'), findsNothing); // 대시보드 안의 탭으로 옮겼다
    expect(find.widgetWithText(AdminMenuItem, '신호 관리'), findsNothing);
    expect(find.text('시스템 모니터링'), findsOneWidget);
    expect(find.text('국내 수신'), findsOneWidget);
    expect(find.text('해외 수신'), findsOneWidget);
    expect(find.text('정상'), findsWidgets);
    expect(find.text('지연'), findsOneWidget); // 증권사 연결
    expect(find.textContaining('장애 2건 처리 중'), findsOneWidget);
    await tester.tap(find.text('시스템 상태 보기'));
    await tester.pumpAndSettle();
    expect(find.text('전체 상태: 지연'), findsOneWidget);
    expect(find.text('KIS 해외선물 실전'), findsWidgets);
    expect(find.text('푸시 발송 중단'), findsNothing); // 해결된 장애는 기본으로 숨긴다

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(mockIncidents.first.status, IncidentStatus.acknowledged);
    expect(mockIncidents.first.handledBy, '김대표');
    expect(mockActivities.first.kind, ActivityKind.system);

    await tester.tap(find.text('해결').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '해결'));
    await tester.pumpAndSettle();
    expect(find.text('해외선물 주문 응답 지연'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, '해결된 장애 포함'));
    await tester.pumpAndSettle();
    expect(find.text('푸시 발송 중단'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('종목 마스터: 시간을 고치면 확인 후 저장되고 변경 전후가 기록된다', (tester) async {
    await openMenu(tester, '종목 마스터');
    expect(find.text('국내선물 2'), findsOneWidget);
    expect(find.text('해외선물 5'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, '국내선물 2'));
    await tester.pumpAndSettle();
    expect(find.text('코스피200'), findsOneWidget);
    expect(find.text('나스닥100'), findsNothing);
    expect(find.text('장 시간'), findsOneWidget);
    expect(find.text('08:45~15:45'), findsNWidgets(2)); // 장 시작~장 종료
    expect(find.text('08:30~15:45'), findsNWidgets(2)); // 주문 가능

    // 형식이 틀리면 저장할 수 없다. 팝업이 아니라 화면 안에서 고친다.
    await tester.tap(find.byTooltip('수정').first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('상품 수정 · 101'), findsOneWidget);
    expect(find.text('250000'), findsOneWidget); // 계약승수는 틱 가치 ÷ 틱 크기
    expect(find.text('장 시작'), findsWidgets);
    final fields = find.byType(TextField);
    Finder field(String value) => find.descendant(of: fields, matching: find.text(value));
    await tester.enterText(field('08:45').first, '25:00');
    await tester.pumpAndSettle();
    expect(find.text('시간은 09:00 형식으로 입력하세요.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '저장')).onPressed, isNull);

    await tester.enterText(field('25:00').first, '09:00');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('장 시작 08:45 → 09:00'), findsOneWidget);
    expect(find.textContaining('워커 1개의 주문과 청산에 바로 적용됩니다'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await tester.pumpAndSettle();
    expect(mockSymbols.first.sessionOpen, '09:00');
    expect(mockActivities.first.kind, ActivityKind.symbol);
    expect(mockActivities.first.text, '101 장 시작 08:45 → 09:00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('종목 마스터: 상품과 항목을 체크해 일괄 적용하고 상품별 전후가 남는다', (tester) async {
    await openMenu(tester, '종목 마스터');
    expect(find.text('일괄 적용'), findsNothing);

    // 국내선물 전체를 체크한다.
    await tester.tap(find.widgetWithText(FilterChip, '국내선물 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('일괄 적용 · 선택한 상품 2개'), findsOneWidget);
    expect(find.text('101, 106'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '일괄 적용')).onPressed, isNull);

    // 장 시작만 체크해 값을 넣는다. 형식이 틀리면 적용할 수 없다.
    await tester.tap(find.widgetWithText(FilterChip, '장 시작'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '08:45'), '9시');
    await tester.pumpAndSettle();
    expect(find.text('장 시작은(는) 09:00 형식으로 입력하세요.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '9시'), '09:00');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '일괄 적용'));
    await tester.pumpAndSettle();
    expect(find.text('일괄 적용 · 상품 2개'), findsOneWidget);
    expect(find.textContaining('101: 장 시작 08:45 → 09:00'), findsOneWidget);
    expect(find.textContaining('워커 1개의 주문과 청산에 바로 적용됩니다'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '적용'));
    await tester.pumpAndSettle();

    final domestic = mockSymbols.where((s) => s.marketType == '국내선물');
    expect(domestic.every((s) => s.sessionOpen == '09:00'), isTrue);
    expect(domestic.every((s) => s.sessionClose == '15:45'), isTrue); // 체크하지 않은 항목은 그대로
    expect(mockSymbols.firstWhere((s) => s.productCode == 'MCL').sessionOpen, '07:00');
    expect(mockActivities.first.text, '106 일괄 적용: 장 시작 08:45 → 09:00');
    expect(mockActivities[1].text, '101 일괄 적용: 장 시작 08:45 → 09:00');
    expect(find.text('일괄 적용'), findsNothing); // 끝나면 선택이 풀린다
    expect(tester.takeException(), isNull);
  });

  testWidgets('종목 마스터: 서머타임은 버튼 하나로 시작·종료한다', (tester) async {
    await openMenu(tester, '종목 마스터');
    expect(find.text('미국 서머타임 적용 중'), findsOneWidget);
    expect(find.text('유럽 서머타임 미적용'), findsOneWidget);

    // 상품이나 항목을 고르지 않고 버튼만 누른다. 바뀔 시간은 확인창에 나온다.
    await tester.tap(find.text('미국 서머타임 종료하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('상품 3개의 시간을 1시간 늦춥니다'), findsOneWidget);
    expect(find.textContaining('MCL  07:00~06:00 → 08:00~07:00'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '적용'));
    await tester.pumpAndSettle();

    final mcl = mockSymbols.firstWhere((s) => s.productCode == 'MCL');
    expect(mcl.sessionOpen, '08:00');
    expect(mcl.sessionClose, '07:00');
    expect(mcl.orderOpen, '08:00');
    expect(mcl.orderClose, '07:00');
    expect(mcl.breakTime, '07:00-08:00');
    expect(mcl.holidays, '2026-11-26');
    expect(mockSymbols.firstWhere((s) => s.productCode == '101').sessionOpen, '08:45'); // 국내는 그대로
    expect(mockSymbols.firstWhere((s) => s.productCode == 'HSI').sessionOpen, '10:15'); // 서머타임 없는 해외도 그대로
    expect(mockSymbols.firstWhere((s) => s.productCode == 'FESX').sessionOpen, '09:10'); // 유럽도 그대로
    expect(mockActivities.first.text, 'MGC 미국 서머타임 종료: 장 시간 07:00~06:00 → 08:00~07:00');

    // 상태가 바뀌어 같은 전환을 두 번 할 수 없고, 다시 시작하면 원래대로 돌아온다.
    expect(find.text('미국 서머타임 미적용'), findsOneWidget);
    expect(find.text('미국 서머타임 종료하기'), findsNothing);
    await tester.tap(find.text('미국 서머타임 시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '적용'));
    await tester.pumpAndSettle();
    expect(mcl.sessionOpen, '07:00');
    expect(shiftTimes('23:30', 1), '00:30');
    expect(tester.takeException(), isNull);
  });

  testWidgets('종목 마스터: 상품을 고르면 월물 테이블이 나오고 월물을 관리한다', (tester) async {
    await openMenu(tester, '종목 마스터');
    expect(find.text('월물 추가'), findsNothing);

    await tester.tap(find.text('마이크로 WTI 원유'));
    await tester.pumpAndSettle();
    expect(find.text('마이크로 WTI 원유 (MCL) 월물 4개'), findsOneWidget);
    expect(find.text('MCLZ26'), findsOneWidget);
    expect(find.text('MCLF27'), findsOneWidget);
    expect(find.text('최근월물'), findsNWidgets(2)); // 표 머리글 + 최근월물 표시
    expect(find.text('차월물'), findsOneWidget);
    expect(find.text('차차월물'), findsOneWidget);
    expect(find.text('차차차월물'), findsOneWidget);
    expect(find.text('D-18'), findsOneWidget);

    // 장 시간과 거래 정보가 월물마다 나온다.
    expect(find.text('장 시작'), findsOneWidget);
    expect(find.text('장 종료'), findsOneWidget);
    expect(find.text('07:00'), findsNWidgets(5));
    expect(find.text('06:00'), findsNWidgets(5));
    expect(find.text('거래량'), findsOneWidget);
    expect(find.text('미결제약정'), findsOneWidget);
    expect(find.text('184,320'), findsOneWidget);
    expect(find.text('101.1'), findsOneWidget);

    // 형식이 맞아야 추가된다.
    await tester.enterText(find.widgetWithText(TextField, 'MCLH27'), 'MCLH27');
    await tester.enterText(find.widgetWithText(TextField, '202703'), '2027-03');
    await tester.pumpAndSettle();
    expect(find.text('월물은 202612 형식으로 입력하세요.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '2027-03'), '202703');
    await tester.enterText(find.widgetWithText(TextField, '2027-02-18'), '2027-02-18');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '월물 추가'));
    await tester.pumpAndSettle();
    expect(find.text('마이크로 WTI 원유 (MCL) 월물 5개'), findsOneWidget);
    expect(mockActivities.first.text, 'MCL 월물 추가 MCLH27 (202703, 만기 2027-02-18)');

    // 최근월물을 중지하면 다음 월물이 최근월물이 된다. 워커가 있으면 확인을 받는다.
    final mcl = mockSymbols.firstWhere((s) => s.productCode == 'MCL');
    expect(mcl.nearMonth!.code, 'MCLZ26');
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('이 월물을 쓰는 워커가 3개'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '사용 중지'));
    await tester.pumpAndSettle();
    expect(mcl.nearMonth!.code, 'MCLF27');
    expect(mcl.monthLabel(mcl.months.firstWhere((m) => m.code == 'MCLG27')), '차월물'); // 한 칸씩 올라온다
    expect(find.text('중지'), findsOneWidget); // 중지한 월물은 순서에서 빠진다

    // 만기일을 고치면 전후가 기록된다.
    await tester.tap(find.byTooltip('월물 수정').first);
    await tester.pumpAndSettle();
    expect(find.text('월물 수정 · MCLZ26'), findsOneWidget);

    // 월물만 시간을 다르게 줄 수 있고, 서머타임 전환 때 함께 옮겨진다.
    final monthOpen = find.widgetWithText(TextField, '07:00');
    await tester.enterText(monthOpen, '07:30');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '월물 저장'));
    await tester.pumpAndSettle();
    final z26 = mcl.months.firstWhere((m) => m.code == 'MCLZ26');
    expect(z26.sessionOpen, '07:30');
    expect(mcl.openOf(z26), '07:30');
    expect(mockActivities.first.text, 'MCLZ26 장 시작 07:00 → 07:30');

    await tester.tap(find.text('미국 서머타임 종료하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '적용'));
    await tester.pumpAndSettle();
    expect(z26.sessionOpen, '08:30');
    expect(mcl.sessionOpen, '08:00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('운영 정리: 상세 상담 선택, 임시 비밀번호, 필터, 체결 금액 고정, 전환일 알림', (tester) async {
    await openMenu(tester, '대시보드');
    expect(find.text('미국 서머타임 종료 D-2 · 종목 마스터에서 전환하세요'), findsOneWidget);

    // 지난 주문 금액은 체결 당시 승수로 고정된다.
    final before = orderTotals().first.filledAmount;
    mockSymbols.firstWhere((s) => s.productCode == '101').tickValue = 25000;
    expect(orderTotals().first.filledAmount, before);

    // 다섯 번째 월물부터는 순번으로 나온다.
    final mcl = mockSymbols.firstWhere((s) => s.productCode == 'MCL');
    mcl.months.add(ContractMonth('MCLK27', '202705', DateTime(2027, 4, 20)));
    expect(mcl.monthLabel(mcl.months.last), '5번째 월물');

    // 회원 상세에서 상담 경로와 유형을 고른다.
    await tester.tap(find.widgetWithText(AdminMenuItem, '회원 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('uptrend99'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<ConsultChannel>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이메일').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '상담·문의 내용을 남겨 두세요'), '메일 문의');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();
    expect(mockConsultations.first.channel, ConsultChannel.email);

    // 상담은 경로로 거르고 내용을 눌러 전체를 본다.
    await tester.tap(find.widgetWithText(ChoiceChip, '상담 이력'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 경로').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('카카오톡').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('총 1건'), findsOneWidget);
    await tester.tap(find.textContaining('갭 상승 진입 잡이'));
    await tester.pumpAndSettle();
    expect(find.text('상담 #5 · risingkang'), findsOneWidget);

    // 비밀번호를 초기화하면 임시 비밀번호가 한 번 보이고 기록에는 남지 않는다.
    await tester.tap(find.widgetWithText(AdminMenuItem, '관리자'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '계정 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('비밀번호 초기화').at(1));
    await tester.pumpAndSettle();
    expect(find.text('이운영 임시 비밀번호'), findsOneWidget);
    expect(find.text('이 화면에서 한 번만 보입니다. 본인에게 전달하세요.'), findsOneWidget);
    expect(mockActivities.first.text, '이운영 비밀번호 초기화');

    // 활동 기록을 처리자로 거른다.
    await tester.tap(find.widgetWithText(ChoiceChip, '활동 기록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 처리자').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('박상담').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('총 2건'), findsOneWidget);

    // 장애는 내용을 눌러 상세를 본다.
    await tester.tap(find.widgetWithText(AdminMenuItem, '대시보드'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '시스템'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('잔고 불일치 감지'));
    await tester.pumpAndSettle();
    expect(find.textContaining('잡 1개를 정지했습니다'), findsOneWidget);
    expect(find.textContaining('마지막 보고'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('종목 마스터: 형식이 틀린 휴식 구간은 일괄 적용할 수 없다', (tester) async {
    await openMenu(tester, '종목 마스터');
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '휴식 구간'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '12:00-13:00'), '점심');
    await tester.pumpAndSettle();
    expect(find.text('휴식 구간은 12:00-13:00 형식으로 입력하세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원 포지션: 전체 회원 포지션을 보고 거른 뒤 회원 계좌로 이동한다', (tester) async {
    await openMenu(tester, '회원 관리');
    await tester.tap(find.widgetWithText(ChoiceChip, '회원 포지션'));
    await tester.pumpAndSettle();
    expect(find.text('전체 9'), findsOneWidget);
    expect(find.text('수동 1'), findsOneWidget);
    expect(find.text('LG에너지솔루션'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, '수동 1'));
    await tester.pumpAndSettle();
    expect(find.text('삼성전자'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, '전체 9'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '회원·종목 검색'), 'tank');
    await tester.pumpAndSettle();
    expect(find.text('samsung_tank'), findsOneWidget);
    expect(find.text('LG에너지솔루션'), findsNothing);

    await tester.tap(find.text('samsung_tank'));
    await tester.pumpAndSettle();
    expect(find.text('보유 포지션 1'), findsOneWidget); // 그 회원의 계좌·주문 탭
    expect(tester.takeException(), isNull);
  });

  testWidgets('거래: 앱 내역처럼 보유와 주문을 함께 보고 거른다', (tester) async {
    await openMenu(tester, '회원 모니터링');
    await tester.tap(find.widgetWithText(ChoiceChip, '거래'));
    await tester.pumpAndSettle();

    // 보유 포지션 카드: 현재가·매입가·보유수량, 손익과 틱.
    expect(find.text('마이크로 WTI 원유 12월물 (MCLZ26)'), findsOneWidget);
    expect(find.text('\$101.1'), findsOneWidget);
    expect(find.text('\$100.75'), findsWidgets);
    expect(find.text('+\$70'), findsOneWidget);
    expect(find.text('+35T'), findsOneWidget);
    expect(find.text('보유수량'), findsWidgets);
    expect(find.text('매도수량'), findsOneWidget); // 항셍은 매도 보유

    await tester.tap(find.widgetWithText(ChoiceChip, '보유'));
    await tester.pumpAndSettle();
    expect(find.text('매수거부'), findsNothing);
    expect(find.text('보유수량'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, '거부'));
    await tester.pumpAndSettle();
    expect(find.text('매수거부'), findsOneWidget);
    expect(find.text('주문 가능 금액 부족'), findsOneWidget);
    expect(find.text('보유수량'), findsNothing);

    // 주문을 누르면 그 잡으로 간다.
    await tester.tap(find.text('매수거부'));
    await tester.pumpAndSettle();
    expect(find.text('갭 상승 진입 상세'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('푸시: 보낸 알림이 회원의 알림 이력에 남는다', (tester) async {
    await openMenu(tester, '푸시 알림');
    await tester.tap(find.widgetWithText(ChoiceChip, '사용자 검색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '아이디·이메일 검색'), 'rising');
    await tester.pumpAndSettle();
    await tester.tap(find.text('risingkang'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '제목'), '개별 안내');
    await tester.enterText(find.widgetWithText(TextField, '내용'), '확인 부탁드립니다.');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '1명에게 보내기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '보내기'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AdminMenuItem, '회원 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '회원 모니터링'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '알림'));
    await tester.pumpAndSettle();
    expect(find.text('개별 안내'), findsOneWidget);
    expect(find.text('확인 부탁드립니다.'), findsOneWidget);
  });

  testWidgets('고객 로그: 검색·기간으로 찾고 눌러서 잡으로 이동한다', (tester) async {
    await openMenu(tester, '회원 모니터링');
    await flowTab(tester, '로그');
    await tester.enterText(find.widgetWithText(TextField, '로그 검색'), '삼성전자');
    await tester.pumpAndSettle();
    expect(find.text('삼성전자 워커 시작'), findsOneWidget);
    expect(find.text('Android 앱 로그인'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, '로그 검색'), '');
    await tester.pumpAndSettle();

    await tester.tap(find.text('전체 기간'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('어제').last);
    await tester.pumpAndSettle();
    expect(find.text('마이크로 WTI 원유 12월물 워커 시작'), findsOneWidget);
    expect(find.text('삼성전자 워커 시작'), findsNothing);

    // 종료된 잡의 로그를 누르면 종료된 전략 탭과 잡 상세가 열린다.
    await tester.tap(find.textContaining('주문 가능 금액 부족'));
    await tester.pumpAndSettle();
    expect(find.text('갭 상승 진입 상세'), findsOneWidget);
    await flowTab(tester, '로그');
    expect(find.text('고객 로그 · 갭 상승 진입'), findsOneWidget);
    await flowTab(tester, '잡');
    expect(find.text('고점 이탈 알람'), findsNothing); // 종료된 전략 탭이 열려 있다

    // 주문을 눌러도 그 잡으로 간다.
    await flowTab(tester, '계좌');
    await tester.tap(find.textContaining('코스피200 12월물 매수'));
    await tester.pumpAndSettle();
    expect(find.text('장 초반 돌파 상세'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('로그인: 틀리면 막고, 권한에 따라 메뉴와 기능이 달라지며 활동이 남는다', (tester) async {
    tester.view.physicalSize = const Size(2400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    signOut();
    await tester.pumpWidget(const AdminApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '아이디'), 'cs');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), '0000');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(find.text('아이디 또는 비밀번호가 맞지 않습니다.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '아이디'), 'cs2');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), samplePassword);
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(find.text('사용이 중지된 계정입니다.'), findsOneWidget);

    // 상담 직원: 조회만 된다.
    await tester.tap(find.text('상담 직원'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), samplePassword);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('박상담'), findsOneWidget);
    expect(find.widgetWithText(AdminMenuItem, '관리자'), findsNothing);
    await tester.tap(find.widgetWithText(AdminMenuItem, '푸시 알림'));
    await tester.pumpAndSettle();
    expect(find.text('새 알림 보내기'), findsNothing);
    await tester.tap(find.widgetWithText(AdminMenuItem, '공지사항'));
    await tester.pumpAndSettle();
    expect(find.text('공지 작성'), findsNothing);
    await tester.tap(find.widgetWithText(AdminMenuItem, '종목 마스터'));
    await tester.pumpAndSettle();
    expect(find.text('상품 추가'), findsNothing);
    expect(find.byTooltip('수정'), findsNothing);
    expect(find.text('미국 서머타임 적용 중'), findsOneWidget); // 상태는 보인다
    expect(find.text('미국 서머타임 종료하기'), findsNothing);
    expect(find.byType(Checkbox), findsNothing); // 일괄 적용도 없다
    await tester.tap(find.text('코스피200'));
    await tester.pumpAndSettle();
    expect(find.text('101Z6'), findsOneWidget); // 월물 조회는 된다
    expect(find.text('월물 추가'), findsNothing);
    await tester.tap(find.widgetWithText(AdminMenuItem, '회원 관리'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, '차단'), findsNothing); // 목록의 차단 버튼도 숨긴다
    await tester.tap(find.text('uptrend99'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(find.text('이용 정지'), findsNothing);
    expect(find.text('이 권한은 조회와 상담 기록만 할 수 있습니다.'), findsOneWidget);

    await tester.tap(find.byTooltip('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그인'), findsOneWidget);

    // 최고 관리자: 활동 기록에 상담 직원의 접속이 남고, 계정을 관리한다.
    await tester.tap(find.text('최고 관리자'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), samplePassword);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AdminMenuItem, '관리자'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃'), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, '계정 관리'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '이름'), '신입');
    await tester.enterText(find.widgetWithText(TextField, '아이디'), 'new1');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();
    expect(find.text('new1'), findsOneWidget);
    expect(mockActivities.first.text, '신입(new1) 계정 추가 · 상담 직원');
    expect(tester.takeException(), isNull);
  });

  // 기본은 오른쪽 패널이 없는 너비다. 상세는 팝업으로 열린다.
  Future<void> openMembers(WidgetTester tester, {Size size = const Size(1190, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(AdminMenuItem, '회원 관리'));
    await tester.pumpAndSettle();
  }

  testWidgets('회원 관리: 모니터링 버튼으로 그 회원의 모니터링을 연다', (tester) async {
    await openMembers(tester);
    // 테스트 글꼴은 글자폭이 넓어 표가 옆으로 밀리므로 화면을 넓힌다.
    tester.view.physicalSize = const Size(2400, 900);
    await tester.pumpAndSettle();
    await tester.tap(find.text('모니터링').at(4)); // 승인 대기 회원은 버튼이 없다
    await tester.pumpAndSettle();
    expect(find.text('uptrend99 워커'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원 관리: 메뉴 하나에서 목록과 모니터링을 오가고 모니터링에서 회원을 처리한다', (tester) async {
    await openMembers(tester);
    expect(find.widgetWithText(AdminMenuItem, '회원 모니터링'), findsNothing); // 메뉴가 합쳐졌다
    expect(find.text('가입 승인을 기다리는 회원이 3명 있습니다.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '회원 모니터링'));
    await tester.pumpAndSettle();
    expect(find.text('risingkang 워커'), findsOneWidget);

    await tester.tap(find.text('회원 정보·처리'));
    await tester.pumpAndSettle();
    expect(find.text('휴면 전환'), findsOneWidget);
    await tester.tap(find.text('휴면 전환'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '휴면 전환'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(mockMembers.firstWhere((m) => m.username == 'risingkang').status, MemberStatus.dormant);
    expect(find.text('휴면'), findsWidgets); // 닫으면 모니터링 목록에도 바로 반영된다

    await tester.tap(find.widgetWithText(ChoiceChip, '회원 목록'));
    await tester.pumpAndSettle();
    expect(find.text('가입 승인을 기다리는 회원이 3명 있습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원: 승인 대기 회원을 골라 한 번에 승인한다', (tester) async {
    await openMembers(tester);
    expect(find.text('가입 승인을 기다리는 회원이 3명 있습니다.'), findsOneWidget);

    await tester.tap(find.text('승인 대기 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first); // 전체 선택
    await tester.pumpAndSettle();
    expect(find.text('3명 선택됨'), findsOneWidget);

    await tester.tap(find.text('선택 승인'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '승인'));
    await tester.pumpAndSettle();

    expect(find.text('승인 대기 0'), findsOneWidget);
    expect(mockMembers.where((m) => m.status == MemberStatus.pending), isEmpty);
    expect(mockMembers.firstWhere((m) => m.id == 1027).history.first.text, '가입 승인');
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원: 목록에서 접속을 차단하고 해제한다', (tester) async {
    await openMembers(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'uptrend99');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(TextButton, '차단')); // 좁은 창에서는 표를 옆으로 민다
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '차단'));
    await tester.pumpAndSettle();
    expect(find.textContaining('멈추지 않습니다'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, '차단');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, '차단 사유'), '계정 도용 의심');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    final m = mockMembers.firstWhere((m) => m.username == 'uptrend99');
    expect(m.accessBlocked, isTrue);
    expect(m.status, MemberStatus.active);
    expect(m.history.first.text, '접속 차단 (계정 도용 의심)');
    expect(issuesOf(m).any((i) => i.label == '접속 차단: 계정 도용 의심'), isTrue);
    expect(find.text('접속 차단'), findsOneWidget); // 상태 옆 표시. 버튼은 차단 해제로 바뀐다
    expect(find.text('접속 차단 1'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextButton, '해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '해제'));
    await tester.pumpAndSettle();
    expect(m.accessBlocked, isFalse);
    expect(m.history.first.text, '접속 차단 해제');
    expect(find.widgetWithText(TextButton, '차단'), findsOneWidget);
  });

  testWidgets('회원: 승인 전 회원은 접속 차단 대상이 아니다', (tester) async {
    await openMembers(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'newbie_slime');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, '차단'), findsNothing);
  });

  testWidgets('회원: 줄을 두 번 누르면 모니터링에서 그 회원의 워커가 열린다', (tester) async {
    await openMembers(tester);
    final row = find.text('bottomhunter');
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.text('bottomhunter 워커'), findsOneWidget);
    expect(find.text('000660'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원: 맨 왼쪽 칸에서 상세와 모니터링을 연다', (tester) async {
    await openMembers(tester);
    await tester.enterText(find.byType(TextField), 'bottomhunter');
    await tester.pumpAndSettle();
    final details = tester.getTopLeft(find.widgetWithText(TextButton, '상세'));
    final monitor = tester.getTopLeft(find.widgetWithText(TextButton, '모니터링'));
    expect(monitor.dx, lessThan(tester.getTopLeft(find.text('bottomhunter').last).dx));
    expect(details.dx, lessThan(monitor.dx));

    await tester.tap(find.widgetWithText(TextButton, '상세'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '모니터링'));
    await tester.pumpAndSettle();
    expect(find.text('bottomhunter 워커'), findsOneWidget);
  });

  testWidgets('회원 상세: 수정 칸이 있고 저장 API 전이라 값을 저장하지 않는다', (tester) async {
    await openMembers(tester, size: const Size(1400, 1400));
    await tester.tap(find.text('bottomhunter'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing); // 넓은 화면은 줄을 누르면 오른쪽 패널에 나온다
    expect(find.text('bottomhunter'), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, '저장'), findsOneWidget);
    for (final label in ['회원등급', '시작일자', '만료일자', '차단 사유', '휴대폰', '메모']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('이름'), findsNWidgets(2)); // 회원 표 머리줄과 상세 칸
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('허용'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pump();
    expect(find.text('아직 API 가 연결되지 않았습니다.'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '되돌리기'));
    await tester.pump();
    expect(find.text('허용'), findsOneWidget);
    expect(mockMembers.firstWhere((m) => m.username == 'bottomhunter').accessBlocked, isFalse);

    // 회원등급 변경은 처리 칸 안에서 고른다. 저장 API 전이라 안내만 한다.
    await tester.ensureVisible(find.text('회원등급 변경'));
    await tester.tap(find.text('회원등급 변경'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.widgetWithText(FilledButton, '변경'), findsOneWidget);
    await tester.ensureVisible(find.text('변경할 회원등급'));
    await tester.tap(find.text('변경할 회원등급'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('골드').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '변경'));
    await tester.pump();
    expect(find.text('아직 API 가 연결되지 않았습니다.'), findsOneWidget);

    // 고객 상세 로그 보기는 그 회원의 로그 탭을 연다.
    await tester.tap(find.text('고객 상세 로그 보기'));
    await tester.pumpAndSettle();
    expect(find.text('bottomhunter 워커'), findsNothing);
    expect(find.textContaining('고객 로그 ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원: 검색하고 상세에서 정지·해제한다', (tester) async {
    await openMembers(tester);
    await tester.enterText(find.byType(TextField), 'uptrend');
    await tester.pumpAndSettle();
    expect(find.text('uptrend99'), findsOneWidget);
    expect(find.text('risingkang'), findsNothing);
    expect(find.text('up**@example.com'), findsOneWidget); // 목록은 이메일을 가린다

    await tester.tap(find.text('uptrend99')); // 아이디를 눌러도 상세가 열린다
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('이용 정지'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '정지 사유 (회원에게 안내됩니다)'), '테스트 정지');
    await tester.tap(find.text('30일'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '정지'));
    await tester.pumpAndSettle();

    final m = mockMembers.firstWhere((m) => m.username == 'uptrend99');
    expect(m.status, MemberStatus.suspended);
    expect(find.text('테스트 정지'), findsOneWidget);

    await tester.tap(find.text('정지 해제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '해제'));
    await tester.pumpAndSettle();
    expect(m.status, MemberStatus.active);
    expect(m.history.first.text, '정지 해제');
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원: 탈퇴 요청을 처리하면 목록에서 사라진다', (tester) async {
    await openMembers(tester);
    await tester.tap(find.text('탈퇴 요청 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('dungeon_walker'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴 처리 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '탈퇴 처리'));
    await tester.pumpAndSettle();

    expect(find.text('dungeon_walker'), findsNothing);
    expect(find.text('탈퇴 요청 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
