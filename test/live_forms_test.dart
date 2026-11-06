import 'dart:convert';

import 'package:dungeon_admin/live_api.dart';
import 'package:dungeon_admin/mock_admin.dart';
import 'package:dungeon_admin/mock_data.dart';
import 'package:dungeon_admin/pages/live_lists.dart';
import 'package:dungeon_admin/pages/live_market_hours.dart';
import 'package:dungeon_admin/pages/live_notifications_page.dart';
import 'package:dungeon_admin/pages/live_symbol_page.dart';
import 'package:dungeon_admin/pages/live_workers_table.dart';
import 'package:dungeon_admin/pages/member_detail_dialog.dart';
import 'package:dungeon_admin/pages/member_monitor_page.dart';
import 'package:dungeon_admin/pages/push_page.dart' show pushTargetRequest;
import 'package:dungeon_admin/view_store.dart';
import 'package:dungeon_admin/widgets/admin_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _notConnected = '아직 API 가 연결되지 않았습니다.';

Member _member(MemberStatus status) => Member(
  9001,
  'liveuser',
  'li***@test.com',
  DateTime(2026, 1, 1),
  null,
  status,
  liveId: '11111111-0000-0000-0000-000000000000',
);

void main() {
  setUp(() {
    resetMockAdmins();
    signIn('admin', samplePassword);
    useLiveData.value = true;
    liveMembers.clear();
  });

  tearDown(() => useLiveData.value = false);

  Future<void> pumpDetail(WidgetTester tester, Member m) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: MemberDetailView(m))),
      ),
    );
  }

  testWidgets('테스트 DB 회원: 처리 버튼은 칸 안에 입력 화면을 열고 마지막에 안내만 한다', (tester) async {
    final m = _member(MemberStatus.active);
    await pumpDetail(tester, m);

    await tester.tap(find.text('이용 정지'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    final send = find.widgetWithText(FilledButton, '정지');
    expect(tester.widget<FilledButton>(send).onPressed, isNull); // 사유가 있어야 누를 수 있다
    await tester.enterText(find.widgetWithText(TextField, '정지 사유 (회원에게 안내됩니다)'), '약관 위반');
    await tester.tap(find.widgetWithText(ChoiceChip, '30일'));
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pump();
    expect(find.text(_notConnected), findsOneWidget);
    expect(m.status, MemberStatus.active);

    await tester.tap(find.widgetWithText(OutlinedButton, '접속 차단'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '차단 사유'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '정지'), findsNothing);
    expect(m.accessBlocked, isFalse);

    await tester.tap(find.widgetWithText(OutlinedButton, '휴면 전환'));
    await tester.pumpAndSettle();
    expect(find.text('${m.username} 회원을 휴면으로 전환합니다.'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '취소'));
    await tester.pumpAndSettle();
    expect(find.text('${m.username} 회원을 휴면으로 전환합니다.'), findsNothing);
  });

  testWidgets('테스트 DB 회원: 승인 대기는 승인 화면이 열리고 상담 입력도 보인다', (tester) async {
    await pumpDetail(tester, _member(MemberStatus.pending));
    await tester.tap(find.text('가입 승인'));
    await tester.pumpAndSettle();
    expect(find.text('liveuser 회원의 가입을 승인합니다.'), findsOneWidget);

    expect(find.widgetWithText(TextField, '상담·문의 내용을 남겨 두세요'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '상담·문의 내용을 남겨 두세요'), '문의');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pump();
    expect(find.text(_notConnected), findsOneWidget);
  });

  testWidgets('종목 마스터: 앱처럼 시장, 거래소, 상품, 월물 순서로 찾는다', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final asked = <String>[];
    Map<String, Object?> product(String code, String name, String exchange) => {
      'productCode': code,
      'name': name,
      'exchange': exchange,
      'currency': 'USD',
      'tickSize': 0.1,
      'tickValue': 10,
      'multiplier': 100,
      'monthCount': 2,
      'nearMonth': '${code}Z26',
      'workerCount': 0,
      'active': true,
    };
    setLiveClient(
      MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        asked.add(request.url.toString());
        final exchange = request.url.queryParameters['exchange'];
        final products = [
          for (final p in [product('GC', 'Gold', 'CME'), product('BRN', 'Brent', 'ICE')])
            if (exchange == null || p['exchange'] == exchange) p,
        ];
        final Object body = path.endsWith('/live/symbols')
            ? {'items': products, 'page': 1, 'pageSize': 100, 'total': products.length}
            : path.endsWith('/live/symbols/exchanges')
            ? {
                'items': [
                  {'exchange': 'CME', 'count': 1},
                  {'exchange': 'ICE', 'count': 1},
                ],
                'page': 1,
                'pageSize': 2,
                'total': 2,
              }
            : path.endsWith('/live/symbols/stocks')
            ? {
                'items': [
                  {'code': '005930', 'name': '삼성전자', 'exchange': 'KOSPI', 'active': true},
                ],
                'page': 1,
                'pageSize': 20,
                'total': 1,
              }
            : {
                'items': [
                  {'code': 'GCX26', 'month': '202611', 'exchange': 'CME', 'active': true, 'workerCount': 0},
                  {
                    'code': 'GCZ26',
                    'month': '202612',
                    'exchange': 'CME',
                    'label': '최근월물',
                    'active': true,
                    'workerCount': 0,
                  },
                ],
                'page': 1,
                'pageSize': 100,
                'total': 2,
              };
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LiveSymbolPage())));
    await tester.pumpAndSettle();
    for (final chip in ['전체', 'KOSPI', 'KOSDAQ', '해외선물']) {
      expect(find.widgetWithText(FilterChip, chip), findsOneWidget, reason: chip);
    }
    expect(find.text('1개 종목 · 해외선물 2개 상품'), findsOneWidget);
    expect(find.text('삼성전자'), findsOneWidget);
    expect(find.text('Gold'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'KOSPI'));
    await tester.pumpAndSettle();
    expect(asked.last, contains('exchange=KOSPI'));
    expect(find.text('Gold'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, '해외선물'));
    await tester.pumpAndSettle();
    expect(find.text('삼성전자'), findsNothing);
    expect(find.text('전체 거래소 2'), findsOneWidget);
    await tester.tap(find.text('ICE 1'));
    await tester.pumpAndSettle();
    expect(find.text('ICE 장 시간'), findsOneWidget);
    expect(asked.where((u) => u.contains('/live/symbols?') && u.contains('exchange=ICE')), isNotEmpty);
    expect(find.text('Gold'), findsNothing);
    expect(find.text('Brent'), findsOneWidget);
    expect(find.text('상품 1개에 함께 적용합니다.'), findsOneWidget);
    expect(find.text('Gold'), findsNothing);
    expect(find.text('Brent'), findsOneWidget);
    await tester.tap(find.text('전체 거래소 2'));
    await tester.pumpAndSettle();

    expect(find.text('202612'), findsNWidgets(2)); // GCZ26 을 앱과 같은 표기로
    await tester.tap(find.text('Gold'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('2개 월물  GC · CME · 1틱 0.1 = \$10', findRichText: true), findsOneWidget);
    expect(find.text('Gold 2026년 12월물'), findsOneWidget);
    expect(find.text('GCZ26 · CME'), findsOneWidget);
    expect(find.text('최근월물'), findsWidgets);

    // 장 시간은 네 구간을 입력한다. 형식이 틀리면 저장할 수 없고, 저장은 안내만 한다.
    final fields = find.descendant(of: find.widgetWithText(Panel, '장 시간'), matching: find.byType(TextField));
    expect(fields, findsNWidgets(8));
    final save = find.widgetWithText(FilledButton, '저장');
    await tester.enterText(fields.at(0), '25:00');
    await tester.enterText(fields.at(1), '15:45');
    await tester.pump();
    expect(find.textContaining('08:45 형식'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(fields.at(0), '08:45');
    await tester.pump();
    await tester.tap(find.text('특정일 추가'));
    await tester.pumpAndSettle();
    expect(find.text('특정일 날짜를 고르세요.'), findsOneWidget);
    await tester.tap(find.byTooltip('특정일 삭제'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    expect(find.text(_notConnected), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('전체 워커: 회원별·종목별로 찾고 실현손익 합계를 낸다', (tester) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const a = '11111111-0000-0000-0000-000000000000', b = '22222222-0000-0000-0000-000000000000';
    Map<String, Object?> member(String id, String name) => {
      'id': id,
      'username': name,
      'status': 'active',
      'maskedEmail': 'x@test.com',
      'joinedAt': '2026-10-28T03:20:00Z',
      'workerCount': 1,
      'runningWorkerCount': 1,
    };
    final asked = <Uri>[];
    Map<String, Object?> worker(String id, String member, String name, String code, String status, double pnl) => {
      'id': id,
      'memberId': member,
      'username': name,
      'symbolCode': code,
      'symbolName': '$code 이름',
      'marketType': '해외선물',
      'status': status,
      'qtyUnit': '계약',
      'jobCount': 1,
      'finishedJobCount': 2,
      'cycleCount': 71,
      'insertedAt': '2026-11-04T05:15:00Z',
      'accounts': code == 'HSIX26'
          ? [
              {'accountName': '해외계좌2', 'maskedAccountNumber': '****9999', 'isPaper': true},
            ]
          : [],
      'holdings': code == 'HSIX26'
          ? [
              {'side': 'short', 'size': 1},
            ]
          : [],
      'pnl': [
        {'isPaper': true, 'currency': 'HKD', 'realizedPnl': pnl},
      ],
    };
    final workers = [
      worker('33333333-0000-0000-0000-000000000000', a, 'superman', 'HSIX26', 'running', 1000),
      worker('44444444-0000-0000-0000-000000000000', b, 'bossljo', 'MCLZ26', 'stopped', -300),
    ];
    Object body(Uri url) {
      final path = url.path;
      Map<String, Object?> page(List<Object?> items, [Object? totals]) => {
        'items': items,
        'page': 1,
        'pageSize': 100,
        'total': items.length,
        'totals': ?totals,
      };
      if (path.endsWith('/live/members')) return page([member(a, 'superman'), member(b, 'bossljo')]);
      if (path.endsWith('/live/workers')) {
        final status = url.queryParameters['status'];
        final q = url.queryParameters['q'], symbol = url.queryParameters['symbol'];
        final rows = [
          for (final w in workers)
            if ((status == null || w['status'] == status) &&
                (q == null || w['username'] == q) &&
                (symbol == null || w['symbolCode'] == symbol))
              w,
        ];
        return page(rows, {
          'running': rows.where((w) => w['status'] == 'running').length,
          'stopped': rows.where((w) => w['status'] == 'stopped').length,
          'pnl': [for (final w in rows) ...w['pnl'] as List],
        });
      }
      if (path.endsWith('/live/positions')) {
        return page([
          {
            'memberId': a,
            'username': 'superman',
            'symbolCode': 'HSIX26',
            'symbolName': 'HSI',
            'accountName': '해외계좌2',
            'isPaper': true,
            'side': 'short',
            'size': 1,
            'qtyUnit': '계약',
            'entryPrice': 24640,
            'currency': 'HKD',
            'jobName': '캔5분',
          },
        ]);
      }
      if (path.endsWith('/live/logs')) {
        return page([
          {
            'memberId': b,
            'username': 'bossljo',
            'at': '2026-11-04T05:15:00Z',
            'category': 'order',
            'text': 'order_submitted',
            'jobName': '돌파',
          },
        ]);
      }
      if (path.endsWith('/live/orders')) {
        return page(
          [
            {
              'memberId': a,
              'username': 'superman',
              'orderedAt': '2026-11-04T05:15:00Z',
              'symbolName': 'HSI',
              'side': 'buy',
              'filledQty': 1,
              'qtyUnit': '계약',
              'kind': 'exit',
              'realizedPnl': 500,
            },
          ],
          [
            {'isPaper': true, 'currency': 'HKD', 'orders': 749, 'filled': 748, 'realizedPnl': 120900},
          ],
        );
      }
      return page([]);
    }

    setLiveClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        asked.add(request.url);
        return http.Response.bytes(utf8.encode(jsonEncode(body(request.url))), 200);
      }),
    );
    await refreshLiveMembers();
    LiveWorkerRow? opened;
    int? openedMember;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveWorkersTable(onOpen: (r) => opened = r, onOpenMember: (id) => openedMember = id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('워커 2개 · 가동중 1개'), findsOneWidget);
    expect(find.text('해외계좌2(****9999)'), findsOneWidget);
    expect(find.text('71'), findsNWidgets(2));
    expect(find.text('매도 1계약'), findsOneWidget);
    expect(find.text('+700 HKD', findRichText: true), findsOneWidget); // 합계
    expect(asked.where((u) => u.path.contains('/members/')), isEmpty); // 회원마다 부르지 않는다

    await tester.enterText(find.widgetWithText(TextField, '회원 아이디 검색'), 'bossljo');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(asked.last.queryParameters['q'], 'bossljo');
    expect(find.text('superman'), findsNothing);
    expect(find.text('워커 1개 · 가동중 0개'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '회원 아이디 검색'), '');
    await tester.enterText(find.widgetWithText(TextField, '종목코드·종목명 검색'), 'HSIX26');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('워커 1개 · 가동중 1개'), findsOneWidget);
    await tester.tap(find.text('superman'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened?.symbolCode, 'HSIX26');

    await tester.enterText(find.widgetWithText(TextField, '종목코드·종목명 검색'), '');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(ChoiceChip, '중지됨'));
    await tester.pumpAndSettle();
    expect(asked.last.queryParameters['status'], 'stopped');
    expect(find.text('워커 1개 · 가동중 0개'), findsOneWidget);
    expect(find.text('-300 HKD', findRichText: true), findsWidgets);

    // 거래는 전체 기준 합계를 함께 보여 준다.
    await tester.tap(find.widgetWithText(ChoiceChip, '거래'));
    await tester.pumpAndSettle();
    expect(find.text('청산'), findsOneWidget);
    expect(find.text('+500'), findsOneWidget);
    expect(find.text('모의 HKD · 주문 749건 · 체결 748건 · 손익 120,900'), findsOneWidget);
    await tester.tap(find.text('전체 상태'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('거부').last);
    await tester.pumpAndSettle();
    expect(asked.last.queryParameters['group'], 'rejected');
    expect(find.text('합계(삭제된 워커 포함)'), findsOneWidget);

    // 포지션과 로그도 전체 회원 것이 나오고 줄을 누르면 그 회원을 연다.
    await tester.tap(find.widgetWithText(ChoiceChip, '포지션'));
    await tester.pumpAndSettle();
    expect(find.text('24,640'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '로그'));
    await tester.pumpAndSettle();
    expect(find.text('돌파 · 주문 전송'), findsOneWidget);
    expect(find.text('bossljo'), findsOneWidget);
    await tester.tap(find.text('돌파 · 주문 전송'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(openedMember, liveMembers.firstWhere((m) => m.username == 'bossljo').id);
  });

  testWidgets('회원 선택: 목록을 누르는 순간 그 회원의 워커로 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    writeView('worker-kinds/admin', 'real,paper,alert');
    const a = '11111111-0000-0000-0000-000000000000', b = '22222222-0000-0000-0000-000000000000';
    Map<String, Object?> member(String id, String name) => {
      'id': id,
      'username': name,
      'status': 'active',
      'joinedAt': '2026-10-28T03:20:00Z',
      'workerCount': 1,
    };
    Map<String, Object?> worker(String id, String code) => {
      'id': id,
      'symbolCode': code,
      'symbolName': '$code 이름',
      'marketType': '해외선물',
      'status': 'stopped',
      'kind': 'paper',
      'jobCount': 0,
      'finishedJobCount': 0,
      'insertedAt': '2026-11-04T05:15:00Z',
    };
    Map<String, Object?> page(List<Object?> items) => {'items': items, 'page': 1, 'pageSize': 100, 'total': items.length};
    Object body(String path) {
      if (path.endsWith('/live/members')) return page([member(a, 'superman'), member(b, 'bossljo')]);
      if (path.endsWith('$a/workers')) return page([worker('33333333-0000-0000-0000-000000000000', 'SUPERW')]);
      if (path.endsWith('$b/workers')) return page([worker('44444444-0000-0000-0000-000000000000', 'BOSSW')]);
      return page([]);
    }

    setLiveClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        return http.Response.bytes(utf8.encode(jsonEncode(body(request.url.path))), 200);
      }),
    );
    await refreshLiveMembers();
    memberMonitorRequest.value = MonitorRequest(liveMembers.last.id);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MemberMonitorPage())));
    await tester.pumpAndSettle();
    expect(find.text('BOSSW'), findsOneWidget);

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    // 마우스를 아직 떼지 않았는데 이미 바뀌어야 한다.
    final press = await tester.startGesture(tester.getCenter(find.text('superman').last));
    await tester.pumpAndSettle();
    expect(find.text('superman 워커'), findsOneWidget);
    expect(find.text('SUPERW'), findsOneWidget);
    expect(find.text('BOSSW'), findsNothing);
    await press.up();
    await tester.pumpAndSettle();
    expect(find.text('superman 워커'), findsOneWidget);
  });

  testWidgets('회원 워커: 실전·모의·알람을 체크박스로 골라 본다', (tester) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const id = '11111111-0000-0000-0000-000000000000';
    Map<String, Object?> worker(String guid, String code, String kind) => {
      'id': guid,
      'symbolCode': code,
      'symbolName': '$code 이름',
      'marketType': '해외선물',
      'status': 'stopped',
      'kind': kind,
      'jobCount': 0,
      'finishedJobCount': 0,
      'insertedAt': '2026-11-04T05:15:00Z',
    };
    Map<String, Object?> page(List<Object?> items) => {'items': items, 'page': 1, 'pageSize': 100, 'total': items.length};
    Object body(String path) {
      if (path.endsWith('/live/members')) {
        return page([
          {
            'id': id,
            'username': 'superman',
            'status': 'active',
            'joinedAt': '2026-10-28T03:20:00Z',
            'workerCount': 3,
          },
        ]);
      }
      if (path.endsWith('$id/workers')) {
        return page([
          worker('33333333-0000-0000-0000-000000000000', 'REAL1', 'real'),
          worker('44444444-0000-0000-0000-000000000000', 'PAPER1', 'paper'),
          worker('55555555-0000-0000-0000-000000000000', 'ALERT1', 'alert'),
        ]);
      }
      return page([]);
    }

    setLiveClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        return http.Response.bytes(utf8.encode(jsonEncode(body(request.url.path))), 200);
      }),
    );
    writeView('worker-kinds/admin', 'real,paper,alert');
    await refreshLiveMembers();
    memberMonitorRequest.value = MonitorRequest(liveMembers.single.id);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MemberMonitorPage())));
    await tester.pumpAndSettle();

    expect(find.text('REAL1'), findsOneWidget);
    expect(find.text('PAPER1'), findsOneWidget);
    expect(find.text('ALERT1'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));

    // 실전만 본다.
    await tester.tap(find.text('모의 1'));
    await tester.tap(find.text('알람 1'));
    await tester.pumpAndSettle();
    expect(find.text('REAL1'), findsOneWidget);
    expect(find.text('PAPER1'), findsNothing);
    expect(find.text('ALERT1'), findsNothing);

    // 다른 탭을 다녀와도 체크가 남는다.
    await tester.tap(find.widgetWithText(ChoiceChip, '거래'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '워커'));
    await tester.pumpAndSettle();
    expect(find.text('REAL1'), findsOneWidget);
    expect(find.text('PAPER1'), findsNothing);
    expect(find.text('ALERT1'), findsNothing);

    // 화면을 나갔다가 다시 들어와도 그대로다.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    memberMonitorRequest.value = MonitorRequest(liveMembers.single.id);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MemberMonitorPage())));
    await tester.pumpAndSettle();
    expect(find.text('REAL1'), findsOneWidget);
    expect(find.text('PAPER1'), findsNothing);
    expect(find.text('ALERT1'), findsNothing);

    // 알람을 함께 고른다.
    await tester.tap(find.text('알람 1'));
    await tester.pumpAndSettle();
    expect(find.text('ALERT1'), findsOneWidget);

    // 모두 끄면 안내가 나온다.
    await tester.tap(find.text('실전 1'));
    await tester.tap(find.text('알람 1'));
    await tester.pumpAndSettle();
    expect(find.text('체크한 종류의 워커가 없습니다. 이 회원의 워커는 실전 1개, 모의 1개, 알람 1개입니다.'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '모두 보기'));
    await tester.pumpAndSettle();
    expect(find.text('REAL1'), findsOneWidget);
    expect(find.text('PAPER1'), findsOneWidget);
    expect(find.text('ALERT1'), findsOneWidget);
  });

  testWidgets('회원 목록: 전략을 찾고 줄을 누르면 설정이 나온다', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    setLiveClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'items': [
                {
                  'name': '캔5분',
                  'baseTemplateId': 'candle_direction_breakout',
                  'marketType': '해외선물',
                  'templateParams': {'signal_timeframe': '5m', 'quantity': 2},
                },
                {'name': '돌파전략', 'baseTemplateId': 'breakout', 'marketType': '국내주식'},
              ],
              'page': 1,
              'pageSize': 100,
              'total': 2,
            }),
          ),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveMemberList(member: _member(MemberStatus.active), def: liveStrategyList),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2건'), findsOneWidget);
    expect(find.text('캔들 방향'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '돌파');
    await tester.pump();
    expect(find.text('캔5분'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    await tester.tap(find.text('캔5분'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('2 계약'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('특정일 시간: 국내는 같은 날 안에서, 해외선물은 다음 날로 넘어갈 수 있다', () {
    final rows = [SpecialRow(date: DateTime(2026, 12, 24), reason: '조기 종료', open: '22:20', close: '03:30')];
    expect(specialDaysProblem(rows, sameDay: false), isNull);
    expect(specialDaysProblem(rows, sameDay: true), contains('늦어야'));
  });

  testWidgets('국내 장 시간: 기본 시간과 특정일을 입력하고 저장은 안내만 한다', (tester) async {
    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    setLiveClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'markets': [],
              'holidays': [
                {'date': '2026-12-25', 'name': '성탄절', 'market': 'KRX'},
              ],
              'specialDays': [
                {'name': '국내주식', 'date': null, 'amOpen': '09:00', 'amClose': '15:35'},
                {'name': '수능일', 'date': '2026-11-19', 'reason': '수능일', 'amOpen': '10:00', 'amClose': '16:35'},
              ],
            }),
          ),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: LiveMarketHours())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2026-11-19'), findsOneWidget);
    expect(find.text('수능일'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.textContaining('2026-12-25 성탄절'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, '저장');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

    // 새 특정일은 날짜와 사유가 있어야 저장할 수 있다.
    await tester.tap(find.text('특정일 추가'));
    await tester.pumpAndSettle();
    expect(find.text('특정일 날짜를 고르세요.'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('사유를 입력하세요'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(5), '임시 변경');
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(4), '09:00');
    await tester.pump();
    expect(find.textContaining('장 종료는 장 시작보다 늦어야'), findsOneWidget);
    await tester.tap(find.text('되돌리기'));
    await tester.pump();
    expect(find.text('임시 변경'), findsNothing);
    expect(find.text('16:35'), findsOneWidget);

    await tester.tap(save);
    await tester.pump();
    expect(find.text(_notConnected), findsOneWidget);
  });

  testWidgets('푸시 알림: 회원 상세에서 오면 그 회원이 받는 사람으로 골라져 있다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    setLiveClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        final Object body = request.url.path.endsWith('/live/notifications')
            ? {'items': [], 'page': 1, 'pageSize': 20, 'total': 0}
            : {
                'items': [
                  {
                    'id': '11111111-0000-0000-0000-000000000000',
                    'username': 'superman',
                    'status': 'active',
                    'maskedEmail': 'su***@test.com',
                    'joinedAt': '2026-10-28T03:20:00Z',
                    'workerCount': 0,
                    'runningWorkerCount': 0,
                  },
                ],
                'page': 1,
                'pageSize': 100,
                'total': 1,
              };
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );
    await refreshLiveMembers();
    final m = liveMembers.single;
    pushTargetRequest.value = m.id;

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LiveNotificationsPage())));
    await tester.pumpAndSettle();

    expect(pushTargetRequest.value, isNull);
    expect(find.text('superman에게 보내기'), findsOneWidget);

    // 마지막 회원을 빼도 전체로 나가지 않고, 검색해서 다시 고른다.
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('받는 사람을 고르세요'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '회원 아이디·이메일 검색'), 'nobody');
    await tester.pump();
    expect(find.text('찾는 회원이 없습니다.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '회원 아이디·이메일 검색'), 'SUPER');
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'superman'));
    await tester.pumpAndSettle();
    expect(find.text('superman에게 보내기'), findsOneWidget);

    // 회원등급은 여러 개 고를 수 있다.
    await tester.tap(find.widgetWithText(ChoiceChip, '회원등급'));
    await tester.pumpAndSettle();
    expect(find.text('받는 사람을 고르세요'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'VIP'));
    await tester.tap(find.widgetWithText(FilterChip, '골드'));
    await tester.pumpAndSettle();
    expect(find.text('골드·VIP 등급에게 보내기'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '전체 회원'));
    await tester.pumpAndSettle();
    expect(find.text('전체 회원에게 보내기'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '회원 선택'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '제목'), '점검 안내');
    await tester.enterText(find.widgetWithText(TextField, '내용'), '오늘 점검합니다');
    await tester.pumpAndSettle();
    await tester.tap(find.text('superman에게 보내기'));
    await tester.pump();
    expect(find.text(_notConnected), findsOneWidget);
  });
}
