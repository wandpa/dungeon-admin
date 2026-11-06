/// 테스트 DB 조회 API(/api/admin/live) 연결. 조회만 하고 쓰기는 없다.
///
/// 응답을 화면이 쓰는 모델로 바꿔 넣는다. 회원·워커 ID 는 GUID 지만 화면은 정수 ID 로
/// 움직이므로 [liveIntId] 로 짝지어 둔다. API 에 없는 값은 지어내지 않고 비워 둔다.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'live_strategy.dart';
import 'mock_accounts.dart';
import 'mock_admin.dart';
import 'mock_data.dart';
import 'mock_system.dart' show SystemLevel;
import 'mock_workers.dart';

const _baseUrl = String.fromEnvironment('ADMIN_API', defaultValue: 'http://localhost:5185/api/admin');

/// 한 번에 보낼 잡 조회 수. 워커가 많은 회원이 있어 나눠서 보낸다.
const _batchSize = 6;

/// 응답 한 번에 받는 최대 건수. 주문·로그·알림은 최근 이만큼만 본다.
const liveListLimit = 100;

http.Client _client = http.Client();

@visibleForTesting
void setLiveClient(http.Client client) {
  _client = client;
  _token = null;
  _tokenFor = null;
}

class LiveApiException implements Exception {
  const LiveApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

final _intIds = <String, int>{};

/// GUID 에 짝지은 화면용 정수 ID. 샘플 ID 와 겹치지 않는다.
int liveIntId(String guid) => _intIds.putIfAbsent(guid, () => liveIdBase + _intIds.length);

String? _guidOf(int id) => _intIds.entries.where((e) => e.value == id).firstOrNull?.key;

String? _token;
String? _tokenFor;

/// 지금 로그인한 샘플 계정으로 API 토큰을 받는다.
Future<void> _signIn() async {
  final loginId = signedInAdmin.value?.loginId ?? 'admin';
  final http.Response res;
  try {
    res = await _client.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'loginId': loginId, 'password': samplePassword}),
    );
  } on http.ClientException {
    throw const LiveApiException('API 서버에 연결하지 못했습니다.');
  }
  if (res.statusCode != 200) throw const LiveApiException('API 로그인에 실패했습니다.');
  _token = (_json(res) as Map<String, dynamic>)['token'] as String;
  _tokenFor = loginId;
}

/// 화면이 직접 쓰는 조회. 경로는 /api/admin/live 뒤부터다.
Future<dynamic> liveGet(String path) => _get(path);

/// 전체 알림 검색. 서버는 제목·내용만 찾으므로, 아이디가 한 회원만 가리키면 그 회원의 알림을 받는다.
Future<Map<String, dynamic>> liveNotifications(String query, {required int page, required int pageSize}) async {
  final text = query.trim();
  final q = Uri.encodeQueryComponent(text);
  final paging = 'page=$page&pageSize=$pageSize';
  if (text.isNotEmpty) {
    final found = await _items('/members?q=$q&pageSize=$liveListLimit');
    bool named(Map<String, dynamic> m) => (m['username'] as String? ?? '').toLowerCase().contains(text.toLowerCase());
    final members = found.where(named).toList();
    if (members.length == 1) {
      final m = members.single;
      final body = await _get('/members/${m['id']}/notifications?$paging') as Map<String, dynamic>;
      return {
        ...body,
        'items': [
          for (final n in (body['items'] as List).cast<Map<String, dynamic>>()) {...n, 'username': m['username']},
        ],
      };
    }
  }
  return await _get('/notifications?q=$q&$paging') as Map<String, dynamic>;
}

Future<List<Map<String, dynamic>>> liveItems(String path) => _items(path);
double? liveDouble(Object? v) => _double(v);
DateTime? liveTime(Object? v) => _time(v);
SystemLevel liveLevel(Object? v) => SystemLevel.values.asNameMap()[v] ?? SystemLevel.degraded;
MemberIssue liveIssue(Map<String, dynamic> i) => _issue(i);

/// 아직 받지 않았으면 회원 목록을 받는다. 실패하면 오류를 낸다.
Future<void> ensureLiveMembers() async {
  if (liveStatus.value.revision == 0 || liveStatus.value.error != null) await refreshLiveMembers();
  final error = liveStatus.value.error;
  if (error != null) throw LiveApiException(error);
}

/// 서버가 만든 회원 CSV. 이메일은 가려져 있다.
Future<String> liveMembersCsv({String q = '', MemberStatus? status}) async {
  final query = [
    if (q.isNotEmpty) 'q=${Uri.encodeQueryComponent(q)}',
    if (status != null) 'status=${status.name}',
  ].join('&');
  final res = await _send(() => _client.get(Uri.parse('$_baseUrl/live/members/export?$query'), headers: _auth));
  return utf8.decode(res.bodyBytes).replaceFirst('\uFEFF', ''); // BOM 은 내려받을 때 붙인다
}

/// 이메일 전체 값. 서버가 열람을 활동 기록에 남긴다.
Future<String> liveEmail(Member m) async {
  final res = await _send(
    () => _client.post(
      Uri.parse('$_baseUrl/live/members/${m.liveId}/privacy-view'),
      headers: {..._auth, 'Content-Type': 'application/json'},
      body: jsonEncode({'field': 'email'}),
    ),
  );
  return (_json(res) as Map<String, dynamic>)['value'] as String;
}

Map<String, String> get _auth => {'Authorization': 'Bearer $_token'};

/// 토큰을 챙겨 요청을 보내고, 만료되면 한 번 다시 로그인한다. 실패하면 [LiveApiException].
Future<http.Response> _send(Future<http.Response> Function() request, {bool retry = true}) async {
  if (_token == null || _tokenFor != (signedInAdmin.value?.loginId ?? 'admin')) await _signIn();
  final http.Response res;
  try {
    res = await request();
  } on http.ClientException {
    throw const LiveApiException('API 서버에 연결하지 못했습니다.');
  }
  if (res.statusCode == 401 && retry) {
    _token = null;
    return _send(request, retry: false);
  }
  if (res.statusCode == 200) return res;
  if (res.statusCode == 403) throw const LiveApiException('권한이 없습니다.');
  if (res.statusCode == 404) throw const LiveApiException('대상을 찾지 못했습니다.');
  final body = res.bodyBytes.isEmpty ? null : _json(res);
  throw LiveApiException((body is Map ? body['message'] as String? : null) ?? '조회에 실패했습니다.');
}

Future<dynamic> _get(String path) async {
  final res = await _send(() => _client.get(Uri.parse('$_baseUrl/live$path'), headers: _auth));
  return _json(res);
}

dynamic _json(http.Response res) => jsonDecode(utf8.decode(res.bodyBytes));

Future<List<Map<String, dynamic>>> _items(String path) async {
  final body = await _get(path) as Map<String, dynamic>;
  return (body['items'] as List).cast<Map<String, dynamic>>();
}

double? _double(Object? v) => (v as num?)?.toDouble();
DateTime? _time(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

class LiveStatus {
  const LiveStatus({this.loading = false, this.error, this.revision = 0});
  final bool loading;
  final String? error;
  final int revision; // 다시 불러올 때마다 올라간다
}

final liveStatus = ValueNotifier(const LiveStatus());

/// 회원 목록을 다시 불러온다. 회원별 모니터링 값은 비워서 다음에 볼 때 새로 받는다.
Future<void> refreshLiveMembers() async {
  final revision = liveStatus.value.revision;
  liveStatus.value = LiveStatus(loading: true, revision: revision);
  try {
    final rows = <Map<String, dynamic>>[];
    for (var page = 1; ; page++) {
      final body = await _get('/members?page=$page&pageSize=$liveListLimit') as Map<String, dynamic>;
      rows.addAll((body['items'] as List).cast<Map<String, dynamic>>());
      if (rows.length >= (body['total'] as int) || (body['items'] as List).isEmpty) break;
    }
    // 받아 둔 값은 새 값이 올 때까지 두어 화면이 비지 않게 한다.
    _loaded.clear();
    _jobNames.clear();
    _workerLogs.clear();
    _loadedAt.clear();
    liveMembers
      ..clear()
      ..addAll(rows.map(_member));
    liveStatus.value = LiveStatus(revision: revision + 1);
  } on LiveApiException catch (e) {
    liveMembers.clear();
    liveStatus.value = LiveStatus(error: e.message, revision: revision + 1);
  }
}

Member _member(Map<String, dynamic> j) {
  final id = j['id'] as String;
  return Member(
    liveIntId(id),
    j['username'] as String,
    j['maskedEmail'] as String? ?? '-',
    _time(j['joinedAt'])!,
    _time(j['lastLoginAt']),
    MemberStatus.values.byName(j['status'] as String),
    device: j['device'] as String? ?? '-',
    watchlistCount: j['watchlistCount'] as int? ?? 0,
    liveId: id,
    liveWorkerCount: j['workerCount'] as int? ?? 0,
    liveRunningCount: j['runningWorkerCount'] as int? ?? 0,
  );
}

final _loaded = <int>{};
final _jobNames = <int, Map<String, String>>{}; // 회원별 잡 ID → 화면 이름
final _workerLogs = <int>{}; // 워커별 로그를 받은 워커

bool isLiveLoaded(Member m) => _loaded.contains(m.id);

final _loadedAt = <int, DateTime>{};

/// 마지막으로 회원 값을 받은 시각.
DateTime? liveLoadedAt(Member m) => _loadedAt[m.id];

/// 회원 값을 처음부터 다시 받는다. 실패하면 예외가 나고 이전 값은 그대로 남는다.
Future<void> reloadLiveMember(Member m) async {
  await loadLiveMember(m);
  // 로그가 새로 들어왔으니 워커별로 더 받았던 로그도 다시 받는다.
  _workerLogs.removeAll(workersOf(m.id).map((w) => w.id));
}

/// 회원의 워커·잡·계좌·포지션·주문·로그·알림을 받는다. 잡 내역은 잡을 고를 때 받는다.
Future<void> loadLiveMember(Member m) async {
  final base = '/members/${m.liveId}';
  // 하나가 실패해도 나머지 오류까지 함께 받아 첫 오류만 화면에 알린다.
  final rows = await Future.wait<dynamic>([
    _items('$base/accounts'),
    _items('$base/balances'),
    _items('$base/positions'),
    _items('$base/orders?pageSize=$liveListLimit'),
    _items('$base/logs?pageSize=$liveListLimit'),
    _items('$base/notifications?pageSize=$liveListLimit'),
    _get('$base/notification-state'),
    _get('$base/overview'),
    _items('$base/workers'),
  ]);
  final accountRows = rows[0] as List<Map<String, dynamic>>;
  final balanceRows = rows[1] as List<Map<String, dynamic>>;
  final positions = rows[2] as List<Map<String, dynamic>>;
  final orders = rows[3] as List<Map<String, dynamic>>;
  final logs = rows[4] as List<Map<String, dynamic>>;
  final notifications = rows[5] as List<Map<String, dynamic>>;
  final state = rows[6] as Map<String, dynamic>;
  final overview = rows[7] as Map<String, dynamic>;
  final workerRows = rows[8] as List<Map<String, dynamic>>;

  final jobNames = _jobNames[m.id] = {};
  final workers = <MemberWorker>[];
  for (var i = 0; i < workerRows.length; i += _batchSize) {
    final batch = workerRows.skip(i).take(_batchSize);
    workers.addAll(await Future.wait(batch.map((w) => _worker(base, w, jobNames))));
  }

  putLiveAccounts(
    m.id,
    accounts: [for (final a in accountRows) _account(a, balanceRows)],
    positions: [for (final p in positions) _position(p)],
    orders: [for (final o in orders) _order(o, jobNames)],
    notifications: [for (final n in notifications) _notification(n)],
    state: _notificationState(state),
  );
  putLiveWorkers(m.id, workers, [for (final l in logs) _log(l, jobNames)]);
  final issues = overview['issues'] as List? ?? const [];
  putLiveIssues(m.id, [for (final i in issues.cast<Map<String, dynamic>>()) _issue(i)]);
  _loaded.add(m.id);
  _loadedAt[m.id] = DateTime.now();
}

Future<MemberWorker> _worker(String base, Map<String, dynamic> w, Map<String, String> jobNames) async {
  final id = w['id'] as String;
  Future<List<Map<String, dynamic>>> jobs(String status) => _items('$base/workers/$id/jobs?status=$status');
  final rows = [
    if (w['jobCount'] != 0) ...await jobs('current'),
    if (w['finishedJobCount'] != 0) ...await jobs('finished'),
  ];
  // 앱은 같은 이름의 잡을 여러 개 둘 수 있다. 화면은 이름으로 잡을 찾으므로 등록 시각을 붙여 구분한다.
  final counts = <String, int>{};
  for (final j in rows) {
    counts.update(j['name'] as String? ?? '-', (n) => n + 1, ifAbsent: () => 1);
  }
  String nameOf(Map<String, dynamic> j) {
    final name = j['name'] as String? ?? '-';
    if (counts[name] == 1) return name;
    final at = _time(j['insertedAt']);
    return at == null ? name : '$name · ${formatDateTime(at)}';
  }

  for (final j in rows) {
    jobNames[j['id'] as String] = nameOf(j);
  }
  final detail = await _get('$base/workers/$id') as Map<String, dynamic>;
  return MemberWorker(
    id: liveIntId(id),
    symbolCode: w['symbolCode'] as String? ?? '-',
    symbolName: w['symbolName'] as String? ?? '-',
    marketType: w['marketType'] as String? ?? '-',
    status: w['status'] == 'running' ? WorkerStatus.running : WorkerStatus.stopped,
    insertedAt: _time(w['insertedAt'])!,
    currency: w['currency'] as String? ?? '',
    currentPrice: null, // DB 에 시세가 없다
    autoCloseOnMarketEnd: detail['autoCloseOnMarketEnd'] as bool? ?? false,
    pnlLimit: _pnlLimit(detail['pnlLimit'] as Map<String, dynamic>?),
    jobs: [
      for (final j in rows)
        if (j['hidden'] != true) _job(j, nameOf(j)),
    ],
  );
}

MemberIssue _issue(Map<String, dynamic> i) {
  final workerId = i['workerId'] as String?;
  return MemberIssue(
    MemberIssueKind.values.asNameMap()[i['kind']] ?? MemberIssueKind.memberStatus,
    i['label'] as String? ?? '',
    workerId: workerId == null ? null : liveIntId(workerId),
  );
}

bool isLiveWorkerLogsLoaded(int workerId) => _workerLogs.contains(workerId);

/// 회원 로그는 최근 건만 받으므로, 워커를 고르면 그 워커의 로그를 더 받는다.
Future<void> loadLiveWorkerLogs(Member m, int workerId) async {
  await _mergeLogs(m, 'workerId=${_guidOf(workerId)}');
  _workerLogs.add(workerId);
}

Future<void> _mergeLogs(Member m, String query) async {
  final rows = await _items('/members/${m.liveId}/logs?$query&pageSize=$liveListLimit');
  addLiveLogs(m.id, [for (final l in rows) _log(l, _jobNames[m.id] ?? const {})]);
}

WorkerPnlLimit? _pnlLimit(Map<String, dynamic>? j) {
  if (j == null || j['enabled'] != true) return null;
  return WorkerPnlLimit(
    period: j['period'] as String? ?? 'none',
    unit: j['unit'] as String? ?? 'amount',
    profitTarget: _double(j['profitTarget']),
    lossLimit: _double(j['lossLimit']),
    accumAmount: _double(j['accumAmount']) ?? 0,
    accumTicks: _double(j['accumTicks']) ?? 0,
    accumCount: j['accumCount'] as int? ?? 0,
    stoppedAt: _time(j['stoppedAt']),
    stopReason: j['stopReason'] as String?,
  );
}

WorkerJob _job(Map<String, dynamic> j, String name) {
  final position = j['position'] as Map<String, dynamic>?;
  final qty = _double(j['qty']) ?? 0;
  return WorkerJob(
    name: name,
    status: j['status'] as String? ?? '',
    accountName: j['accountName'] as String? ?? '-',
    isPaper: j['isPaper'] as bool? ?? false,
    strategy: JobStrategy(j['templateId'] as String? ?? '', qty: qty),
    mode: j['mode'] as String? ?? 'trade',
    isActive: j['isActive'] as bool? ?? false,
    entrySide: j['entrySide'] as String? ?? 'buy',
    repeatCurrent: j['repeatCurrent'] as int? ?? 0,
    repeatCount: j['repeatCount'] as int? ?? 1,
    position: position == null ? null : _jobPosition(position),
    liveId: j['id'] as String,
    fixedRealizedPnl: _double(j['realizedPnl']) ?? 0,
    accountNumber: j['maskedAccountNumber'] as String?,
    endReason: j['endReason'] as String?,
  );
}

JobPosition _jobPosition(Map<String, dynamic> p) => JobPosition(
  side: p['side'] as String? ?? '',
  size: _double(p['size']) ?? 0,
  entryPrice: _double(p['entryPrice']) ?? 0,
  multiplier: _double(p['multiplier']) ?? 1,
);

/// 잡 설정과 회차·타임라인을 받아 채운 잡을 돌려준다.
Future<WorkerJob> loadLiveJobDetail(Member m, WorkerJob job) async {
  final base = '/members/${m.liveId}/jobs/${job.liveId}';
  final rows = await Future.wait<dynamic>([_get(base), _items('$base/cycles'), _items('$base/events')]);
  final cycles = rows[1] as List<Map<String, dynamic>>;
  final events = rows[2] as List<Map<String, dynamic>>;
  await _mergeLogs(m, 'jobId=${job.liveId}');
  final params = (rows[0] as Map<String, dynamic>)['templateParams'] as Map<String, dynamic>?;
  final worker = workersOf(m.id).where((w) => w.jobs.contains(job)).firstOrNull;
  int no(Map<String, dynamic> c) => c['cycleNo'] as int? ?? 0;
  final newestFirst = [...cycles]..sort((a, b) => no(b).compareTo(no(a)));
  final tick = await _tickOf(worker);
  final filled = job.withDetail(_strategy(job.strategy.templateId, job.strategy.qty, params, worker, job, tick), [
    for (final c in newestFirst) _cycle(c, events),
    if (events.any((e) => e['cycleNo'] == null)) _looseEvents(events),
  ]);
  replaceLiveJob(m.id, job, filled);
  return filled;
}

/// 회차가 없는 이벤트. 빠뜨리지 않고 회차 밖 칸으로 따로 보여 준다.
JobCycle _looseEvents(List<Map<String, dynamic>> events) => JobCycle(
  cycleNo: 0,
  status: 'none',
  strategy: null,
  events: [
    for (final e in events)
      if (e['cycleNo'] == null) _event(e),
  ]..sort((a, b) => a.at.compareTo(b.at)),
);

JobCycle _cycle(Map<String, dynamic> c, List<Map<String, dynamic>> events) {
  final no = c['cycleNo'] as int;
  final mine = [
    for (final e in events)
      if (e['cycleNo'] == no) _event(e),
  ]..sort((a, b) => a.at.compareTo(b.at));
  return JobCycle(
    cycleNo: no,
    status: c['status'] as String? ?? '',
    strategy: null, // 회차 카드는 수량·보유시간만 쓴다
    multiplier: _double(c['multiplier']) ?? 1,
    filledBuyQty: _double(c['filledBuyQty']),
    avgBuyPrice: _double(c['avgBuyPrice']),
    filledSellQty: _double(c['filledSellQty']),
    avgSellPrice: _double(c['avgSellPrice']),
    realizedPnl: _double(c['realizedPnl']),
    openedAt: _time(c['openedAt']),
    closedAt: _time(c['closedAt']),
    events: mine,
    side: c['side'] as String?,
  );
}

JobEvent _event(Map<String, dynamic> e) {
  final price = _double(e['price']);
  return JobEvent(
    _time(e['eventAt'])!,
    e['eventType'] as String? ?? '',
    side: e['side'] as String?,
    qty: _double(e['qty']),
    price: price == 0 ? null : price, // 체결 전 이벤트는 0 으로 온다
    message: e['message'] as String?,
    group: e['group'] as String?,
    exitReason: e['exitReason'] as String?,
  );
}

/// 앱과 같이 값이 있으면 켜진 것으로 본다. 단위는 시장이 정한다(국내주식 %, 나머지 틱).
final _ticks = <String, (double, double)?>{};

/// 틱 크기와 틱 가치. 월물 마스터에서 찾는다. 없으면 환산 줄만 빠지고 화면은 그대로 뜬다.
Future<(double, double)?> _tickOf(MemberWorker? worker) async {
  if (worker == null || !worker.marketType.contains('해외')) return null;
  final code = worker.symbolCode;
  if (_ticks.containsKey(code)) return _ticks[code];
  final product = RegExp(r'^(.+)[FGHJKMNQUVXZ]\d{2}$').firstMatch(code)?.group(1);
  if (product == null) return null;
  try {
    final months = await _items('/symbols/${Uri.encodeComponent(product)}/months?pageSize=100');
    final month = months.where((m) => m['code'] == code).firstOrNull;
    final size = _double(month?['tickSize']);
    final value = _double(month?['tickValue']);
    return _ticks[code] = size == null || value == null ? null : (size, value);
  } on LiveApiException {
    return null;
  }
}

JobStrategy _strategy(
  String templateId,
  double qty,
  Map<String, dynamic>? p,
  MemberWorker? worker,
  WorkerJob job,
  (double, double)? tick,
) {
  final params = p ?? const <String, dynamic>{};
  final market = worker?.marketType ?? '';
  final unit = market == '국내주식' ? '%' : '틱';
  double? risk(String use, String value) {
    final v = _double(params[value]);
    return params[use] == false || v == null ? null : v.abs();
  }

  final trailingOn =
      params['use_trailing_stop'] != false &&
      (params['trailing_stop_step'] != null || params['breakeven_trigger_value'] != null);
  return JobStrategy(
    templateId,
    qty: qty,
    stopLossPct: risk('use_stop_loss', 'stop_loss_value'),
    takeProfitPct: risk('use_take_profit', 'take_profit_value'),
    stopLossUnit: unit,
    takeProfitUnit: unit,
    orderType: params['order_type'] == 'limit' ? '지정가' : '시장가',
    trailingStop: liveTrailingRows(params, unit),
    liveTrailingOn: trailingOn,
    tickSize: tick?.$1,
    tickValue: tick?.$2,
    liveExitCards: liveExitCards(params, isAlert: job.isAlert),
    conditions: liveConditions(params),
    liveItems: liveSettings(
      templateId: templateId,
      params: params,
      marketType: market,
      qtyUnit: worker?.qtyUnit ?? '',
      isAlert: job.isAlert,
    ),
    liveName: params['job_name'] as String?,
  );
}

MemberAccount _account(Map<String, dynamic> a, List<Map<String, dynamic>> balances) {
  final id = a['accountId'];
  final balance = balances.where((b) => b['accountId'] == id).firstOrNull;
  return MemberAccount(
    a['accountName'] as String? ?? '-',
    a['maskedAccountNumber'] as String? ?? '-',
    a['marketType'] as String? ?? '-',
    balance?['currency'] as String? ?? '',
    deposit: _double(balance?['deposit']) ?? 0,
    orderableCash: _double(balance?['orderableCash']) ?? 0,
    totalEval: _double(balance?['totalEval']) ?? 0,
    snapshotAt: _time(balance?['snapshotAt']) ?? DateTime.now(),
    isPaper: a['isPaper'] as bool? ?? false,
    brokerCode: a['brokerCode'] as String? ?? '-',
    isActive: a['isActive'] as bool? ?? true,
    hasBalance: balance != null,
  );
}

AccountPosition _position(Map<String, dynamic> p) {
  final workerId = p['workerId'] as String?;
  return AccountPosition(
    symbolCode: p['symbolCode'] as String? ?? '-',
    symbolName: p['symbolName'] as String? ?? '-',
    currency: p['currency'] as String? ?? '',
    qtyUnit: p['qtyUnit'] as String? ?? '',
    accountName: p['accountName'] as String? ?? '-',
    position: _jobPosition(p),
    currentPrice: null,
    workerId: workerId == null ? null : liveIntId(workerId),
    jobName: p['isManual'] == true ? null : p['jobName'] as String?,
  );
}

AccountOrder _order(Map<String, dynamic> o, Map<String, String> jobNames) {
  final workerId = o['workerId'] as String?;
  return AccountOrder(
    at: _time(o['orderedAt'])!,
    symbolName: o['symbolName'] as String? ?? '-',
    side: o['side'] as String?,
    qty: _double(o['qty']) ?? 0,
    filledQty: _double(o['filledQty']) ?? 0,
    status: o['status'] as String? ?? '',
    qtyUnit: o['qtyUnit'] as String? ?? '',
    accountName: o['accountName'] as String? ?? '-',
    jobName: jobNames[o['jobId']] ?? o['jobName'] as String? ?? '-',
    workerId: workerId == null ? null : liveIntId(workerId),
    currency: o['currency'] as String? ?? '',
    multiplier: _double(o['multiplier']) ?? 1,
    isPaper: o['isPaper'] as bool? ?? false,
    avgFillPrice: _double(o['avgFillPrice']),
    message: o['message'] as String?,
  );
}

CustomerLog _log(Map<String, dynamic> l, Map<String, String> jobNames) {
  final workerId = l['workerId'] as String?;
  return CustomerLog(
    _time(l['at'])!,
    CustomerLogCategory.values.asNameMap()[l['category']] ?? CustomerLogCategory.worker,
    l['text'] as String? ?? '',
    workerId: workerId == null ? null : liveIntId(workerId),
    jobName: jobNames[l['jobId']] ?? l['jobName'] as String?,
  );
}

NotificationMessage _notification(Map<String, dynamic> n) => NotificationMessage(
  _time(n['sentAt'])!,
  n['title'] as String? ?? '',
  n['body'] as String? ?? '',
  n['accountName'] as String? ?? '',
  isRead: n['isRead'] as bool? ?? false,
);

NotificationState _notificationState(Map<String, dynamic> s) => NotificationState(
  pushAllowed: false,
  hasToken: s['hasToken'] as bool? ?? false,
  onServer: s['onServer'] as bool? ?? false,
  deviceSettingsKnown: false,
);
