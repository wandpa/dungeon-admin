/// 회원 모니터링의 모드·계좌·주문·알림 샘플. 필드와 상태값은 dungeon-app 의
/// TradeMode, AccountEntity, AccountBalanceEntity, AccountOrderEntity,
/// NotificationMessage, NotifDiagnosis 에 맞춘다.
///
/// 포지션·주문·알림은 워커 샘플의 잡과 회차에서 만들어, 화면끼리 숫자가 어긋나지 않게 한다.
library;

import 'deep_link.dart';
import 'mock_admin.dart';
import 'mock_data.dart';
import 'mock_workers.dart';

/// 앱 TradeMode. 앱은 기기에만 저장하므로 실제로 보려면 앱이 서버로 보내야 한다.
enum TradeMode {
  real('실매매'),
  paper('모의투자'),
  alert('알람');

  const TradeMode(this.label);
  final String label;
}

TradeMode tradeModeOf(int memberId) => _modes[memberId] ?? TradeMode.real;

const _modes = {1018: TradeMode.alert};

class MemberAccount {
  const MemberAccount(
    this.name,
    this.cano,
    this.marketType,
    this.currency, {
    required this.deposit,
    required this.orderableCash,
    required this.totalEval,
    required this.snapshotAt,
    this.isPaper = false,
    this.kind,
    this.brokerCode = 'KIS',
    this.isActive = true,
    this.hasBalance = true,
    this.tokenStatus,
    this.tokenExpiresAt,
    this.tokenUpdatedAt,
    this.nxtEnabled,
    this.usPremarketEnabled,
    this.usAftermarketEnabled,
  });

  final String name;
  final String cano;
  final String marketType;
  final String currency;
  final double deposit; // 예수금
  final double orderableCash; // 주문가능금액
  final double totalEval; // 총평가금액
  final DateTime snapshotAt;
  final bool isPaper;
  final String? kind; // real | paper | alert. 샘플 계좌는 비어 있다
  final String brokerCode;
  final bool isActive;
  final bool hasBalance; // 테스트 DB 는 잔고 기록이 없는 계좌가 있다
  final String? tokenStatus; // none | valid | expired. 샘플 계좌는 비어 있다
  final DateTime? tokenExpiresAt;
  final DateTime? tokenUpdatedAt;
  final bool? nxtEnabled; // 국내주식 NXT(대체거래소) 거래
  final bool? usPremarketEnabled; // 미국주식 장전 거래
  final bool? usAftermarketEnabled; // 미국주식 장후 거래

  /// 앱 계좌 설정의 거래 시간 옵션 한 줄. 샘플 계좌와 알람 계좌는 없다.
  String? get sessionLine {
    if (isAlert || nxtEnabled == null) return null;
    String on(bool? v) => v == true ? '켜짐' : '꺼짐';
    return 'NXT ${on(nxtEnabled)} · 미국 장전 ${on(usPremarketEnabled)} · 장후 ${on(usAftermarketEnabled)}';
  }

  /// 증권사 접속 토큰 상태 한 줄. 알람 계좌는 토큰을 쓰지 않는다.
  String? get tokenLine {
    if (isAlert || tokenStatus == null) return null;
    final until = tokenExpiresAt == null ? '' : ' · 만료 ${formatDateTime(tokenExpiresAt!)}';
    return switch (tokenStatus) {
      'valid' => '토큰 유효$until',
      'expired' => '토큰 만료됨$until',
      _ => '토큰 기록 없음',
    };
  }

  /// 목록에서는 계좌번호 뒤 네 자리만 보여 준다.
  String get maskedCano => cano.length <= 4 ? cano : '****${cano.substring(cano.length - 4)}';

  /// 알람 계좌. 앱키가 없고 주문을 내지 않는다.
  bool get isAlert => kind == 'alert';

  /// 앱 총자산과 같은 계산: 보유 평가금액 + 주문가능금액.
  double get totalAsset => totalEval + orderableCash;
}

/// 보유 포지션. [jobName] 이 없으면 앱의 "연결된 job이 없음"(수동) 포지션이다.
class AccountPosition {
  const AccountPosition({
    required this.symbolCode,
    required this.symbolName,
    required this.currency,
    required this.qtyUnit,
    required this.accountName,
    required this.position,
    required this.currentPrice,
    this.workerId,
    this.jobName,
  });

  final String symbolCode;
  final String symbolName;
  final String currency;
  final String qtyUnit;
  final String accountName;
  final JobPosition position;
  final double? currentPrice; // 테스트 DB 에는 시세가 없어 비어 있다
  final int? workerId;
  final String? jobName;

  double? get unrealizedPnl => position.pnlAt(currentPrice);
}

class AccountOrder {
  const AccountOrder({
    required this.at,
    required this.symbolName,
    required this.side,
    required this.qty,
    required this.filledQty,
    required this.status,
    required this.qtyUnit,
    required this.accountName,
    required this.jobName,
    this.workerId,
    this.currency = 'KRW',
    this.multiplier = 1,
    this.isPaper = false,
    this.avgFillPrice,
    this.message,
    this.buyPrice,
    this.sellPrice,
    this.realizedPnl,
    this.kind,
    this.exitReason,
    this.cycleNo,
    this.liveId,
    this.fillCount,
    this.judgePrice,
  });

  final String? liveId; // 테스트 DB 주문 GUID. 체결 내역을 받을 때 쓴다
  final int? fillCount; // 증권사 체결 건수. 분할 체결이면 2 이상
  final double? judgePrice; // 엔진이 주문을 판단한 가격
  final String? kind; // entry | exit
  final String? exitReason;
  final int? cycleNo;
  final DateTime at;
  final int? workerId;
  final String currency;
  final double multiplier; // 계약승수
  final bool isPaper;
  final String symbolName;
  final String? side; // buy | sell
  final double qty;
  final double filledQty;
  final String status; // submitted | accepted | partial | filled | rejected | failed | cancelled
  final String qtyUnit;
  final String accountName;
  final String jobName;
  final double? avgFillPrice;
  final String? message;
  // 청산 주문만 있다. 그 회차의 평균 매수가·매도가와 실현손익이다.
  final double? buyPrice;
  final double? sellPrice;
  final double? realizedPnl;

  String get sideLabel => switch (side) {
    'buy' => '매수',
    'sell' => '매도',
    _ => '',
  };

  /// 체결 금액: 체결가 × 체결수량 × 계약승수.
  double get filledAmount => (avgFillPrice ?? 0) * filledQty * multiplier;

  /// 앱 계좌 화면과 같은 표기.
  String get statusLabel => switch (status) {
    'submitted' => '전송',
    'accepted' => '접수',
    'partial' => '부분체결',
    'filled' => '체결완료',
    'rejected' => '거부',
    'failed' => '실패',
    'cancelled' => '취소',
    _ => status,
  };

  /// 앱 거래 내역의 갈래. 체결수량이 조금이라도 있으면 체결이다.
  bool get isFilled => filledQty > 0;
  bool get isRejected => status == 'rejected';
  bool get isWaiting => !isFilled && const {'sent', 'submitted', 'pending', 'accepted', 'open', 'new'}.contains(status);
}

/// 앱 알림 설정 화면의 값. 서버 등록 외에는 기기에서 정해지는 값이다.
class NotificationState {
  const NotificationState({
    required this.pushAllowed,
    this.supported = true,
    this.permitted = true,
    this.hasToken = true,
    this.onServer = true,
    this.sound = true,
    this.vibration = true,
    this.banner = true,
    this.deviceSettingsKnown = true,
  });

  final bool pushAllowed;
  final bool supported;
  final bool permitted;
  final bool hasToken;
  final bool onServer;
  final bool sound;
  final bool vibration;
  final bool banner;
  final bool deviceSettingsKnown; // false 면 토큰·서버 등록 외의 값은 모른다
}

class NotificationMessage {
  const NotificationMessage(this.sentAt, this.title, this.body, this.accountName, {required this.isRead});

  final DateTime sentAt;
  final String title;
  final String body;
  final String accountName;
  final bool isRead;
}

/// 푸시 발송 그룹.
class PushGroup {
  const PushGroup(this.label, this.includes);
  final String label;
  final bool Function(Member) includes;
}

bool _usesMarket(Member m, String market) => workersOf(m.id).any((w) => w.marketType == market);

final pushGroups = <PushGroup>[
  PushGroup('워커 실행 중', (m) => workersOf(m.id).any((w) => w.status == WorkerStatus.running)),
  PushGroup('보유 포지션 있음', (m) => positionsOf(m.id).isNotEmpty),
  PushGroup('해외선물 사용', (m) => _usesMarket(m, '해외선물')),
  PushGroup('국내주식 사용', (m) => _usesMarket(m, '국내주식')),
  PushGroup('오류 워커 있음', (m) => workersOf(m.id).any((w) => w.status == WorkerStatus.error)),
  PushGroup('휴면 회원', (m) => m.status == MemberStatus.dormant),
];

/// 푸시 대상이 될 수 있는 회원. 승인 전 회원은 앱을 쓴 적이 없어 뺀다.
List<Member> pushableMembers() => [
  for (final m in mockMembers)
    if (m.status != MemberStatus.pending) m,
];

/// 푸시를 받을 수 없는 이유. 받을 수 있으면 null. 사용자가 거부한 회원에게는 보내지 않는다.
String? pushBlockReason(Member m) {
  if (m.status == MemberStatus.deleteRequested) return '탈퇴 요청';
  final s = notificationStateOf(m);
  if (!s.pushAllowed) return '푸시 거부';
  if (!s.hasToken || !s.onServer) return '푸시 서버 미등록';
  return null;
}

final _sentPushes = <int, List<NotificationMessage>>{};

void resetSentPushes() => _sentPushes.clear();

/// 푸시를 발송 이력과 받는 회원의 알림 이력에 남긴다. 샘플이라 실제로 나가지는 않는다.
void sendPush(String title, String body, String target, List<Member> receivers, {DeepLink link = DeepLink.none}) {
  final now = DateTime.now();
  mockPushes.insert(0, PushMessage(mockPushes.first.id + 1, title, body, target, now, receivers.length, 0, link: link));
  for (final m in receivers) {
    (_sentPushes[m.id] ??= []).insert(0, NotificationMessage(now, title, body, '', isRead: false));
  }
  logActivity(ActivityKind.push, '「$title」 $target ${receivers.length}명 발송');
}

enum MemberIssueKind {
  worker,
  workerStopped,
  waitingOrders,
  rejectedOrders,
  manualPositions,
  notification,
  memberStatus,
}

/// 상담 전에 먼저 봐야 할 문제 하나. 앱에서 사용자가 겪을 일을 관리자 말로 옮긴 것이다.
class MemberIssue {
  const MemberIssue(this.kind, this.label, {this.workerId, this.detail});
  final MemberIssueKind kind;
  final String label;
  final int? workerId; // 누르면 이 워커로 이동한다
  final double? detail; // 건수
}

/// 전체 계좌 기준으로 문제를 모은다. 계좌를 골라도 문제는 숨기지 않는다.
List<MemberIssue> issuesOf(Member m) {
  if (m.isLive) return _liveIssues[m.id] ?? const [];
  final workers = workersOf(m.id);
  final orders = ordersOf(m.id);
  final errors = workers.where((w) => w.status == WorkerStatus.error).toList();
  final limited = workers.where((w) => w.pnlLimit?.stoppedAt != null).toList();
  final waiting = orders.where((o) => o.isWaiting).length;
  final rejected = orders.where((o) => o.isRejected).length;
  final manual = positionsOf(m.id).where((p) => p.jobName == null).length;
  final s = notificationStateOf(m);
  final push = !s.pushAllowed
      ? '푸시 꺼짐'
      : !s.permitted
      ? '알림 권한 꺼짐'
      : !s.hasToken
      ? '기기 토큰 없음'
      : !s.onServer
      ? '푸시 서버 미등록'
      : null;
  return [
    if (m.status == MemberStatus.suspended)
      MemberIssue(MemberIssueKind.memberStatus, '이용 정지: ${m.suspendReason ?? '-'}'),
    if (m.accessBlocked) MemberIssue(MemberIssueKind.memberStatus, '접속 차단: ${m.accessBlockReason ?? '-'}'),
    if (errors.isNotEmpty) MemberIssue(MemberIssueKind.worker, '오류 워커 ${errors.length}', workerId: errors.first.id),
    if (limited.isNotEmpty)
      MemberIssue(MemberIssueKind.worker, '한도 종료 워커 ${limited.length}', workerId: limited.first.id),
    if (waiting > 0) MemberIssue(MemberIssueKind.waitingOrders, '미체결 주문 $waiting'),
    if (rejected > 0) MemberIssue(MemberIssueKind.rejectedOrders, '거부 주문 $rejected'),
    if (manual > 0) MemberIssue(MemberIssueKind.manualPositions, '수동 포지션 $manual'),
    if (push != null) MemberIssue(MemberIssueKind.notification, push),
  ];
}

final _liveAccounts = <int, List<MemberAccount>>{};
final _livePositions = <int, List<AccountPosition>>{};
final _liveOrders = <int, List<AccountOrder>>{};
final _liveNotifications = <int, List<NotificationMessage>>{};
final _liveStates = <int, NotificationState>{};
final _liveIssues = <int, List<MemberIssue>>{};

void putLiveIssues(int memberId, List<MemberIssue> issues) => _liveIssues[memberId] = issues;

/// 테스트 DB 에서 받은 회원의 계좌·포지션·주문·알림을 넣는다.
void putLiveAccounts(
  int memberId, {
  required List<MemberAccount> accounts,
  required List<AccountPosition> positions,
  required List<AccountOrder> orders,
  required List<NotificationMessage> notifications,
  required NotificationState state,
}) {
  _liveAccounts[memberId] = accounts;
  _livePositions[memberId] = positions;
  _liveOrders[memberId] = orders;
  _liveNotifications[memberId] = notifications;
  _liveStates[memberId] = state;
}

List<MemberAccount> accountsOf(int memberId) => _liveAccounts[memberId] ?? _accounts[memberId] ?? const [];

/// 회원과 함께 묶은 포지션.
class MemberPosition {
  const MemberPosition(this.member, this.position, this.isPaper);
  final Member member;
  final AccountPosition position;
  final bool isPaper;
}

/// 전체 회원의 포지션. 승인 전 회원은 포지션이 없다.
List<MemberPosition> allMemberPositions() => [
  for (final m in mockMembers)
    for (final p in positionsOf(m.id))
      MemberPosition(m, p, accountsOf(m.id).any((a) => a.name == p.accountName && a.isPaper)),
];

/// [accountName] 을 주면 그 계좌, 없으면 전체 계좌의 포지션.
List<AccountPosition> positionsOf(int memberId, {String? accountName}) => [
  for (final p in _livePositions[memberId] ?? const <AccountPosition>[])
    if (accountName == null || p.accountName == accountName) p,
  if (!_livePositions.containsKey(memberId))
    for (final w in workersOf(memberId))
      for (final j in w.jobs)
        if (j.position != null && (accountName == null || j.accountName == accountName))
          AccountPosition(
            symbolCode: w.symbolCode,
            symbolName: w.symbolName,
            currency: w.currency,
            qtyUnit: w.qtyUnit,
            accountName: j.accountName,
            position: j.position!,
            currentPrice: w.currentPrice,
            workerId: w.id,
            jobName: j.name,
          ),
  for (final p in _manualPositions[memberId] ?? const <AccountPosition>[])
    if (accountName == null || p.accountName == accountName) p,
];

/// 잡 회차의 이벤트로 주문 목록을 만든다. 최신 주문이 앞에 온다.
/// 더 받은 주문을 뒤에 붙인다. 그사이 새 주문이 들어와 쪽이 밀리면 겹치는 줄은 건너뛴다.
void addLiveOrders(int memberId, List<AccountOrder> orders) {
  final list = _liveOrders[memberId];
  if (list == null) return;
  // 테스트 DB 주문은 ID 로, 샘플은 시각·종목·방향·계좌로 같은 주문을 가린다.
  Object key(AccountOrder o) => o.liveId ?? (o.at, o.symbolName, o.side, o.accountName);
  final known = {for (final o in list) key(o)};
  list
    ..addAll(orders.where((o) => known.add(key(o))))
    ..sort((a, b) => b.at.compareTo(a.at)); // 새로 받은 최신 주문도 맨 위에 온다
}

List<AccountOrder> ordersOf(int memberId, {String? accountName}) {
  final live = _liveOrders[memberId];
  if (live != null) {
    return [
      for (final o in live)
        if (accountName == null || o.accountName == accountName) o,
    ];
  }
  final orders = <AccountOrder>[];
  for (final w in workersOf(memberId)) {
    for (final j in w.jobs) {
      if (j.isAlert || (accountName != null && j.accountName != accountName)) continue;
      for (final c in j.cycles) {
        JobEvent? pending;
        AccountOrder order(String status, DateTime at, {double? filled, double? price, String? message}) =>
            AccountOrder(
              at: at,
              symbolName: w.symbolName,
              side: pending?.side,
              qty: pending?.qty ?? j.strategy.qty,
              filledQty: filled ?? 0,
              status: status,
              qtyUnit: w.qtyUnit,
              accountName: j.accountName,
              jobName: j.name,
              workerId: w.id,
              currency: w.currency,
              multiplier: c.multiplier,
              isPaper: j.isPaper,
              avgFillPrice: price,
              message: message,
            );
        for (final e in c.events) {
          switch (e.type) {
            case 'order_submitted':
              pending = e;
            case 'fill' when pending != null:
              orders.add(order('filled', e.at, filled: e.qty, price: e.price));
              pending = null;
            case 'order_rejected' when pending != null:
              orders.add(order('rejected', e.at, message: e.message));
              pending = null;
          }
        }
        if (pending != null) orders.add(order('accepted', pending.at));
      }
    }
  }
  return orders..sort((a, b) => b.at.compareTo(a.at));
}

/// 막대 한 줄.
class BarRow {
  const BarRow(this.label, this.value, this.detail);
  final String label;
  final int value;
  final String detail;
}

/// 회사 전체 운영 지표.
class CompanyStats {
  const CompanyStats({
    required this.strategyCount,
    required this.currentJobs,
    required this.finishedJobs,
    required this.workers,
    required this.runningWorkers,
    required this.errorWorkers,
    required this.positions,
    required this.manualPositions,
    required this.jobsBySymbol,
    required this.jobsByStrategy,
  });

  final int strategyCount;
  final int currentJobs;
  final int finishedJobs;
  final int workers;
  final int runningWorkers;
  final int errorWorkers;
  final int positions;
  final int manualPositions;
  final List<BarRow> jobsBySymbol;
  final List<BarRow> jobsByStrategy;
}

/// 전체 회원의 워커·잡을 집계한다. 표에 다 싣기 많은 종목은 상위 [topSymbols] 뒤로 "기타"에 묶는다.
CompanyStats companyStats({int topSymbols = 8}) {
  final workers = [for (final m in mockMembers) ...workersOf(m.id)];
  final jobs = [for (final w in workers) ...w.jobs];
  final current = jobs.where((j) => !j.isFinished).toList();
  final positions = [for (final m in mockMembers) ...positionsOf(m.id)];

  // 앱의 전략 묶음에 해당한다. 샘플에서는 회원별로 서로 다른 전략 설정 수를 센다.
  var strategyCount = 0;
  for (final m in mockMembers) {
    strategyCount += {
      for (final w in workersOf(m.id))
        for (final j in w.jobs) j.strategy,
    }.length;
  }

  final symbols = <String, ({String name, int jobs, int workers, Set<int> members})>{};
  for (final m in mockMembers) {
    for (final w in workersOf(m.id)) {
      final count = w.jobs.where((j) => !j.isFinished).length;
      if (count == 0) continue;
      final s = symbols[w.symbolCode];
      symbols[w.symbolCode] = (
        name: w.symbolName,
        jobs: (s?.jobs ?? 0) + count,
        workers: (s?.workers ?? 0) + 1,
        members: {...?s?.members, m.id},
      );
    }
  }
  final symbolRows = symbols.values.toList()..sort((a, b) => b.jobs.compareTo(a.jobs));
  final rest = symbolRows.skip(topSymbols).toList();
  final jobsBySymbol = [
    for (final s in symbolRows.take(topSymbols))
      BarRow(s.name, s.jobs, '${s.name}\n잡 ${s.jobs}개 · 워커 ${s.workers}개 · 회원 ${s.members.length}명'),
    if (rest.isNotEmpty)
      BarRow('기타 ${rest.length}종목', rest.fold(0, (n, s) => n + s.jobs), rest.map((s) => s.name).join(', ')),
  ];

  final byStrategy = <String, int>{};
  for (final j in current) {
    byStrategy.update(j.strategy.label, (n) => n + 1, ifAbsent: () => 1);
  }
  final strategyRows = byStrategy.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  return CompanyStats(
    strategyCount: strategyCount,
    currentJobs: current.length,
    finishedJobs: jobs.length - current.length,
    workers: workers.length,
    runningWorkers: workers.where((w) => w.status == WorkerStatus.running).length,
    errorWorkers: workers.where((w) => w.status == WorkerStatus.error).length,
    positions: positions.length,
    manualPositions: positions.where((p) => p.jobName == null).length,
    jobsBySymbol: jobsBySymbol,
    jobsByStrategy: [for (final e in strategyRows) BarRow(e.key, e.value, '${e.key} 전략 잡 ${e.value}개')],
  );
}

/// 통화 하나의 주문 합계.
class OrderTotal {
  OrderTotal(this.currency);
  final String currency;
  int orders = 0;
  int filled = 0;
  int waiting = 0;
  int rejected = 0;
  double buyAmount = 0;
  double sellAmount = 0;

  double get filledAmount => buyAmount + sellAmount;
}

/// 전체 회원의 실전 주문 합계. 통화별로 나누고 모의 계좌는 뺀다. 금액이 큰 순서로 준다.
List<OrderTotal> orderTotals({DateTime? since}) {
  final totals = <String, OrderTotal>{};
  for (final m in mockMembers) {
    for (final o in ordersOf(m.id)) {
      if (o.isPaper || (since != null && o.at.isBefore(since))) continue;
      final t = totals.putIfAbsent(o.currency, () => OrderTotal(o.currency));
      t.orders++;
      if (o.isFilled) t.filled++;
      if (o.isWaiting) t.waiting++;
      if (o.isRejected) t.rejected++;
      if (o.side == 'buy') t.buyAmount += o.filledAmount;
      if (o.side == 'sell') t.sellAmount += o.filledAmount;
    }
  }
  return totals.values.toList()..sort((a, b) => b.filledAmount.compareTo(a.filledAmount));
}

/// 통화별 실현손익. 통화가 다르면 합치지 않는다.
Map<String, double> realizedPnlOf(int memberId, {String? accountName}) {
  final sums = <String, double>{};
  for (final w in workersOf(memberId)) {
    for (final j in w.jobs) {
      if (accountName != null && j.accountName != accountName) continue;
      if (j.realizedPnl != 0) sums.update(w.currency, (v) => v + j.realizedPnl, ifAbsent: () => j.realizedPnl);
    }
  }
  return sums;
}

NotificationState notificationStateOf(Member m) =>
    _liveStates[m.id] ??
    switch (m.id) {
      1020 => NotificationState(pushAllowed: m.pushAgreed, onServer: false),
      1018 => NotificationState(pushAllowed: m.pushAgreed, permitted: false, hasToken: false, onServer: false),
      1017 => NotificationState(pushAllowed: m.pushAgreed, sound: false, banner: false),
      _ => NotificationState(pushAllowed: m.pushAgreed),
    };

/// 체결·거부 이벤트로 알림 이력을 만든다. 최신 알림이 앞에 오고 최근 2건은 안 읽음으로 둔다.
/// [accountName] 을 주면 그 계좌의 알림만 준다.
List<NotificationMessage> notificationsOf(int memberId, {String? accountName}) {
  final live = _liveNotifications[memberId];
  if (live != null) {
    return [
      for (final n in live)
        if (accountName == null || n.accountName == accountName) n,
    ];
  }
  String amount(double? v) {
    if (v == null) return '';
    final r = (v * 100).round() / 100;
    return formatNumber(r == r.truncateToDouble() ? r.toInt() : r);
  }

  final rows = <({DateTime at, String title, String body, String account})>[];
  for (final w in workersOf(memberId)) {
    for (final j in w.jobs) {
      if (accountName != null && j.accountName != accountName) continue;
      for (final c in j.cycles) {
        for (final e in c.events) {
          final body = '${amount(e.qty)}${w.qtyUnit} @${amount(e.price)} · ${j.name}';
          switch (e.type) {
            case 'fill':
              rows.add((at: e.at, title: '${w.symbolName} ${e.sideLabel} 체결', body: body, account: j.accountName));
            case 'order_rejected':
              rows.add((
                at: e.at,
                title: '${w.symbolName} ${e.sideLabel} 거부',
                body: '${e.message ?? '주문 거부'} · ${j.name}',
                account: j.accountName,
              ));
          }
        }
      }
    }
  }
  rows.sort((a, b) => b.at.compareTo(a.at));
  return [
    // 관리자가 보낸 푸시는 계좌와 무관해 전체 계좌에서만 보인다.
    if (accountName == null) ...?_sentPushes[memberId],
    for (final (i, r) in rows.indexed) NotificationMessage(r.at, r.title, r.body, r.account, isRead: i >= 2),
  ];
}

final _snapshot = DateTime(2026, 10, 30, 10, 45);

final _accounts = <int, List<MemberAccount>>{
  1024: [
    MemberAccount(
      '해외선물 메인',
      '50123401',
      '해외선물',
      'USD',
      deposit: 18420.5,
      orderableCash: 9310.25,
      totalEval: 3240,
      snapshotAt: _snapshot,
    ),
    MemberAccount(
      '해외선물 서브',
      '50123405',
      '해외선물',
      'USD',
      deposit: 4300,
      orderableCash: 4300,
      totalEval: 0,
      snapshotAt: _snapshot,
    ),
    MemberAccount(
      '국내선물 메인',
      '50123402',
      '국내선물',
      'KRW',
      deposit: 42000000,
      orderableCash: 18500000,
      totalEval: 113250000,
      snapshotAt: _snapshot,
    ),
    MemberAccount(
      '국내주식 연습',
      '50123403',
      '국내주식',
      'KRW',
      deposit: 8200000,
      orderableCash: 8200000,
      totalEval: 1795000,
      snapshotAt: _snapshot,
      isPaper: true,
    ),
    MemberAccount(
      '해외주식 메인',
      '50123404',
      '해외주식',
      'USD',
      deposit: 6200,
      orderableCash: 6200,
      totalEval: 0,
      snapshotAt: _snapshot,
    ),
  ],
  1023: [
    MemberAccount(
      '국내주식 메인',
      '50456701',
      '국내주식',
      'KRW',
      deposit: 12800000,
      orderableCash: 11900000,
      totalEval: 1255000,
      snapshotAt: _snapshot,
    ),
    MemberAccount(
      '해외주식 메인',
      '50456702',
      '해외주식',
      'USD',
      deposit: 4100,
      orderableCash: 4100,
      totalEval: 0,
      snapshotAt: _snapshot,
    ),
  ],
  1020: [
    MemberAccount(
      '해외선물 메인',
      '50789001',
      '해외선물',
      'USD',
      deposit: 26150,
      orderableCash: 22400,
      totalEval: 0,
      snapshotAt: _snapshot,
    ),
    MemberAccount(
      '해외주식 메인',
      '50789002',
      '해외주식',
      'USD',
      deposit: 9800,
      orderableCash: 6680,
      totalEval: 2212.5,
      snapshotAt: _snapshot,
    ),
  ],
  1019: [
    MemberAccount(
      '해외선물 메인',
      '50321001',
      '해외선물',
      'USD',
      deposit: 3100,
      orderableCash: 3100,
      totalEval: 0,
      snapshotAt: DateTime(2026, 10, 22, 10, 0),
    ),
    MemberAccount(
      '해외주식 메인',
      '50321002',
      '해외주식',
      'USD',
      deposit: 1500,
      orderableCash: 1500,
      totalEval: 0,
      snapshotAt: DateTime(2026, 10, 22, 10, 0),
    ),
  ],
  1017: [
    MemberAccount(
      '해외선물 메인',
      '50654301',
      '해외선물',
      'USD',
      deposit: 15900,
      orderableCash: 12300,
      totalEval: 57420,
      snapshotAt: _snapshot,
    ),
  ],
  1016: [
    MemberAccount(
      '국내주식 메인',
      '50987601',
      '국내주식',
      'KRW',
      deposit: 5400000,
      orderableCash: 4800000,
      totalEval: 495500,
      snapshotAt: _snapshot,
    ),
  ],
};

/// 앱에서 잡 없이 잡히는 수동 포지션.
const _manualPositions = <int, List<AccountPosition>>{
  1024: [
    AccountPosition(
      symbolCode: '373220',
      symbolName: 'LG에너지솔루션',
      currency: 'KRW',
      qtyUnit: '주',
      accountName: '국내주식 연습',
      position: JobPosition(side: 'long', size: 2, entryPrice: 398000),
      currentPrice: 402000,
    ),
  ],
};
