import 'dart:convert';

import 'package:dungeon_admin/live_api.dart';
import 'package:dungeon_admin/mock_accounts.dart';
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

  void serve({int status = 200}) {
    methods = [];
    setLiveClient(
      MockClient((request) async {
        methods.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        expect(request.headers['Authorization'], 'Bearer t');
        if (status != 200) {
          return http.Response.bytes(utf8.encode(jsonEncode({'message': '테스트 DB 를 조회하지 못했습니다.'})), status);
        }
        final body = _routes[request.url.path];
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
      containsAllInOrder(['돌파기준', '신호 주기', '주문 유형', '주문 수량', '잡 반복 횟수']),
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

  test('알림 검색: 아이디가 한 회원을 가리키면 그 회원의 알림을 받고, 아니면 내용을 찾는다', () async {
    final asked = <String>[];
    setLiveClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        asked.add(request.url.path);
        final path = request.url.path;
        final Object body = path.endsWith('/live/members')
            ? _page([
                {'id': 'm1', 'username': 'superman'},
                if (request.url.queryParameters['q'] == 'naver') {'id': 'm2', 'username': 'bossljo'},
              ])
            : _page([
                {'title': 'ORDER', 'body': '체결'},
              ]);
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );

    final byId = await liveNotifications(' Super ', page: 1, pageSize: 20);
    expect(asked.last, '/api/admin/live/members/m1/notifications');
    expect((byId['items'] as List).single['username'], 'superman');

    await liveNotifications('naver', page: 1, pageSize: 20); // 이메일로만 걸린 회원은 아이디 검색이 아니다
    expect(asked.last, '/api/admin/live/notifications');

    asked.clear();
    await liveNotifications('', page: 1, pageSize: 20);
    expect(asked, ['/api/admin/live/notifications']);
  });

  test('DB 오류면 서버 문구를 보여 주고 회원을 지어내지 않는다', () async {
    serve(status: 503);
    await refreshLiveMembers();
    expect(liveStatus.value.error, '테스트 DB 를 조회하지 못했습니다.');
    expect(liveMembers, isEmpty);
  });
}
