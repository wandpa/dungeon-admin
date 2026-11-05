import 'package:dungeon_admin/main.dart';
import 'package:dungeon_admin/mock_accounts.dart';
import 'package:dungeon_admin/mock_admin.dart';
import 'package:dungeon_admin/mock_consultations.dart';
import 'package:dungeon_admin/mock_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    resetMockAdmins();
    resetMockMembers();
    resetMockNotices();
    resetMockSignals();
    resetSentPushes();
    resetMockConsultations();
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
      '상담 이력': '접수 1',
      '회원 모니터링': '고객 로그 · 전체',
      '신호 관리': '마이크로 WTI 원유 12월물',
      '푸시 알림': '오늘의 던전이 열렸습니다',
      '공지사항': '던전우상향 정식 출시 안내',
      '관리자': '활동 기록',
      '대시보드': '오늘 발생 신호',
    };
    for (final MapEntry(key: menu, value: content) in pages.entries) {
      await tester.tap(find.widgetWithText(ListTile, menu));
      await tester.pumpAndSettle();
      expect(find.text(content), findsWidgets, reason: menu);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 화면: 서랍 메뉴로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '공지사항'));
    await tester.pumpAndSettle();

    expect(find.text('던전우상향 정식 출시 안내'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원 모니터링: 워커를 선택하면 설정과 잡이 따로 나오고, 잡에서 이력과 설정을 본다', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000); // 내용이 스크롤 없이 다 만들어지게
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(ListTile, '회원 모니터링'));
    await tester.pumpAndSettle();

    // 처음에는 워커가 있는 첫 회원의 워커 전체가 목록으로 나오고 로그도 전체다.
    expect(find.text('risingkang 워커'), findsOneWidget);
    expect(find.text('newbie_slime'), findsNothing); // 승인 대기 회원은 목록에 없다
    expect(find.textContaining('실행 5 / 7'), findsOneWidget);
    expect(find.text('테슬라 (TSLA)'), findsOneWidget);
    expect(find.text('+7,000 KRW'), findsOneWidget); // 선택하지 않은 워커의 손익도 목록에 보인다
    expect(find.text('고객 로그 · 전체'), findsOneWidget);
    expect(find.text('워커를 선택하세요.'), findsNWidgets(2));
    expect(find.text('Android 앱 로그인'), findsWidgets);
    expect(find.text('삼성전자 워커 시작'), findsOneWidget);

    // 워커를 누르면 그 워커의 설정·잡·로그만 나온다.
    await tester.tap(find.text('마이크로 WTI 원유 12월물 (MCLZ26)'));
    await tester.pumpAndSettle();
    expect(find.text('고객 로그 · 마이크로 WTI 원유 12월물'), findsOneWidget);
    expect(find.text('마이크로 WTI 원유 12월물 워커 시작'), findsOneWidget);
    expect(find.text('삼성전자 워커 시작'), findsNothing);
    expect(find.text('Android 앱 로그인'), findsNothing);

    // 워커 제목(탭)을 누르면 전체 로그로 돌아오고, 다시 워커를 고를 수 있다.
    await tester.tap(find.text('risingkang 워커'));
    await tester.pumpAndSettle();
    expect(find.text('고객 로그 · 전체'), findsOneWidget);
    expect(find.text('삼성전자 워커 시작'), findsOneWidget);
    await tester.tap(find.text('마이크로 WTI 원유 12월물 (MCLZ26)'));
    await tester.pumpAndSettle();

    expect(find.text('마이크로 WTI 원유 12월물 워커 설정'), findsOneWidget);
    expect(find.text('마이크로 WTI 원유 12월물 잡'), findsOneWidget);
    expect(find.text('돌파 매수 전략'), findsOneWidget);
    expect(find.text('거래량 급증 매수'), findsNothing);

    // 사용자가 설정한 값이 앱과 같은 항목으로 보인다.
    expect(find.text('장 마감 시 자동 청산'), findsOneWidget);
    expect(find.text('누적 손익으로 워커 종료'), findsOneWidget);
    expect(find.text('일 · 매일 장 시작 10분 전'), findsOneWidget);
    expect(find.text('+500 USD 이상'), findsOneWidget);
    expect(find.text('−300 USD 이하'), findsOneWidget);
    expect(find.text('오늘 누적 손익'), findsOneWidget);
    expect(find.text('+210 USD'), findsOneWidget); // 실현 140 + 평가 70

    // 잡을 선택하면 팝업 없이 아래 패널에 설정과 체결·이력이 다 나온다.
    expect(find.text('잡을 선택하세요.'), findsOneWidget);
    expect(find.text('1회차'), findsNothing);
    await tester.tap(find.text('돌파 매수 전략'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('돌파 매수 전략 상세'), findsOneWidget);
    expect(find.text('돌파 (상세보기)'), findsOneWidget);
    expect(find.text('진입설정'), findsOneWidget);
    expect(find.text('청산설정'), findsOneWidget);
    expect(find.text('현재가 대비 +10틱'), findsOneWidget);
    expect(find.text('지정가'), findsOneWidget);
    expect(find.text('체결 내역'), findsOneWidget);
    expect(find.text('주문 5건 · 체결 5건 · 거부 0건'), findsOneWidget);
    expect(find.text('1회차'), findsOneWidget);
    expect(find.text('+100 USD'), findsOneWidget); // 회차 손익 합이 잡 실현손익이다
    expect(find.text('+40 USD'), findsOneWidget);
    expect(find.text('사이클 종료'), findsNWidgets(2));

    // 잡을 선택하면 고객 로그도 그 잡의 로그로 바뀐다.
    expect(find.text('고객 로그 · 돌파 매수 전략'), findsOneWidget);
    expect(find.text('마이크로 WTI 원유 12월물 매수 2계약 체결 @100.75'), findsOneWidget);
    expect(find.text('마이크로 WTI 원유 12월물 워커 시작'), findsNothing);
    expect(find.text('고점 이탈 알람 감시 시작'), findsNothing);

    // 알람 잡도 설정을 볼 수 있다.
    await tester.tap(find.text('고점 이탈 알람'));
    await tester.pumpAndSettle();
    expect(find.text('알람 모드에서는 주문을 내지 않습니다'), findsOneWidget);
    expect(find.text('RSI(14) 70 이상 AND 볼린저밴드 상단 이탈'), findsOneWidget);
    expect(find.text('아직 이력이 없어요'), findsOneWidget);
    expect(find.text('고객 로그 · 고점 이탈 알람'), findsOneWidget);
    expect(find.text('고점 이탈 알람 감시 시작'), findsOneWidget);
    expect(find.text('마이크로 WTI 원유 12월물 매수 2계약 체결 @100.75'), findsNothing);

    // 끝난 잡은 종료된 전략 탭에 있고, 카드와 상세에서 거부 사유를 볼 수 있다.
    expect(find.text('갭 상승 진입'), findsNothing);
    await tester.tap(find.text('종료된 전략 1'));
    await tester.pumpAndSettle();
    expect(find.text('돌파 매수 전략'), findsNothing);
    expect(find.text('잡을 선택하세요.'), findsOneWidget); // 탭을 바꾸면 상세도 비운다
    expect(find.text('고객 로그 · 마이크로 WTI 원유 12월물'), findsOneWidget); // 로그는 워커 단위로 돌아온다
    expect(find.text('주문 가능 금액 부족'), findsOneWidget);
    await tester.tap(find.text('갭 상승 진입'));
    await tester.pumpAndSettle();
    expect(find.text('갭 트레이딩 (상세보기)'), findsOneWidget);
    expect(find.text('매수 거부 · 주문 가능 금액 부족'), findsOneWidget);

    // 다른 워커를 고르면 설정과 잡이 함께 바뀌고 열어 둔 내용은 닫힌다.
    await tester.tap(find.text('삼성전자 (005930)'));
    await tester.pumpAndSettle();
    expect(find.text('삼성전자 잡'), findsOneWidget);
    expect(find.text('거래량 급증 매수'), findsOneWidget);
    expect(find.text('현재 잡 1'), findsOneWidget); // 탭도 현재 잡으로 돌아온다
    expect(find.text('잡을 선택하세요.'), findsOneWidget);

    // 틱 기준, 쓰지 않는 수익 종료, 비정상종료가 그대로 드러난다.
    await tester.tap(find.text('uptrend99'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나스닥100 12월물 (NQZ26)'));
    await tester.pumpAndSettle();
    expect(find.text('−400틱 이하'), findsOneWidget);
    expect(find.text('-125틱'), findsOneWidget);
    expect(find.text('사용 안 함'), findsWidgets);
    await tester.tap(find.text('종료된 전략 1'));
    await tester.pumpAndSettle();
    expect(find.text('비정상종료'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '오류'));
    await tester.pumpAndSettle();
    expect(find.textContaining('잔고 불일치 감지'), findsOneWidget);
    expect(find.text('Android 앱 로그인'), findsNothing);

    await tester.tap(find.text('f_rank_trader'));
    await tester.pumpAndSettle();
    expect(find.text('등록한 워커가 없습니다.'), findsOneWidget);
    expect(find.text('워커를 선택하세요.'), findsNWidgets(2));
    expect(find.text('로그가 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원 모니터링: 모드와 계좌·주문, 알림을 탭으로 본다', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(ListTile, '회원 모니터링'));
    await tester.pumpAndSettle();

    expect(find.text('실매매'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '계좌·주문'));
    await tester.pumpAndSettle();

    // 전체 계좌: 잡 포지션과 수동 포지션, 체결·미체결·거부 주문이 다 나온다.
    expect(find.text('계좌 5개'), findsOneWidget);
    expect(find.text('통화별 총자산'), findsOneWidget);
    expect(find.text('보유 포지션 5'), findsOneWidget);
    expect(find.text('수동'), findsOneWidget);
    expect(find.textContaining('LG에너지솔루션'), findsOneWidget);
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
    expect(find.text('보유 포지션 2'), findsOneWidget);
    expect(find.text('주문 내역'), findsOneWidget);
    expect(find.text('전체 2'), findsNothing);

    // 알림: 진단에서 막힌 곳이 앱 문구로 보인다.
    await tester.tap(find.text('uptrend99'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '알림'));
    await tester.pumpAndSettle();
    expect(find.text('푸시 알림 허용'), findsOneWidget);
    expect(find.text('푸시가 나갈 곳이 없습니다'), findsOneWidget);
    expect(find.text('읽지 않음 2'), findsOneWidget);
    expect(find.textContaining('나스닥100 12월물 매도 체결'), findsWidgets);

    // 워커·잡 탭으로 돌아올 수 있다.
    await tester.tap(find.widgetWithText(ChoiceChip, '워커·잡'));
    await tester.pumpAndSettle();
    expect(find.text('uptrend99 워커'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원 모니터링: 계좌를 고르면 워커·잡·로그·알림이 그 계좌 기준으로 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(ListTile, '회원 모니터링'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('마이크로 WTI 원유 12월물 (MCLZ26)'));
    await tester.pumpAndSettle();
    expect(find.text('돌파 매수 전략'), findsOneWidget);
    expect(find.text('눌림목 소액 매수'), findsOneWidget); // 한 워커에 계좌가 다른 잡이 섞여 있다

    // 서브 계좌: 그 계좌를 쓰는 워커와 잡만 남고 다른 계좌의 손익은 빠진다.
    await tester.tap(find.widgetWithText(ChoiceChip, '해외선물 서브 ****3405'));
    await tester.pumpAndSettle();
    expect(find.text('눌림목 소액 매수'), findsOneWidget);
    expect(find.text('돌파 매수 전략'), findsNothing);
    expect(find.text('삼성전자 (005930)'), findsNothing);
    expect(find.textContaining('실행 1 / 1'), findsOneWidget);
    expect(find.text('+140 USD'), findsOneWidget); // 워커 전체 기준인 누적 손익 한 곳에만 남는다
    expect(find.text('+210 USD'), findsOneWidget); // 평가 포함도 워커 전체 기준이다
    expect(find.text('Android 앱 로그인'), findsNothing);

    // 메인 계좌: 체결 로그가 나오고, 고른 계좌는 알림 탭에도 그대로 적용된다.
    await tester.tap(find.widgetWithText(ChoiceChip, '해외선물 메인 ****3401'));
    await tester.pumpAndSettle();
    expect(find.text('돌파 매수 전략'), findsOneWidget);
    expect(find.text('마이크로 WTI 원유 12월물 매수 2계약 체결 @100.75'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '알림'));
    await tester.pumpAndSettle();
    expect(find.textContaining('삼성전자 매수 체결'), findsNothing);
    expect(find.textContaining('마이크로 금 12월물 매도 체결'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '전체 계좌'));
    await tester.pumpAndSettle();
    expect(find.textContaining('삼성전자 매수 체결'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원 모니터링: 문제 요약을 눌러 이동하고 상담 메모를 남긴다', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(ListTile, '회원 모니터링'));
    await tester.pumpAndSettle();

    // 실전과 모의 손익은 합치지 않는다.
    expect(find.textContaining('실전 +360 USD · +225,000 KRW · +2,500 HKD · 모의 +7,000 KRW'), findsOneWidget);

    // 회원 목록에 문제가 보이고, 없는 회원은 없다고 나온다.
    expect(find.text('워커 4개 · 실행 2 · 문제 3', findRichText: true), findsOneWidget);
    await tester.tap(find.text('f_rank_trader'));
    await tester.pumpAndSettle();
    expect(find.text('확인할 문제가 없습니다.'), findsOneWidget);

    // 오류 워커를 누르면 그 워커로 간다. 오류 워커는 목록 맨 위에 있다.
    await tester.tap(find.text('uptrend99'));
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
    await tester.tap(find.widgetWithText(ListTile, '푸시 알림'));
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
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '아이디·이메일 검색'), 'bottom');
    await tester.pumpAndSettle();
    await tester.tap(find.text('bottomhunter'));
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
    await tester.tap(find.widgetWithText(ListTile, '공지사항'));
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
    await tester.tap(find.byType(Switch).at(1));
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
    await tester.tap(find.widgetWithText(ListTile, menu));
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

  testWidgets('신호: 검색·시장 필터·숨기기가 동작한다', (tester) async {
    await openMenu(tester, '신호 관리');
    await tester.tap(find.widgetWithText(FilterChip, '국내주식 2'));
    await tester.pumpAndSettle();
    expect(find.text('삼성전자'), findsOneWidget);
    expect(find.text('엔비디아'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, '종목명·종목코드 검색'), '000660');
    await tester.pumpAndSettle();
    expect(find.text('SK하이닉스'), findsOneWidget);
    expect(find.text('삼성전자'), findsNothing);

    await tester.tap(find.text('숨기기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '숨기기'));
    await tester.pumpAndSettle();
    expect(find.text('SK하이닉스'), findsNothing);
    expect(mockActivities.first.kind, ActivityKind.signal);

    await tester.tap(find.widgetWithText(FilterChip, '숨긴 신호 포함 1'));
    await tester.pumpAndSettle();
    expect(find.text('다시 보이기'), findsOneWidget);
  });

  testWidgets('회원: 내보내기, 재설정 메일, 상세에서 푸시로 이어진다', (tester) async {
    await openMenu(tester, '회원 관리');
    await tester.tap(find.text('엑셀 내보내기'));
    await tester.pumpAndSettle();
    expect(mockActivities.first.text, '회원 12명 내보내기');

    await tester.tap(find.text('uptrend99'));
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
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, '관리자'));
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
    await tester.tap(find.widgetWithText(ListTile, '상담 이력'));
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    expect(find.text('risingkang 워커'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('푸시: 보낸 알림이 회원의 알림 이력에 남는다', (tester) async {
    await openMenu(tester, '푸시 알림');
    await tester.tap(find.widgetWithText(ChoiceChip, '사용자 검색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '아이디·이메일 검색'), 'rising');
    await tester.pumpAndSettle();
    await tester.tap(find.text('risingkang'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '제목'), '개별 안내');
    await tester.enterText(find.widgetWithText(TextField, '내용'), '확인 부탁드립니다.');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '1명에게 보내기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '보내기'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, '회원 모니터링'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '알림'));
    await tester.pumpAndSettle();
    expect(find.text('개별 안내'), findsOneWidget);
    expect(find.text('확인 부탁드립니다.'), findsOneWidget);
  });

  testWidgets('고객 로그: 검색·기간으로 찾고 눌러서 잡으로 이동한다', (tester) async {
    await openMenu(tester, '회원 모니터링');
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
    expect(find.text('고객 로그 · 갭 상승 진입'), findsOneWidget);
    expect(find.text('고점 이탈 알람'), findsNothing);

    // 주문을 눌러도 그 잡으로 간다.
    await tester.tap(find.widgetWithText(ChoiceChip, '계좌·주문'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(find.text('박상담'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '관리자'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, '푸시 알림'));
    await tester.pumpAndSettle();
    expect(find.text('새 알림 보내기'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, '공지사항'));
    await tester.pumpAndSettle();
    expect(find.text('공지 작성'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, '신호 관리'));
    await tester.pumpAndSettle();
    expect(find.text('숨기기'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, '회원 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('uptrend99'));
    await tester.pumpAndSettle();
    expect(find.text('이용 정지'), findsNothing);
    expect(find.text('이 권한은 조회와 상담 기록만 할 수 있습니다.'), findsOneWidget);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그인'), findsOneWidget);

    // 최고 관리자: 활동 기록에 상담 직원의 접속이 남고, 계정을 관리한다.
    await tester.tap(find.text('최고 관리자'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '관리자'));
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

  Future<void> openMembers(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(ListTile, '회원 관리'));
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

  testWidgets('회원: 검색하고 상세에서 정지·해제한다', (tester) async {
    await openMembers(tester);
    await tester.enterText(find.byType(TextField), 'uptrend');
    await tester.pumpAndSettle();
    expect(find.text('uptrend99'), findsOneWidget);
    expect(find.text('risingkang'), findsNothing);
    expect(find.text('up**@example.com'), findsOneWidget); // 목록은 이메일을 가린다

    await tester.tap(find.text('uptrend99')); // 아이디를 눌러도 상세가 열린다
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
