import 'dart:convert';

import 'package:dungeon_admin/live_api.dart';
import 'package:dungeon_admin/live_strategy.dart';
import 'package:dungeon_admin/mock_accounts.dart';
import 'package:dungeon_admin/mock_admin.dart';
import 'package:dungeon_admin/mock_data.dart';
import 'package:dungeon_admin/mock_workers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _memberId = '11111111-0000-0000-0000-000000000000';
const _workerId = '22222222-0000-0000-0000-000000000000';
const _jobId = '33333333-0000-0000-0000-000000000000';
const _base = '/api/admin/live/members/$_memberId';

Map<String, Object?> _page(List<Object?> items) => {'items': items, 'page': 1, 'pageSize': 0, 'total': items.length};

final _job = {
  'id': _jobId,
  'workerId': _workerId,
  'name': '돌파',
  'status': 'bought',
  'isActive': true,
  'hidden': false,
  'mode': 'trade',
  'entrySide': 'buy',
  'templateId': 'breakout',
  'qty': 2,
  'repeatCurrent': 1,
  'repeatCount': null,
  'accountName': '해외모의',
  'isPaper': true,
  'realizedPnl': 5.5,
  'position': {'side': 'long', 'size': 2, 'entryPrice': 94.5, 'multiplier': 100},
};

final _routes = <String, Object?>{
  '/api/admin/live/members': {
    'items': [
      {
        'id': _memberId,
        'username': 'tester',
        'maskedEmail': 'te**@example.com',
        'joinedAt': '2026-10-28T03:20:39Z',
        'lastLoginAt': null,
        'status': 'active',
        'device': null,
        'watchlistCount': 2,
        'workerCount': 1,
      },
    ],
    'total': 1,
  },
  '$_base/overview': {
    'issues': [
      {'kind': 'worker', 'label': '오류 워커 1', 'workerId': _workerId},
    ],
  },
  '$_base/accounts': _page([
    {'accountId': 'a', 'accountName': '해외모의', 'maskedAccountNumber': '****1424', 'marketType': '해외선물', 'isPaper': true},
  ]),
  '$_base/balances': _page([]),
  '$_base/positions': _page([]),
  '$_base/orders': _page([
    {
      'orderedAt': '2026-11-04T12:37:16Z',
      'jobId': _jobId,
      'workerId': _workerId,
      'symbolName': 'WTI',
      'side': 'buy',
      'qty': 1,
      'filledQty': 1,
      'avgFillPrice': 94.68,
      'status': 'filled',
      'group': null,
    },
  ]),
  '$_base/logs': _page([
    {'at': '2026-11-04T12:37:17Z', 'category': 'worker', 'text': '종료', 'workerId': _workerId, 'jobId': _jobId},
    {
      'at': '2026-11-03T12:37:17Z',
      'category': 'order',
      'text': '지난 주문',
      'workerId': 'gone',
      'jobId': 'gone',
      'jobName': '비활성 잡',
    },
  ]),
  '$_base/notifications': _page([]),
  '$_base/notification-state': {'hasToken': true, 'onServer': false},
  '$_base/workers': _page([
    {
      'id': _workerId,
      'symbolCode': 'MCLZ26',
      'symbolName': 'WTI',
      'marketType': '해외선물',
      'status': 'running',
      'currency': 'USD',
      'currentPrice': null,
      'insertedAt': '2026-10-30T13:05:33Z',
      'jobCount': 1,
      'finishedJobCount': 0,
    },
  ]),
  '$_base/workers/$_workerId': {
    'autoCloseOnMarketEnd': true,
    'pnlLimit': {'enabled': false},
  },
  '$_base/workers/$_workerId/jobs': _page([_job]),
  '/api/admin/live/symbols/MCL/months': _page([
    {'code': 'MCLX26', 'tickSize': 0.1, 'tickValue': 9},
    {'code': 'MCLZ26', 'tickSize': 0.01, 'tickValue': 1},
  ]),
  '$_base/jobs/$_jobId': {
    'templateParams': {
      'order_type': 'limit',
      'use_stop_loss': true,
      'stop_loss_value': 10,
      'stop_loss_unit': 'tick',
      'signal_timeframe': '1t',
      'use_take_profit': false,
    },
  },
  '$_base/jobs/$_jobId/cycles': _page([
    {'cycleNo': 1, 'status': 'closed', 'multiplier': 100, 'realizedPnl': 5.5, 'strategySnapshot': null},
    {'cycleNo': 2, 'status': 'open', 'multiplier': 100, 'strategySnapshot': null},
  ]),
  '$_base/jobs/$_jobId/events': _page([
    {'cycleNo': null, 'eventType': 'order_rejected', 'message': '거부', 'eventAt': '2026-11-04T12:37:01Z'},
    {'cycleNo': 1, 'eventType': 'fill', 'side': 'buy', 'qty': 2, 'price': 94.5, 'eventAt': '2026-11-04T12:37:03Z'},
    {
      'cycleNo': 1,
      'eventType': 'order_submitted',
      'side': 'buy',
      'qty': 2,
      'price': 0,
      'eventAt': '2026-11-04T12:37:02Z',
    },
  ]),
};

void main() {
  late List<String> methods;

  void serve({int status = 200, Map<String, Object?>? routes, void Function(String path)? onRequest}) {
    methods = [];
    setLiveClient(
      MockClient((request) async {
        methods.add('${request.method} ${request.url.path}');
        onRequest?.call(request.url.path);
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        expect(request.headers['Authorization'], 'Bearer t');
        if (status != 200) {
          return http.Response.bytes(utf8.encode(jsonEncode({'message': '테스트 DB 를 조회하지 못했습니다.'})), status);
        }
        final body = (routes ?? _routes)[request.url.path];
        if (body == null) return http.Response('', 404);
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );
  }

  setUp(() {
    useLiveData.value = true;
    liveMembers.clear();
  });

  tearDown(() => useLiveData.value = false);

  test('회원 목록을 화면 모델로 바꾼다', () async {
    serve();
    await refreshLiveMembers();
    final m = currentMembers.single;
    expect(liveStatus.value.error, isNull);
    expect(m.isLive, isTrue);
    expect(m.id, greaterThanOrEqualTo(liveIdBase));
    expect(m.shownEmail, 'te**@example.com');
    expect(m.shownId, '11111111');
    expect(m.device, '-');
    expect(m.lastLoginAt, isNull);
  });

  test('워커·잡·잡 내역을 받고, 없는 시세는 지어내지 않는다', () async {
    serve();
    await refreshLiveMembers();
    final m = liveMembers.single;
    await loadLiveMember(m);

    final w = workersOf(m.id).single;
    expect(w.status, WorkerStatus.running);
    expect(w.currentPrice, isNull);
    expect(w.autoCloseOnMarketEnd, isTrue);
    expect(w.pnlLimit, isNull);

    final job = w.jobs.single;
    expect(job.statusLabel, '매수완료 · 매도감시중');
    expect(job.realizedPnl, 5.5); // 회차를 받기 전에도 서버 합계를 보여 준다
    expect(job.position!.pnlAt(w.currentPrice), isNull);
    expect(job.repeatCount, 1);
    expect(job.detailLoaded, isFalse);

    final filled = await loadLiveJobDetail(m, job);
    expect(workersOf(m.id).single.jobs.single, same(filled));
    expect(filled.strategy.orderType, '지정가');
    expect(filled.strategy.stopLossPct, 10);
    expect(filled.strategy.stopLossUnit, '틱'); // 단위는 시장이 정한다
    expect(filled.strategy.tickSize, 0.01);
    expect(filled.strategy.tickValue, 1);
    expect(filled.strategy.liveExitCards!.map((c) => c.label), ['매수 커스텀 청산 조건', '매도 커스텀 청산 조건']);
    expect(filled.strategy.liveExitCards!.first.on, isFalse);
    expect(filled.strategy.liveTrailingOn, isFalse);
    expect(filled.strategy.trailingStop, {'동작 회차': '0 회', '동작 마디': '-'});
    expect(filled.strategy.takeProfitPct, isNull);
    expect(
      filled.strategy.liveItems!.map((i) => i.label),
      containsAllInOrder(['돌파기준', '신호 주기', '주문 유형', '주문 수량', '반복 횟수']),
    );
    expect(filled.strategy.liveItems!.firstWhere((i) => i.label == '신호 주기').value, '실시간');
    expect(filled.cycles.map((c) => c.cycleNo), [2, 1, 0]); // 최신 회차가 앞, 회차 밖 이벤트는 맨 뒤
    expect(filled.cycles[1].events.map((e) => e.type), ['order_submitted', 'fill']); // 시간순
    expect(filled.cycles[1].events.first.price, isNull);
    expect(filled.cycles.last.events.single.type, 'order_rejected');
    expect(filled.rejectReasons, ['거부']);

    expect(ordersOf(m.id).single.jobName, '돌파');
    expect(accountsOf(m.id).single.hasBalance, isFalse);
    expect(customerLogsOf(m.id, workerId: w.id).single.jobName, '돌파');
    expect(customerLogsOf(m.id).last.jobName, '비활성 잡'); // 목록에 없는 워커의 지난 로그
    expect(notificationStateOf(m).deviceSettingsKnown, isFalse);
    expect(notificationStateOf(m).onServer, isFalse);
    expect(issuesOf(m).single.label, '오류 워커 1');
    expect(issuesOf(m).single.workerId, w.id);

    // 로그인 외에는 조회만 한다.
    expect(methods.where((r) => !r.startsWith('GET')), ['POST /api/admin/auth/login']);
  });

  test('dev DB 대조로 더한 앱 설정·주문·이상 회원 값을 받는다', () async {
    final routes = Map<String, Object?>.of(_routes);
    final members = _routes['/api/admin/live/members']! as Map<String, Object?>;
    routes['/api/admin/live/members'] = {
      ...members,
      'items': [
        {
          ...((members['items']! as List).single as Map<String, Object?>),
          'customCandleUnits': [9, 25],
          'issueKinds': ['workerStopped', 'dailyLoss'],
        },
      ],
    };
    routes['$_base/overview'] = {
      'issues': [
        {'kind': 'workerStopped', 'label': '멈춘 워커 1', 'workerId': _workerId, 'detail': 1},
        {'kind': 'dailyLoss', 'label': '오늘 손실', 'detail': -120.5, 'currency': 'USD'}, // 빼기로 한 종류는 건너뛴다
      ],
    };
    routes['$_base/accounts'] = _page([
      {
        'accountId': 'a',
        'accountName': '국내',
        'maskedAccountNumber': '****1111',
        'marketType': '국내주식',
        'kind': 'real',
        'tokenStatus': 'valid',
        'tokenExpiresAt': '2026-11-12T00:00:00Z',
        'nxtEnabled': true,
        'usPremarketEnabled': false,
        'usAftermarketEnabled': false,
      },
    ]);
    routes['$_base/orders'] = _page([
      {
        'id': 'o1',
        'orderedAt': '2026-11-04T12:37:16Z',
        'jobId': _jobId,
        'workerId': _workerId,
        'symbolName': 'WTI',
        'side': 'buy',
        'qty': 2,
        'filledQty': 2,
        'avgFillPrice': 94.68,
        'status': 'filled',
        'fillCount': 2,
        'judgePrice': 94.6,
      },
    ]);
    routes['$_base/workers/$_workerId'] = {
      'worker': {'resumeOnMarketOpen': true, 'stopAfterCycle': false},
      'autoCloseOnMarketEnd': true,
      'pnlLimit': {'enabled': true, 'period': 'day', 'periodStart': '2026-11-04T00:00:00Z'},
    };
    routes['$_base/workers/$_workerId/jobs'] = _page([
      {..._job, 'limitPrice': 95.1, 'stopOnClose': true, 'repeatMode': 'repeat', 'runStartedAt': '2026-11-04T01:00:00Z'},
    ]);
    serve(routes: routes);
    await refreshLiveMembers();
    final m = liveMembers.single;
    await loadLiveMember(m);

    expect(m.customCandleUnits, '9, 25'); // 서버가 배열로 준다
    expect(m.issueKinds, ['workerStopped']);

    final a = accountsOf(m.id).single;
    expect(a.tokenLine, startsWith('토큰 유효 · 만료 '));
    expect(a.sessionLine, 'NXT 켜짐 · 미국 장전 꺼짐 · 장후 꺼짐');

    final o = ordersOf(m.id).single;
    expect(o.liveId, 'o1');
    expect(o.fillCount, 2);
    expect(o.judgePrice, 94.6);

    final w = workersOf(m.id).single;
    expect(w.resumeOnMarketOpen, isTrue);
    expect(w.stopAfterCycle, isFalse);
    expect(w.pnlLimit!.periodStart, DateTime.utc(2026, 11, 4).toLocal());

    final j = w.jobs.single;
    expect(j.limitPrice, 95.1);
    expect(j.stopOnClose, isTrue);
    expect(j.repeatMode, 'repeat');
    expect(j.runStartedAt, DateTime.utc(2026, 11, 4, 1).toLocal());

    final issues = issuesOf(m);
    expect(issues.map((i) => i.kind), [MemberIssueKind.workerStopped]);
    expect(issues.single.workerId, w.id);
    expect(issues.single.detail, 1);
  });

  test('고객 로그: 영어 코드를 앱과 같은 말로 바꾼다', () {
    expect(liveLogText('order_submitted'), '주문 전송');
    expect(liveLogText('fill'), '체결');
    expect(liveLogText('balance_updated'), '잔고 반영');
    expect(liveLogText('cycle_closed'), '사이클 종료');
    expect(liveLogText('alert_fired'), '신호 발생');
    expect(liveLogText('익절'), '신호 발생 · 익절');
    expect(liveLogText('MOCK****0038'), '주문 접수 · 주문번호 MOCK****0038');
    expect(liveLogText('new_event_type'), '기타 이력');
    expect(liveLogText('Hang Seng Index-202611 start 수동'), 'Hang Seng Index-202611 시작 수동');
    expect(liveLogText('캔5분30틱100회'), '캔5분30틱100회'); // 서버 문장은 그대로 둔다
  });

  test('고객 로그: 로그의 코드와 값으로 문장을 만들고 잡 이벤트는 따로 받지 않는다', () async {
    final asked = <String>[];
    Map<String, Object?> log(String type, {Object? kind, Object? side, Object? reason, String? text}) => {
      'id': type,
      'at': '2026-11-04T12:37:17Z',
      'category': 'order',
      'text': text ?? type,
      'workerId': _workerId,
      'jobId': _jobId,
      'jobName': '돌파',
      'eventType': type,
      'side': side,
      'qty': 1,
      'price': 24572,
      'balanceQty': 0,
      'exitReason': reason,
      'kind': kind,
      'cycleNo': 3,
      'symbolCode': 'MCLZ26',
    };
    serve(
      routes: {
        ..._routes,
        '$_base/logs': _page([
          log('fill', kind: 'exit', side: 'buy', reason: 'stop_loss'),
          log('balance_updated'),
          log('cycle_closed'),
          log('order_accepted', kind: 'entry', side: 'sell', text: 'MOCK****0091'),
        ]),
      },
      onRequest: asked.add,
    );
    await refreshLiveMembers();
    final m = liveMembers.single;
    await loadLiveMember(m);
    final texts = customerLogsOf(m.id).map((l) => l.text).toList();
    expect(texts, contains('MCLZ26 · 돌파 · 청산 매수 체결 · 1 @24,572 USD · 손절'));
    expect(texts, contains('MCLZ26 · 돌파 · 잔고 반영 · 잔량 0'));
    expect(texts, contains('MCLZ26 · 돌파 · 3회차 종료'));
    expect(texts, contains('MCLZ26 · 돌파 · 진입 매도 주문 접수 · 주문번호 MOCK****0091'));
    expect(asked.where((p) => p.endsWith('/events')), isEmpty);
  });

  test('거래: API 의 승수를 쓰고 청산 주문에만 매수가·매도가·손익을 붙인다', () async {
    final asked = <String>[];
    Map<String, Object?> order(String kind, double multiplier, {double? pnl}) => {
      'orderedAt': '2026-11-04T13:00:00Z',
      'jobId': _jobId,
      'workerId': _workerId,
      'symbolName': 'WTI',
      'side': 'buy',
      'qty': 1,
      'filledQty': 1,
      'avgFillPrice': 95,
      'status': 'filled',
      'symbolCode': 'CLZ26',
      'multiplier': multiplier,
      'kind': kind,
      'buyPrice': 94,
      'sellPrice': kind == 'exit' ? 96 : 0,
      'realizedPnl': pnl,
    };
    serve(
      routes: {
        ..._routes,
        '$_base/orders': _page([order('entry', 50), order('exit', 50, pnl: 200), order('exit', 50)]),
      },
      onRequest: asked.add,
    );
    await refreshLiveMembers();
    final m = liveMembers.single;
    await loadLiveMember(m);

    final orders = ordersOf(m.id);
    expect(orders.map((o) => o.realizedPnl), [null, 200, null]); // 나눠 청산하면 마지막 주문에만 온다
    expect(orders[1].buyPrice, 94);
    expect(orders[1].sellPrice, 96);
    expect(orders[0].buyPrice, isNull);
    expect(orders[0].sellPrice, isNull);
    expect(orders[0].filledAmount, 95 * 50);
    expect(asked.where((p) => p.endsWith('/cycles')), isEmpty);
  });

  test('재조회하면 새 값으로 바뀌고, 실패하면 받아 둔 값이 남는다', () async {
    serve();
    await refreshLiveMembers();
    final m = liveMembers.single;
    await loadLiveMember(m);
    final first = workersOf(m.id).single;
    await loadLiveWorkerLogs(m, first.id);
    expect(isLiveWorkerLogsLoaded(first.id), isTrue);
    final at = liveLoadedAt(m);
    expect(at, isNotNull);

    await reloadLiveMember(m);
    expect(workersOf(m.id).single, isNot(same(first)));
    expect(workersOf(m.id).single.jobs.single.detailLoaded, isFalse); // 잡 내역은 다시 받는다
    expect(isLiveWorkerLogsLoaded(first.id), isFalse);

    final kept = workersOf(m.id).single;
    final seen = liveLoadedAt(m);
    serve(status: 503);
    await expectLater(reloadLiveMember(m), throwsA(isA<LiveApiException>()));
    expect(workersOf(m.id).single, same(kept));
    expect(liveLoadedAt(m), seen);
  });

  test('알림 검색: 검색어를 전체 알림 경로의 q 로 보낸다', () async {
    final asked = <Uri>[];
    setLiveClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        asked.add(request.url);
        return http.Response.bytes(utf8.encode(jsonEncode(_page([]))), 200);
      }),
    );

    await liveNotifications(' Super ', page: 2, pageSize: 20);
    expect(asked.single.path, '/api/admin/live/notifications');
    expect(asked.single.queryParameters, {'q': 'Super', 'page': '2', 'pageSize': '20'});
  });

  test('전체 회원 목록: 조건을 쿼리로 보내고 워커 줄은 응답의 계좌·회차·보유를 쓴다', () async {
    final asked = <Uri>[];
    setLiveClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        asked.add(request.url);
        return http.Response.bytes(utf8.encode(jsonEncode(_routes[request.url.path] ?? _page([]))), 200);
      }),
    );
    await refreshLiveMembers();
    asked.clear();

    await liveAllList('/workers', member: ' super ', symbol: 'HSI', status: 'running', page: 3, pageSize: 50);
    expect(asked.single.path, '/api/admin/live/workers');
    expect(asked.single.queryParameters, {
      'q': 'super',
      'symbol': 'HSI',
      'status': 'running',
      'page': '3',
      'pageSize': '50',
    });

    await liveAllList(
      '/signals',
      member: 'super',
      symbol: 'HSI',
      memberKey: 'member',
      symbolKey: 'q',
      page: 1,
      pageSize: 50,
    );
    expect(asked.last.path, '/api/admin/live/signals');
    expect(asked.last.queryParameters, {'member': 'super', 'q': 'HSI', 'page': '1', 'pageSize': '50'});

    final row = liveWorkerRow({
      'id': _workerId,
      'memberId': _memberId,
      'username': 'superman',
      'status': 'running',
      'kind': 'paper',
      'qtyUnit': '계약',
      'cycleCount': 71,
      'accounts': [
        {'accountName': '해외계좌2', 'maskedAccountNumber': '****9999', 'isPaper': true},
      ],
      'holdings': [
        {'side': 'short', 'size': 1},
        {'side': 'long', 'size': 2},
      ],
      'pnl': [
        {'isPaper': true, 'currency': 'HKD', 'realizedPnl': 700},
      ],
    });
    expect(row.memberId, liveMembers.single.id);
    expect(row.accounts, '해외계좌2(****9999)');
    expect(row.kind, '모의');
    expect(row.round, '누적 71회');
    expect(row.holding, '매도 1계약 외 1');
    expect(row.pnl, {'HKD': 700.0});
  });

  group('토큰 만료', () {
    late int logins;
    late List<String> tokens;
    late bool expired;

    setUp(() {
      logins = 0;
      tokens = [];
      expired = true;
      setLiveClient(
        MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            logins++;
            return http.Response(jsonEncode({'token': 't$logins'}), 200);
          }
          tokens.add(request.headers['Authorization'] ?? '');
          if (expired) return http.Response('', 401);
          return http.Response(jsonEncode(_page([])), 200);
        }),
      );
      resetMockAdmins();
    });

    tearDown(resetMockAdmins);

    test('다시 로그인하지 않고 로그아웃하며, 안내는 한 번만 보여 준다', () async {
      expect(signIn('admin', samplePassword), isNull);

      await expectLater(liveGet('/dashboard'), throwsA(isA<LiveApiException>()));

      expect(logins, 1); // 코드의 비밀번호로 다시 받지 않는다
      expect(signedInAdmin.value, isNull);
      expect(takeLiveSessionMessage(), '로그인이 만료되었습니다. 다시 로그인하세요.');
      expect(takeLiveSessionMessage(), isNull);
    });

    test('동시에 거절돼도 로그아웃은 한 번이고, 새로 로그인하면 새 토큰을 쓴다', () async {
      expect(signIn('admin', samplePassword), isNull);
      await liveGet('/first').then((_) {}, onError: (_) {});
      expect(signIn('admin', samplePassword), isNull);
      final before = mockActivities.where((a) => a.text == '로그아웃').length;

      await Future.wait([
        liveGet('/a').then((_) {}, onError: (_) {}),
        liveGet('/b').then((_) {}, onError: (_) {}),
      ]);
      expect(mockActivities.where((a) => a.text == '로그아웃').length, before + 1);

      expired = false;
      expect(signIn('admin', samplePassword), isNull);
      await liveGet('/dashboard');
      expect(tokens.last, 'Bearer t$logins');
    });
  });

  test('회원: 가린 이름과 회원등급을 받고, 범위 밖 등급은 비워 둔다', () async {
    Map<String, Object?> member(String id, String? name, int? tier) => {
      'id': id,
      'username': id,
      'status': 'active',
      'joinedAt': '2026-10-28T03:20:00Z',
      'maskedName': name,
      'tier': tier,
    };
    serve(
      routes: {
        '/api/admin/live/members': _page([member('a', '홍*동', 1), member('b', null, 5), member('c', null, 9)]),
      },
    );
    await refreshLiveMembers();
    expect(liveMembers.map((m) => m.maskedName), ['홍*동', null, null]);
    expect(liveMembers.map((m) => m.gradeLabel), ['브론즈', 'VIP', null]);
  });

  test('전체 회원 목록: 기간·상태·계좌 조건을 쿼리로 보낸다', () async {
    final asked = <Uri>[];
    setLiveClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        asked.add(request.url);
        return http.Response.bytes(utf8.encode(jsonEncode(_routes[request.url.path] ?? _page([]))), 200);
      }),
    );
    await refreshLiveMembers();
    asked.clear();
    await liveAllLogs(filters: {'from': '2026-11-06', 'to': '2026-11-06', 'category': 'order'}, page: 1, pageSize: 50);
    expect(asked.single.queryParameters, {
      'from': '2026-11-06',
      'to': '2026-11-06',
      'category': 'order',
      'page': '1',
      'pageSize': '50',
    });
  });

  test('회원 내역: 100건 뒤의 주문·로그를 이어 받고 회차·청산 사유를 쓴다', () async {
    Map<String, Object?> order(int n) => {
      'orderedAt': DateTime.utc(2026, 11, 4, 12, 0, 10 - n).toIso8601String(), // API 는 최신순이라 뒤쪽일수록 오래됐다
      'symbolName': 'WTI',
      'side': 'sell',
      'qty': 1,
      'filledQty': 1,
      'status': 'filled',
      'kind': 'exit',
      'exitReason': 'stop_loss',
      'cycleNo': n,
    };
    Map<String, Object?> log(int n) => {
      'id': 'l$n',
      'at': DateTime.utc(2026, 11, 4, 12, 0, n).toIso8601String(),
      'category': 'order',
      'text': '기록 $n',
    };
    final asked = <Uri>[];
    setLiveClient(
      MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        asked.add(request.url);
        final page = request.url.queryParameters['page'];
        final Object? body = path == '$_base/orders'
            ? {
                'items': page == '2' ? [order(2)] : [order(1)],
                'total': 101,
              }
            : path == '$_base/logs'
            ? {
                'items': page == '2' ? [log(2)] : [log(1)],
                'total': 101,
              }
            : _routes[path];
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );
    await refreshLiveMembers();
    final m = liveMembers.single;
    await loadLiveMember(m);
    expect(liveMoreOrders(m), (100, 101));
    expect(liveMoreLogs(m), (100, 101));
    expect(ordersOf(m.id).single.cycleNo, 1);
    expect(ordersOf(m.id).single.exitReason, 'stop_loss');
    expect(liveExitLabel('stop_loss'), '손절');

    await loadMoreLiveOrders(m);
    await loadMoreLiveLogs(m);
    expect(ordersOf(m.id).map((o) => o.cycleNo), [1, 2]);
    expect(customerLogsOf(m.id).length, 2);
    expect(liveMoreOrders(m), isNull);
    expect(liveMoreLogs(m), isNull);
  });

  test('알람: 서버 종류와 진행 중 잡 회차를 쓰고, 전체 회차가 없으면 지어내지 않는다', () async {
    final asked = <Uri>[];
    setLiveClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        asked.add(request.url);
        return http.Response.bytes(utf8.encode(jsonEncode(_routes[request.url.path] ?? _page([]))), 200);
      }),
    );
    await refreshLiveMembers();
    asked.clear();
    await liveAllList('/workers', filters: {'kind': 'alert'}, page: 1, pageSize: 50);
    expect(asked.single.queryParameters['kind'], 'alert');

    Map<String, Object?> worker(String kind, List<Object?> jobs, {int cycles = 0}) => {
      'id': _workerId,
      'memberId': _memberId,
      'kind': kind,
      'cycleCount': cycles,
      'currentJobs': jobs,
    };
    final noCount = liveWorkerRow(
      worker('alert', [
        {'repeatCurrent': 0, 'repeatCount': null},
      ]),
    );
    expect(noCount.kind, '알람');
    expect(noCount.round, '0회차');

    final counted = liveWorkerRow(
      worker('paper', [
        {'repeatCurrent': 7, 'repeatCount': 100},
        {'repeatCurrent': 1, 'repeatCount': 100},
      ]),
    );
    expect(counted.kind, '모의');
    expect(counted.round, '7/100회차 외 1');
    expect(liveWorkerRow(worker('real', const [], cycles: 3)).round, '누적 3회');
    expect(liveWorkerRow(worker('real', const [], cycles: 0)).round, '-');
  });

  test('요청 횟수 제한: 로그인과 조회 모두 서버 안내를 보여 준다', () async {
    Future<Object?> errorOf(int loginStatus, int getStatus) async {
      setLiveClient(
        MockClient((request) async {
          final limited = jsonEncode({'message': '잠시 뒤 다시 시도하세요.'});
          if (request.url.path.endsWith('/auth/login')) {
            return loginStatus == 200
                ? http.Response(jsonEncode({'token': 't'}), 200)
                : http.Response.bytes(utf8.encode(limited), loginStatus);
          }
          return http.Response.bytes(utf8.encode(limited), getStatus);
        }),
      );
      try {
        await liveGet('/dashboard');
        return null;
      } on LiveApiException catch (e) {
        return e.message;
      }
    }

    expect(await errorOf(429, 200), '잠시 뒤 다시 시도하세요.');
    expect(await errorOf(200, 429), '잠시 뒤 다시 시도하세요.');
  });

  test('DB 오류면 서버 문구를 보여 주고 회원을 지어내지 않는다', () async {
    serve(status: 503);
    await refreshLiveMembers();
    expect(liveStatus.value.error, '테스트 DB 를 조회하지 못했습니다.');
    expect(liveMembers, isEmpty);
  });

  test('푸시 제목: 영문 구분값을 앱과 같은 한글로 바꾸고 모르는 값은 그대로 둔다', () {
    expect(liveNotificationTitle('ORDER'), '자동매매');
    expect(liveNotificationTitle('signal'), '신호 알림');
    expect(liveNotificationTitle('NEW_KIND'), 'NEW_KIND');
    expect(liveNotificationTitle(null), '-');
  });

  group('전략 설정: 앱 화면과 같은 항목', () {
    List<LiveSetting> items(String id, Map<String, dynamic> p, {String market = '해외선물'}) =>
        liveSettings(templateId: id, params: p, marketType: market, qtyUnit: '계약', isAlert: false, tick: (0.01, 10.0));

    test('트레일링 진입 하이브리드: 신호 주기 대신 카드 안 돌파 감지 타임프레임, 진입 간격에 환산 줄', () {
      final list = items('trailing_entry', {
        'direction': 'buy_only',
        'signal_timeframe': '1t',
        'order_type': 'market',
        'quantity': 1,
        'repeat_count': 5,
        'trailing_entry_step': 20,
        'trailing_entry_step_unit': 'tick',
        'switch_to_first_entry_breakout': true,
      });
      expect(list.map((i) => i.label), ['거래 방향', '주문 유형', '주문 수량', '진입 간격', '반복 횟수', '첫 진입 후 최초가 돌파로 전환 ✦ 하이브리드']);
      expect(list[3].note, '20tick / 0.2point / 200.00\$\n진입선 = 현재가 + 20틱 · 트레일링 스탑처럼 끝없이 따라갑니다');
      final hybrid = list.last;
      expect(hybrid.on, isTrue);
      expect(hybrid.value, '1회차는 트레일링 진입, 2회차부터 최초 체결가 돌파로 재진입');
      expect(hybrid.children.single.label, '돌파 감지 타임프레임');
      expect(hybrid.children.single.value, '실시간');
    });

    test('하이브리드 전 트레일링 잡은 신호 주기를 그대로 보여 준다', () {
      final list = items('trailing_entry', {'direction': 'sell_only', 'signal_timeframe': '1m', 'trailing_entry_step': 3});
      expect(list.map((i) => i.label), contains('신호 주기'));
      expect(list.map((i) => i.label), isNot(contains('첫 진입 후 최초가 돌파로 전환 ✦ 하이브리드')));
    });

    test('갭 하이브리드는 반복 2회 미만이면 꺼진 채 안내를 보여 준다', () {
      final list = items('gap_trading_breakout', {'repeat_count': 1, 'switch_to_first_entry_breakout': true});
      expect(list.last.on, isFalse);
      expect(list.last.value, '반복 횟수가 2회 이상일 때만 켤 수 있습니다');
    });

    test('돌파: 현재가 대비는 거리와 단위를 붙인다', () {
      final list = items('breakout', {
        'breakout_basis': 'current',
        'breakout_offset_unit': 'tick',
        'buy_target_set_price': 10,
        'sell_enabled': true,
        'sell_target_set_price': -10,
      });
      expect(list.firstWhere((i) => i.label == '매수').value, '현재가 대비 +10틱');
      expect(list.firstWhere((i) => i.label == '매도').value, '현재가 대비 -10틱');
    });

    test('직전봉 방향: 반복 횟수는 토글 아래 맨 끝, 옛 봉 주기 목록도 읽는다', () {
      final list = items('candle_direction_breakout', {
        'signal_timeframe': ['minute', 1, 100],
        'use_prev2_candle': false,
      });
      expect(list.last.label, '반복 횟수');
      expect(list.firstWhere((i) => i.label == '신호 주기').value, '1분');
    });
  });
}
