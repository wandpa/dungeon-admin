/// 회원 모니터링 화면의 샘플 데이터. 상담할 때 사용자 앱 화면과 맞춰 볼 수 있도록
/// 필드·상태값·문구를 dungeon-app 에 맞춘다.
///   워커: WorkerEntity, 누적 손익: WorkerPnlLimit, 잡: JobEntity,
///   회차: JobCycleEntity, 타임라인: JobEventEntity
library;

enum WorkerStatus {
  running('가동중'),
  stopped('중지됨'),
  error('오류');

  const WorkerStatus(this.label);
  final String label;
}

class MemberWorker {
  const MemberWorker({
    required this.id,
    required this.symbolCode,
    required this.symbolName,
    required this.marketType,
    required this.status,
    required this.insertedAt,
    required this.currency,
    required this.currentPrice,
    this.autoCloseOnMarketEnd = false,
    this.errorMessage,
    this.pnlLimit,
    this.jobs = const [],
  });

  final int id;
  final String symbolCode;
  final String symbolName;
  final String marketType;
  final WorkerStatus status;
  final DateTime insertedAt;
  final String currency; // USD · HKD · EUR · KRW
  final double? currentPrice; // 테스트 DB 에는 시세가 없어 비어 있다
  final bool autoCloseOnMarketEnd;
  final String? errorMessage;
  final WorkerPnlLimit? pnlLimit; // null 이면 누적 손익 종료를 쓰지 않는다
  final List<WorkerJob> jobs;

  bool usesAccount(String accountName) => jobs.any((j) => j.accountName == accountName);

  /// 그 계좌의 잡만 남긴 워커. 앱은 계좌를 잡마다 고르므로 한 워커에 계좌가 섞일 수 있다.
  MemberWorker onlyAccount(String accountName) => MemberWorker(
    id: id,
    symbolCode: symbolCode,
    symbolName: symbolName,
    marketType: marketType,
    status: status,
    insertedAt: insertedAt,
    currency: currency,
    currentPrice: currentPrice,
    autoCloseOnMarketEnd: autoCloseOnMarketEnd,
    errorMessage: errorMessage,
    pnlLimit: pnlLimit,
    jobs: [
      for (final j in jobs)
        if (j.accountName == accountName) j,
    ],
  );

  MemberWorker withJobs(List<WorkerJob> next) => MemberWorker(
    id: id,
    symbolCode: symbolCode,
    symbolName: symbolName,
    marketType: marketType,
    status: status,
    insertedAt: insertedAt,
    currency: currency,
    currentPrice: currentPrice,
    autoCloseOnMarketEnd: autoCloseOnMarketEnd,
    errorMessage: errorMessage,
    pnlLimit: pnlLimit,
    jobs: next,
  );

  /// 수량 단위. 앱과 같이 선물은 계약, 주식은 주.
  String get qtyUnit => marketType.endsWith('선물') ? '계약' : '주';

  double get realizedPnl => jobs.fold(0, (sum, j) => sum + j.realizedPnl);

  /// 보유가 없는 잡은 더하지 않는다. 방향을 모르는 보유도 손익을 지어내지 않고 뺀다.
  double get unrealizedPnl => jobs.fold(0, (sum, j) => sum + (j.position?.pnlAt(currentPrice) ?? 0));
}

/// 누적 손익으로 워커 종료.
class WorkerPnlLimit {
  const WorkerPnlLimit({
    required this.period,
    this.unit = 'amount',
    this.profitTarget,
    this.lossLimit,
    this.accumAmount = 0,
    this.accumTicks = 0,
    this.accumCount = 0,
    this.stoppedAt,
    this.stopReason,
  });

  final String period; // day | week | month | none
  final String unit; // amount | tick
  final double? profitTarget; // 이 값 이상이면 종료. null = 사용 안 함
  final double? lossLimit; // −이 값 이하면 종료. null = 사용 안 함
  final double accumAmount;
  final double accumTicks;
  final int accumCount;
  final DateTime? stoppedAt;
  final String? stopReason;

  bool get isTick => unit == 'tick';

  String get periodLabel => switch (period) {
    'day' => '일 · 매일 장 시작 10분 전',
    'week' => '주 · 월요일 장 시작 10분 전',
    'month' => '월 · 첫 거래일 장 시작 10분 전',
    _ => '초기화 없음',
  };

  String get accumTitle => switch (period) {
    'day' => '오늘 누적 손익',
    'week' => '이번 주 누적 손익',
    'month' => '이번 달 누적 손익',
    _ => '누적 손익',
  };
}

/// 앱 잡 화면의 자리. 앱은 실행 슬롯, 중지됨, 대기열, 종료로 나눈다.
enum JobSlot { running, stopped, queued, finished }

/// 앱 전략 화면의 설정. 잡의 현재 설정과 회차 시작 시점의 스냅샷에 같이 쓴다.
/// 실제로는 잡의 templateParams 에서 만든다.
class JobStrategy {
  const JobStrategy(
    this.templateId, {
    required this.qty,
    this.stopLossPct,
    this.takeProfitPct,
    this.stopLossUnit = '%',
    this.takeProfitUnit = '%',
    this.trailingStop,
    this.orderType = '시장가',
    this.entrySettings = const {},
    this.conditions = const {},
    this.entryMode,
    this.liveItems,
    this.liveName,
    this.liveExitCards,
    this.liveTrailingOn = false,
    this.tickSize,
    this.tickValue,
  });

  final String templateId;
  final double qty;
  final double? stopLossPct;
  final double? takeProfitPct;
  final String stopLossUnit; // 틱 · 포인트 · %
  final String takeProfitUnit;
  final Map<String, String>? trailingStop; // 추종 폭·추종 회차·동작 마디. null 이면 사용 안 함
  final String orderType;

  /// 전략마다 다른 진입 항목(돌파기준·평가 시점·신호 주기 등).
  final Map<String, String> entrySettings;

  /// 지표 조합의 신호 조건. 키는 OR 묶음, 값은 그 안의 AND 조건.
  final Map<String, List<String>> conditions;
  final String? entryMode; // 지표 조합의 진입 방식
  final List<LiveSetting>? liveItems; // 테스트 DB 잡의 앱 항목. 있으면 화면이 이 순서대로 그린다
  final String? liveName; // 앱에 저장된 전략 이름
  final List<LiveSetting>? liveExitCards; // 커스텀 청산 조건 카드
  final bool liveTrailingOn; // 테스트 DB 잡은 꺼져 있어도 트레일링 항목을 보여 준다
  final double? tickSize; // 틱 환산 줄에 쓴다
  final double? tickValue;

  String get label => strategyTemplateLabel(templateId);
}

/// 앱 strategyTemplateLabel 과 같은 표기.
String strategyTemplateLabel(String templateId) => switch (templateId) {
  'breakout' => '돌파',
  'candle_direction_breakout' => '캔들 방향',
  'first_fill_breakout' => '선입파 돌파',
  'gap_trading_breakout' => '갭 트레이딩',
  'indicator_combination' => '지표 조합',
  'trailing_entry' => '트레일링 진입',
  _ => templateId,
};

/// 앱 상세보기 화면의 항목 하나.
class LiveSetting {
  const LiveSetting.value(this.label, this.value, {this.note}) : options = const [], on = null;
  const LiveSetting.segment(this.label, this.options, this.value, {this.note}) : on = null;
  const LiveSetting.toggle(this.label, this.value, bool this.on) : options = const [], note = null;

  final String label;
  final String value; // 스위치 카드에서는 설명글
  final List<String> options; // 비어 있지 않으면 고르는 버튼
  final String? note;
  final bool? on; // 있으면 스위치 카드

  bool get isToggle => on != null;
}

class WorkerJob {
  const WorkerJob({
    required this.name,
    required this.status,
    required this.accountName,
    required this.isPaper,
    required this.strategy,
    this.mode = 'trade',
    this.isActive = true,
    this.entrySide = 'buy',
    this.repeatCurrent = 0,
    this.repeatCount = 1,
    this.position,
    this.cycles = const [],
    this.liveId,
    this.fixedRealizedPnl,
    this.detailLoaded = false,
    this.accountNumber,
    this.endReason,
  });

  final String name;
  final String status;
  final String accountName;
  final bool isPaper;
  final JobStrategy strategy;
  final String mode; // trade | alert
  final bool isActive;
  final String entrySide; // buy | sell | both
  final int repeatCurrent;
  final int repeatCount;
  final JobPosition? position;
  final List<JobCycle> cycles; // 최신 회차가 앞에 온다
  final String? liveId; // 테스트 DB 잡의 GUID
  final double? fixedRealizedPnl; // 서버가 합산해 준 실현손익. 회차는 잡을 고를 때 받는다
  final bool detailLoaded; // 테스트 DB 잡의 설정·회차를 받았는지
  final String? accountNumber; // 서버가 가려서 준 계좌번호
  final String? endReason; // completed · user_close · deleted · failed · cancelled · abnormal

  /// 설정과 회차를 채운 잡.
  WorkerJob withDetail(JobStrategy strategy, List<JobCycle> cycles) => WorkerJob(
    name: name,
    status: status,
    accountName: accountName,
    isPaper: isPaper,
    strategy: strategy,
    mode: mode,
    isActive: isActive,
    entrySide: entrySide,
    repeatCurrent: repeatCurrent,
    repeatCount: repeatCount,
    position: position,
    cycles: cycles,
    liveId: liveId,
    fixedRealizedPnl: fixedRealizedPnl,
    detailLoaded: true,
    accountNumber: accountNumber,
    endReason: endReason,
  );

  bool get isAlert => mode == 'alert';

  /// 앱 finishedJobStatuses 에 삭제 종료(terminated)를 더한 값. 나머지는 현재 잡이다.
  bool get isFinished =>
      const {'closed', 'cancelled', 'failed', 'done', 'error', 'abnormal_terminated', 'terminated'}.contains(status);

  bool get isShort => entrySide == 'sell';

  /// 앱 잡 목록과 같은 분류. 시작 전 잡은 대기열, 꺼진 잡은 중지됨이다.
  JobSlot get slot {
    if (isFinished) return JobSlot.finished;
    if (const {'monitoring', 'submitted', 'bought', 'sent', 'running'}.contains(status)) {
      return isActive ? JobSlot.running : JobSlot.stopped;
    }
    return JobSlot.queued;
  }

  double get realizedPnl => fixedRealizedPnl ?? cycles.fold(0, (sum, c) => sum + (c.realizedPnl ?? 0));

  /// 거부된 주문의 사유.
  List<String> get rejectReasons => [
    for (final c in cycles)
      for (final e in c.events)
        if (e.type == 'order_rejected') e.message ?? '주문 거부',
  ];

  /// 앱 jobStatusLabel 과 같은 표기. 스위치를 내렸는데 보유가 남으면 "중지됨(보유중)".
  String get statusLabel {
    if (!isActive && position != null) return '중지됨(보유중)';
    return switch (status) {
      'sent' => '전송중',
      'failed' => '접수실패',
      'monitoring' => '감시중',
      'submitted' => isShort ? '매도 접수중' : '매수 접수중',
      'bought' => isShort ? '매도완료 · 매수감시중' : '매수완료 · 매도감시중',
      'closed' => isShort ? '매수완료(청산)' : '매도완료',
      'running' => '실행 중',
      'done' => '완료',
      'error' => '오류',
      'cancelled' => '취소됨',
      'terminated' => '삭제 종료',
      'abnormal_terminated' => '비정상종료',
      'waiting' => '대기열',
      _ => '대기',
    };
  }

  /// 앱 종료된 전략 카드의 칩. 서버가 종료 사유를 주지 않으면 상태 글자를 쓴다.
  String get endLabel => switch (endReason) {
    'completed' => '정상 종료',
    'user_close' => 'Close 종료',
    'deleted' => '삭제 종료',
    'failed' => '실패 종료',
    'cancelled' => '취소됨',
    'abnormal' => '⚠️ 비정상종료',
    _ => statusLabel,
  };

  /// 계좌 이름과 서버가 가려서 준 번호. 번호가 없으면 이름만 쓴다.
  String get accountLabel => accountNumber == null ? accountName : '$accountName($accountNumber)';

  String get entrySideLabel => switch (entrySide) {
    'buy' => '매수',
    'sell' => '매도',
    _ => '양방향',
  };
}

class JobPosition {
  const JobPosition({required this.side, required this.size, required this.entryPrice, this.multiplier = 1});

  final String side; // long | short
  final double size;
  final double entryPrice;
  final double multiplier; // 계약승수

  /// 평가손익. 앱과 같이 (현재가 − 진입가) × 수량 × 승수이고 매도 보유는 부호가 반대다.
  /// 방향이나 현재가를 모르면 null.
  double? pnlAt(double? price) {
    if (price == null) return null;
    return switch (side) {
      'long' => (price - entryPrice) * size * multiplier,
      'short' => (entryPrice - price) * size * multiplier,
      _ => null,
    };
  }

  /// 앱과 같이 방향이 비면 롱으로 치지 않고 그대로 드러낸다.
  String get sideLabel => switch (side) {
    'long' => '매수',
    'short' => '매도',
    _ => '방향 없음',
  };
}

/// 잡의 회차 하나. 앱 "이력" 화면의 회차 카드와 타임라인에 해당한다.
class JobCycle {
  const JobCycle({
    required this.cycleNo,
    required this.status,
    required this.strategy,
    this.multiplier = 1,
    this.filledBuyQty,
    this.avgBuyPrice,
    this.filledSellQty,
    this.avgSellPrice,
    this.realizedPnl,
    this.openedAt,
    this.closedAt,
    this.events = const [],
    this.side,
  });

  final int cycleNo;
  final String status; // open | closed | sold_elsewhere | cancelled
  final JobStrategy? strategy; // null 이면 앱과 같이 "설정 정보 없음"
  final double multiplier; // 체결 당시 계약승수. 나중에 종목 값을 바꿔도 지난 주문은 그대로다
  final double? filledBuyQty;
  final double? avgBuyPrice;
  final double? filledSellQty;
  final double? avgSellPrice;
  final double? realizedPnl;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final List<JobEvent> events; // 시간순
  final String? side; // 테스트 DB 회차의 방향. long | short

  String get statusLabel => switch (status) {
    'open' => '진행중',
    'closed' => '종료',
    'sold_elsewhere' => '타 매체 매도',
    'cancelled' => '취소됨',
    'none' => '',
    _ => status,
  };
}

class JobEvent {
  const JobEvent(this.at, this.type, {this.side, this.qty, this.price, this.message, this.group, this.exitReason});

  final DateTime at;
  final String type; // alert_fired · order_submitted · fill · order_rejected ...
  final String? side; // buy | sell
  final double? qty;
  final double? price;
  final String? message;
  final String? group; // 서버가 준 축. job | entry | exit. 샘플은 비어 있다
  final String? exitReason; // take_profit | stop_loss ...

  String get sideLabel => switch (side) {
    'buy' => '매수',
    'sell' => '매도',
    _ => '',
  };
}

enum CustomerLogCategory {
  access('접속'),
  worker('워커'),
  order('주문'),
  error('오류');

  const CustomerLogCategory(this.label);
  final String label;
}

class CustomerLog {
  const CustomerLog(this.at, this.category, this.text, {this.workerId, this.jobName});
  final DateTime at;
  final CustomerLogCategory category;
  final String text;
  final int? workerId; // 로그인처럼 워커와 무관한 로그는 null
  final String? jobName; // 워커 시작처럼 잡과 무관한 로그는 null. API 를 붙이면 잡 id 로 바꾼다.
}

final _liveWorkers = <int, List<MemberWorker>>{};
final _liveLogs = <int, List<CustomerLog>>{};

/// 테스트 DB 에서 받은 회원의 워커와 고객 로그를 넣는다.
void putLiveWorkers(int memberId, List<MemberWorker> workers, List<CustomerLog> logs) {
  _liveWorkers[memberId] = workers;
  _liveLogs[memberId] = logs;
}

/// 설정·회차를 받은 잡으로 바꾼다.
void replaceLiveJob(int memberId, WorkerJob before, WorkerJob after) {
  final workers = _liveWorkers[memberId];
  if (workers == null) return;
  _liveWorkers[memberId] = [
    for (final w in workers)
      w.jobs.contains(before) ? w.withJobs([for (final j in w.jobs) j == before ? after : j]) : w,
  ];
}

/// 더 받은 로그를 합친다. 겹치는 로그는 한 번만 둔다.
void addLiveLogs(int memberId, List<CustomerLog> logs) {
  final list = _liveLogs[memberId];
  if (list == null) return;
  final known = {for (final l in list) (l.at, l.text, l.workerId, l.jobName)};
  list.addAll(logs.where((l) => known.add((l.at, l.text, l.workerId, l.jobName))));
}

List<MemberWorker> workersOf(int memberId) => _liveWorkers[memberId] ?? _workers[memberId] ?? const [];

/// 최신 로그가 앞에 온다. [workerId] 를 주면 그 워커, [jobName] 까지 주면 그 잡의 로그만 준다.
List<CustomerLog> customerLogsOf(int memberId, {int? workerId, String? jobName}) => [
  for (final l in _liveLogs[memberId] ?? _logs[memberId] ?? const <CustomerLog>[])
    if ((workerId == null || l.workerId == workerId) && (jobName == null || l.jobName == jobName)) l,
]..sort((a, b) => b.at.compareTo(a.at));

/// 신호 → 주문 → 체결 순서의 진입 이벤트.
List<JobEvent> _entry(DateTime filledAt, String side, double qty, double price) => [
  JobEvent(filledAt.subtract(const Duration(seconds: 3)), 'alert_fired', side: side, qty: qty, message: '조건 충족'),
  JobEvent(filledAt.subtract(const Duration(seconds: 2)), 'order_submitted', side: side, qty: qty),
  JobEvent(filledAt, 'fill', side: side, qty: qty, price: price),
];

/// 진입부터 청산까지 끝난 회차. 손익은 체결가·수량·승수로 계산한다.
JobCycle _closedCycle(
  int no,
  JobStrategy strategy, {
  required DateTime openedAt,
  required double buy,
  required DateTime closedAt,
  required double sell,
  required double multiplier,
  bool short = false,
  String exitMessage = '조건 충족',
}) {
  final qty = strategy.qty;
  final entrySide = short ? 'sell' : 'buy';
  final exitSide = short ? 'buy' : 'sell';
  return JobCycle(
    cycleNo: no,
    status: 'closed',
    strategy: strategy,
    filledBuyQty: qty,
    avgBuyPrice: buy,
    filledSellQty: qty,
    avgSellPrice: sell,
    realizedPnl: (sell - buy) * qty * multiplier,
    multiplier: multiplier,
    openedAt: openedAt,
    closedAt: closedAt,
    events: [
      ..._entry(openedAt, entrySide, qty, short ? sell : buy),
      JobEvent(
        closedAt.subtract(const Duration(seconds: 2)),
        'order_submitted',
        side: exitSide,
        qty: qty,
        message: exitMessage,
      ),
      JobEvent(closedAt, 'fill', side: exitSide, qty: qty, price: short ? buy : sell),
      JobEvent(closedAt, 'cycle_closed'),
    ],
  );
}

/// 잡 하나짜리 샘플 워커.
MemberWorker _worker(
  int id,
  String symbolCode,
  String symbolName,
  String marketType,
  String currency,
  double currentPrice,
  WorkerStatus status,
  DateTime insertedAt,
  WorkerJob job, {
  bool autoClose = false,
  WorkerPnlLimit? pnlLimit,
}) => MemberWorker(
  id: id,
  symbolCode: symbolCode,
  symbolName: symbolName,
  marketType: marketType,
  status: status,
  insertedAt: insertedAt,
  currency: currency,
  currentPrice: currentPrice,
  autoCloseOnMarketEnd: autoClose,
  pnlLimit: pnlLimit,
  jobs: [job],
);

/// 체결 없이 조건을 기다리는 잡.
WorkerJob _waitingJob(String name, JobStrategy strategy, String accountName, {String status = 'monitoring'}) =>
    WorkerJob(name: name, status: status, accountName: accountName, isPaper: false, strategy: strategy, repeatCount: 2);

/// 지금 보유 중인 잡. 진입 체결로 열린 회차를 함께 만든다.
WorkerJob _holdingJob(
  String name,
  JobStrategy strategy,
  String accountName, {
  required DateTime filledAt,
  required double entryPrice,
  double multiplier = 1,
  bool short = false,
}) {
  final side = short ? 'sell' : 'buy';
  return WorkerJob(
    name: name,
    status: 'bought',
    accountName: accountName,
    isPaper: false,
    strategy: strategy,
    entrySide: side,
    repeatCurrent: 1,
    repeatCount: 2,
    position: JobPosition(
      side: short ? 'short' : 'long',
      size: strategy.qty,
      entryPrice: entryPrice,
      multiplier: multiplier,
    ),
    cycles: [
      JobCycle(
        multiplier: multiplier,
        cycleNo: 1,
        status: 'open',
        strategy: strategy,
        filledBuyQty: short ? null : strategy.qty,
        avgBuyPrice: short ? null : entryPrice,
        filledSellQty: short ? strategy.qty : null,
        avgSellPrice: short ? entryPrice : null,
        openedAt: filledAt,
        events: _entry(filledAt, side, strategy.qty, entryPrice),
      ),
    ],
  );
}

const _indexFut = JobStrategy(
  'breakout',
  qty: 1,
  stopLossPct: 40,
  stopLossUnit: '틱',
  takeProfitPct: 80,
  takeProfitUnit: '틱',
  entrySettings: {'돌파기준': '일봉시가 대비', '돌파가격': '+20틱', '평가 시점': '봉 완성 시', '신호 주기': '5분'},
);
const _stockSwing = JobStrategy(
  'candle_direction_breakout',
  qty: 5,
  stopLossPct: 2,
  takeProfitPct: 5,
  entrySettings: {'거래 방향': '양봉만', '신호 주기': '15분', '직전봉 등락률': '0.5% 이상'},
);
const _gold = JobStrategy(
  'trailing_entry',
  qty: 1,
  stopLossPct: 30,
  stopLossUnit: '틱',
  trailingStop: {'추종 폭': '15틱', '추종 회차': '연속 추적'},
  entrySettings: {'거래 방향': '매수', '신호 주기': '3분', '진입 간격': '10틱'},
);

const _mclBreakout = JobStrategy(
  'breakout',
  qty: 2,
  stopLossPct: 25,
  stopLossUnit: '틱',
  takeProfitPct: 50,
  takeProfitUnit: '틱',
  orderType: '지정가',
  entrySettings: {'돌파기준': '현재가 대비', '돌파가격': '+10틱', '평가 시점': '실시간'},
);
const _mclBreakoutSmall = JobStrategy(
  'breakout',
  qty: 1,
  stopLossPct: 20,
  stopLossUnit: '틱',
  entrySettings: {'돌파기준': '가격', '돌파가격': '100.50', '평가 시점': '실시간'},
);
const _mclAlert = JobStrategy(
  'indicator_combination',
  qty: 0,
  entryMode: '봉 완성 시',
  entrySettings: {'신호 주기': '15분'},
  conditions: {
    '매도 OR 1': ['RSI(14) 70 이상', '볼린저밴드(20, 2) 상단 이탈'],
    '매도 OR 2': ['SMA(5) < SMA(20)'],
  },
);
const _mclGap = JobStrategy(
  'gap_trading_breakout',
  qty: 1,
  stopLossPct: 30,
  stopLossUnit: '틱',
  takeProfitPct: 60,
  takeProfitUnit: '틱',
  entrySettings: {'거래 방향': '갭상승', '갭 크기': '15틱', '신호 봉(갭 감지용)': '1분'},
);
const _samsung = JobStrategy(
  'candle_direction_breakout',
  qty: 10,
  stopLossPct: 2,
  takeProfitPct: 4,
  entrySettings: {'거래 방향': '양봉만', '신호 주기': '1분', '직전봉 등락률': '1% 이상'},
);
const _hynix = JobStrategy(
  'trailing_entry',
  qty: 3,
  stopLossPct: 2.5,
  trailingStop: {'추종 폭': '1.5%', '추종 회차': '2회', '동작 마디': '1회차 2% · 2회차 4%'},
  entrySettings: {'거래 방향': '매수', '신호 주기': '5분', '진입 간격': '3틱'},
);
const _nq = JobStrategy(
  'first_fill_breakout',
  qty: 1,
  stopLossPct: 2,
  stopLossUnit: '포인트',
  takeProfitPct: 4,
  takeProfitUnit: '포인트',
  entrySettings: {'거래 방향': '매도', '신호 주기': '1분', '평가 시점': '실시간'},
);
const _nvda = JobStrategy(
  'indicator_combination',
  qty: 5,
  stopLossPct: 3,
  takeProfitPct: 6,
  entryMode: '실시간',
  entrySettings: {'신호 주기': '일봉'},
  conditions: {
    '매수 OR 1': ['SMA(5) > SMA(20)', 'RSI(14) 50 이상'],
    '매수청산 OR 1': ['RSI(14) 75 이상'],
  },
);

final _workers = <int, List<MemberWorker>>{
  1024: [
    MemberWorker(
      id: 501,
      symbolCode: 'MCLZ26',
      symbolName: '마이크로 WTI 원유 12월물',
      marketType: '해외선물',
      status: WorkerStatus.running,
      insertedAt: DateTime(2026, 10, 29, 21, 40),
      currency: 'USD',
      currentPrice: 101.10,
      autoCloseOnMarketEnd: true,
      pnlLimit: const WorkerPnlLimit(period: 'day', profitTarget: 500, lossLimit: 300, accumAmount: 140, accumCount: 2),
      jobs: [
        WorkerJob(
          name: '돌파 매수 전략',
          status: 'bought',
          accountName: '해외선물 메인',
          isPaper: false,
          strategy: _mclBreakout,
          repeatCurrent: 3,
          repeatCount: 5,
          position: const JobPosition(side: 'long', size: 2, entryPrice: 100.75, multiplier: 100),
          cycles: [
            JobCycle(
              multiplier: 100,
              cycleNo: 3,
              status: 'open',
              strategy: _mclBreakout,
              filledBuyQty: 2,
              avgBuyPrice: 100.75,
              openedAt: DateTime(2026, 10, 30, 10, 2, 41),
              events: _entry(DateTime(2026, 10, 30, 10, 2, 41), 'buy', 2, 100.75),
            ),
            _closedCycle(
              2,
              _mclBreakout,
              openedAt: DateTime(2026, 10, 30, 3, 18, 7),
              buy: 100.40,
              closedAt: DateTime(2026, 10, 30, 6, 40, 52),
              sell: 100.60,
              multiplier: 100,
            ),
            _closedCycle(
              1,
              _mclBreakout,
              openedAt: DateTime(2026, 10, 29, 22, 5, 30),
              buy: 100.10,
              closedAt: DateTime(2026, 10, 30, 1, 12, 15),
              sell: 100.60,
              multiplier: 100,
            ),
          ],
        ),
        const WorkerJob(
          name: '고점 이탈 알람',
          status: 'monitoring',
          accountName: '해외선물 메인',
          isPaper: false,
          strategy: _mclAlert,
          mode: 'alert',
          entrySide: 'both',
        ),
        WorkerJob(
          name: '눌림목 소액 매수',
          status: 'monitoring',
          accountName: '해외선물 서브',
          isPaper: false,
          strategy: _mclBreakoutSmall,
          repeatCount: 2,
        ),
        WorkerJob(
          name: '갭 상승 진입',
          status: 'failed',
          accountName: '해외선물 메인',
          isPaper: false,
          strategy: _mclGap,
          repeatCurrent: 1,
          cycles: [
            JobCycle(
              cycleNo: 1,
              status: 'cancelled',
              strategy: _mclGap,
              openedAt: DateTime(2026, 10, 29, 21, 50, 4),
              closedAt: DateTime(2026, 10, 29, 21, 50, 6),
              events: [
                JobEvent(DateTime(2026, 10, 29, 21, 50, 4), 'alert_fired', side: 'buy', qty: 1, message: '조건 충족'),
                JobEvent(DateTime(2026, 10, 29, 21, 50, 5), 'order_submitted', side: 'buy', qty: 1),
                JobEvent(DateTime(2026, 10, 29, 21, 50, 6), 'order_rejected', side: 'buy', message: '주문 가능 금액 부족'),
              ],
            ),
          ],
        ),
      ],
    ),
    MemberWorker(
      id: 502,
      symbolCode: '005930',
      symbolName: '삼성전자',
      marketType: '국내주식',
      status: WorkerStatus.stopped,
      insertedAt: DateTime(2026, 10, 30, 8, 50),
      currency: 'KRW',
      currentPrice: 99100,
      jobs: [
        WorkerJob(
          name: '거래량 급증 매수',
          status: 'bought',
          accountName: '국내주식 연습',
          isPaper: true,
          strategy: _samsung,
          isActive: false,
          repeatCurrent: 1,
          position: const JobPosition(side: 'long', size: 10, entryPrice: 98400),
          cycles: [
            JobCycle(
              cycleNo: 1,
              status: 'open',
              strategy: _samsung,
              filledBuyQty: 10,
              avgBuyPrice: 98400,
              openedAt: DateTime(2026, 10, 30, 9, 1, 12),
              events: _entry(DateTime(2026, 10, 30, 9, 1, 12), 'buy', 10, 98400),
            ),
          ],
        ),
      ],
    ),
    _worker(
      507,
      'NQZ26',
      '나스닥100 12월물',
      '해외선물',
      'USD',
      23415.25,
      WorkerStatus.running,
      DateTime(2026, 10, 29, 22, 0),
      _waitingJob('고점 돌파', _indexFut, '해외선물 메인'),
      autoClose: true,
      pnlLimit: const WorkerPnlLimit(period: 'day', lossLimit: 500),
    ),
    _worker(
      508,
      '101Z6',
      '코스피200 12월물',
      '국내선물',
      'KRW',
      453,
      WorkerStatus.running,
      DateTime(2026, 10, 30, 8, 45),
      _holdingJob(
        '장 초반 돌파',
        _indexFut,
        '국내선물 메인',
        filledAt: DateTime(2026, 10, 30, 9, 2, 48),
        entryPrice: 452.1,
        multiplier: 250000,
      ),
      autoClose: true,
    ),
    _worker(
      509,
      'HSIZ26',
      '항셍지수 12월물',
      '해외선물',
      'HKD',
      25950,
      WorkerStatus.running,
      DateTime(2026, 10, 30, 9, 20),
      _holdingJob(
        '고점 이탈 매도',
        _indexFut,
        '해외선물 메인',
        filledAt: DateTime(2026, 10, 30, 10, 31, 2),
        entryPrice: 26000,
        multiplier: 50,
        short: true,
      ),
      autoClose: true,
    ),
    _worker(
      510,
      'MGCZ26',
      '마이크로 금 12월물',
      '해외선물',
      'USD',
      2752,
      WorkerStatus.running,
      DateTime(2026, 10, 29, 21, 58),
      WorkerJob(
        name: '금 트레일링 진입',
        status: 'monitoring',
        accountName: '해외선물 메인',
        isPaper: false,
        strategy: _gold,
        repeatCurrent: 1,
        repeatCount: 3,
        cycles: [
          _closedCycle(
            1,
            _gold,
            openedAt: DateTime(2026, 10, 30, 0, 12, 40),
            buy: 2740,
            closedAt: DateTime(2026, 10, 30, 4, 31, 5),
            sell: 2755,
            multiplier: 10,
          ),
        ],
      ),
    ),
    _worker(
      511,
      'TSLA',
      '테슬라',
      '해외주식',
      'USD',
      442.5,
      WorkerStatus.stopped,
      DateTime(2026, 10, 28, 23, 10),
      _waitingJob('캔들 방향 추종', _stockSwing, '해외주식 메인', status: 'waiting'),
    ),
  ],
  1023: [
    MemberWorker(
      id: 503,
      symbolCode: '000660',
      symbolName: 'SK하이닉스',
      marketType: '국내주식',
      status: WorkerStatus.running,
      insertedAt: DateTime(2026, 10, 30, 8, 58),
      currency: 'KRW',
      currentPrice: 312500,
      autoCloseOnMarketEnd: true,
      jobs: const [
        WorkerJob(
          name: '눌림목 반등',
          status: 'monitoring',
          accountName: '국내주식 메인',
          isPaper: false,
          strategy: _hynix,
          repeatCount: 3,
        ),
        WorkerJob(name: '추세 추종', status: 'waiting', accountName: '국내주식 메인', isPaper: false, strategy: _hynix),
        WorkerJob(name: '장 마감 전 정리', status: 'waiting', accountName: '국내주식 메인', isPaper: false, strategy: _samsung),
      ],
    ),
    _worker(
      512,
      '005380',
      '현대차',
      '국내주식',
      'KRW',
      251000,
      WorkerStatus.running,
      DateTime(2026, 10, 30, 8, 59),
      _holdingJob('갭 상승 추종', _stockSwing, '국내주식 메인', filledAt: DateTime(2026, 10, 30, 9, 4, 22), entryPrice: 249500),
      autoClose: true,
    ),
    _worker(
      513,
      '035720',
      '카카오',
      '국내주식',
      'KRW',
      41250,
      WorkerStatus.stopped,
      DateTime(2026, 10, 29, 15, 40),
      _waitingJob('눌림목 매수', _stockSwing, '국내주식 메인', status: 'waiting'),
    ),
    _worker(
      514,
      'NVDA',
      '엔비디아',
      '해외주식',
      'USD',
      214.37,
      WorkerStatus.running,
      DateTime(2026, 10, 29, 23, 5),
      _waitingJob('지표 조합 매수', _nvda, '해외주식 메인'),
    ),
  ],
  1020: [
    MemberWorker(
      id: 504,
      symbolCode: 'NQZ26',
      symbolName: '나스닥100 12월물',
      marketType: '해외선물',
      status: WorkerStatus.error,
      insertedAt: DateTime(2026, 10, 26, 22, 10),
      currency: 'USD',
      currentPrice: 23402.5,
      errorMessage: '브로커 잔고와 서버 포지션이 일치하지 않아 잡을 정지했습니다.',
      pnlLimit: const WorkerPnlLimit(
        period: 'week',
        unit: 'tick',
        lossLimit: 400,
        accumAmount: -625,
        accumTicks: -125,
        accumCount: 1,
      ),
      jobs: [
        WorkerJob(
          name: '고점 이탈 매도',
          status: 'abnormal_terminated',
          accountName: '해외선물 메인',
          isPaper: false,
          strategy: _nq,
          entrySide: 'sell',
          repeatCurrent: 2,
          repeatCount: 3,
          cycles: [
            JobCycle(
              multiplier: 20,
              cycleNo: 2,
              status: 'sold_elsewhere',
              strategy: _nq,
              avgSellPrice: 23410,
              filledSellQty: 1,
              openedAt: DateTime(2026, 10, 30, 5, 32, 10),
              closedAt: DateTime(2026, 10, 30, 6, 58, 12),
              events: [
                ..._entry(DateTime(2026, 10, 30, 5, 32, 10), 'sell', 1, 23410),
                JobEvent(DateTime(2026, 10, 30, 6, 58, 12), 'sold_elsewhere'),
              ],
            ),
            _closedCycle(
              1,
              _nq,
              openedAt: DateTime(2026, 10, 30, 1, 47, 6),
              buy: 23402.5,
              closedAt: DateTime(2026, 10, 30, 2, 14, 51),
              sell: 23371.25,
              multiplier: 20,
              short: true,
            ),
          ],
        ),
      ],
    ),
    MemberWorker(
      id: 505,
      symbolCode: 'NVDA',
      symbolName: '엔비디아',
      marketType: '해외주식',
      status: WorkerStatus.running,
      insertedAt: DateTime(2026, 10, 27, 23, 0),
      currency: 'USD',
      currentPrice: 214.37,
      jobs: [
        WorkerJob(
          name: '지표 조합 매수',
          status: 'submitted',
          accountName: '해외주식 메인',
          isPaper: false,
          strategy: _nvda,
          repeatCurrent: 1,
          repeatCount: 2,
          cycles: [
            JobCycle(
              cycleNo: 1,
              status: 'open',
              strategy: _nvda,
              openedAt: DateTime(2026, 10, 30, 7, 21, 18),
              events: [
                JobEvent(DateTime(2026, 10, 30, 7, 21, 16), 'alert_fired', side: 'buy', qty: 5, message: '조건 충족'),
                JobEvent(DateTime(2026, 10, 30, 7, 21, 18), 'order_submitted', side: 'buy', qty: 5),
              ],
            ),
          ],
        ),
      ],
    ),
    _worker(
      515,
      'TSLA',
      '테슬라',
      '해외주식',
      'USD',
      442.5,
      WorkerStatus.running,
      DateTime(2026, 10, 28, 22, 30),
      _holdingJob('돌파 추종', _stockSwing, '해외주식 메인', filledAt: DateTime(2026, 10, 29, 23, 41, 9), entryPrice: 438),
    ),
    _worker(
      516,
      'MGCZ26',
      '마이크로 금 12월물',
      '해외선물',
      'USD',
      2752,
      WorkerStatus.stopped,
      DateTime(2026, 10, 27, 21, 15),
      _waitingJob('금 트레일링 진입', _gold, '해외선물 메인', status: 'waiting'),
    ),
  ],
  1017: [
    MemberWorker(
      id: 506,
      symbolCode: 'MCLZ26',
      symbolName: '마이크로 WTI 원유 12월물',
      marketType: '해외선물',
      status: WorkerStatus.stopped,
      insertedAt: DateTime(2026, 10, 28, 8, 15),
      currency: 'USD',
      currentPrice: 99.2,
      pnlLimit: WorkerPnlLimit(
        period: 'day',
        lossLimit: 200,
        accumAmount: -215,
        accumCount: 3,
        stoppedAt: DateTime(2026, 10, 30, 5, 12),
        stopReason: '손실 한도 도달',
      ),
      jobs: [
        WorkerJob(
          name: '돌파 매수 전략',
          status: 'closed',
          accountName: '해외선물 메인',
          isPaper: false,
          strategy: _mclBreakoutSmall,
          repeatCurrent: 3,
          repeatCount: 3,
          cycles: [
            _closedCycle(
              3,
              _mclBreakoutSmall,
              openedAt: DateTime(2026, 10, 30, 4, 20, 33),
              buy: 99.85,
              closedAt: DateTime(2026, 10, 30, 5, 11, 58),
              sell: 99.20,
              multiplier: 100,
            ),
            _closedCycle(
              2,
              _mclBreakoutSmall,
              openedAt: DateTime(2026, 10, 30, 2, 2, 11),
              buy: 100.10,
              closedAt: DateTime(2026, 10, 30, 3, 40, 2),
              sell: 99.30,
              multiplier: 100,
            ),
            _closedCycle(
              1,
              _mclBreakoutSmall,
              openedAt: DateTime(2026, 10, 29, 23, 30, 45),
              buy: 100.00,
              closedAt: DateTime(2026, 10, 30, 1, 5, 29),
              sell: 99.30,
              multiplier: 100,
            ),
          ],
        ),
      ],
    ),
    _worker(
      517,
      'NQZ26',
      '나스닥100 12월물',
      '해외선물',
      'USD',
      23415.25,
      WorkerStatus.running,
      DateTime(2026, 10, 29, 22, 20),
      _waitingJob('고점 돌파', _indexFut, '해외선물 메인'),
      autoClose: true,
    ),
    _worker(
      518,
      'FESXZ26',
      '유로스톡스50 12월물',
      '해외선물',
      'EUR',
      5742,
      WorkerStatus.running,
      DateTime(2026, 10, 29, 16, 5),
      _holdingJob(
        '장 초반 돌파',
        _indexFut,
        '해외선물 메인',
        filledAt: DateTime(2026, 10, 30, 3, 12, 30),
        entryPrice: 5725,
        multiplier: 10,
      ),
    ),
  ],
  1016: [
    _worker(
      519,
      '005930',
      '삼성전자',
      '국내주식',
      'KRW',
      99100,
      WorkerStatus.running,
      DateTime(2026, 10, 29, 8, 55),
      _holdingJob('거래량 급증 매수', _stockSwing, '국내주식 메인', filledAt: DateTime(2026, 10, 29, 9, 12, 44), entryPrice: 97800),
      autoClose: true,
    ),
    _worker(
      520,
      '000660',
      'SK하이닉스',
      '국내주식',
      'KRW',
      312500,
      WorkerStatus.running,
      DateTime(2026, 10, 29, 8, 57),
      _waitingJob('눌림목 반등', _hynix, '국내주식 메인'),
    ),
    _worker(
      521,
      '035720',
      '카카오',
      '국내주식',
      'KRW',
      41250,
      WorkerStatus.stopped,
      DateTime(2026, 10, 28, 9, 30),
      _waitingJob('캔들 방향 추종', _stockSwing, '국내주식 메인', status: 'waiting'),
    ),
  ],
  1019: [
    _worker(
      522,
      'MCLZ26',
      '마이크로 WTI 원유 12월물',
      '해외선물',
      'USD',
      101.1,
      WorkerStatus.stopped,
      DateTime(2026, 10, 21, 22, 0),
      _waitingJob('돌파 매수 전략', _mclBreakoutSmall, '해외선물 메인', status: 'waiting'),
    ),
    _worker(
      523,
      'NVDA',
      '엔비디아',
      '해외주식',
      'USD',
      214.37,
      WorkerStatus.stopped,
      DateTime(2026, 10, 21, 23, 15),
      _waitingJob('지표 조합 매수', _nvda, '해외주식 메인', status: 'waiting'),
    ),
  ],
};

final _logs = <int, List<CustomerLog>>{
  1024: [
    CustomerLog(
      DateTime(2026, 10, 29, 21, 52, 11),
      CustomerLogCategory.worker,
      '고점 이탈 알람 감시 시작',
      workerId: 501,
      jobName: '고점 이탈 알람',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 10, 31, 2),
      CustomerLogCategory.order,
      '항셍지수 12월물 매도 1계약 체결 @26,000',
      workerId: 509,
      jobName: '고점 이탈 매도',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 9, 21, 8),
      CustomerLogCategory.worker,
      '항셍지수 12월물 워커 시작',
      workerId: 509,
      jobName: '고점 이탈 매도',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 9, 2, 48),
      CustomerLogCategory.order,
      '코스피200 12월물 매수 1계약 체결 @452.1',
      workerId: 508,
      jobName: '장 초반 돌파',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 8, 46, 3),
      CustomerLogCategory.worker,
      '코스피200 12월물 워커 시작',
      workerId: 508,
      jobName: '장 초반 돌파',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 4, 31, 5),
      CustomerLogCategory.order,
      '마이크로 금 12월물 매도 1계약 체결 (청산) @2,755',
      workerId: 510,
      jobName: '금 트레일링 진입',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 0, 12, 40),
      CustomerLogCategory.order,
      '마이크로 금 12월물 매수 1계약 체결 @2,740',
      workerId: 510,
      jobName: '금 트레일링 진입',
    ),
    CustomerLog(
      DateTime(2026, 10, 29, 22, 0, 44),
      CustomerLogCategory.worker,
      '나스닥100 12월물 워커 시작',
      workerId: 507,
      jobName: '고점 돌파',
    ),
    CustomerLog(
      DateTime(2026, 10, 29, 21, 59, 10),
      CustomerLogCategory.worker,
      '마이크로 금 12월물 워커 시작',
      workerId: 510,
      jobName: '금 트레일링 진입',
    ),
    CustomerLog(
      DateTime(2026, 10, 28, 23, 40, 17),
      CustomerLogCategory.worker,
      '테슬라 워커 중지',
      workerId: 511,
      jobName: '캔들 방향 추종',
    ),
    CustomerLog(
      DateTime(2026, 10, 28, 23, 12, 2),
      CustomerLogCategory.worker,
      '테슬라 워커 시작',
      workerId: 511,
      jobName: '캔들 방향 추종',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 10, 2, 41),
      CustomerLogCategory.order,
      '마이크로 WTI 원유 12월물 매수 2계약 체결 @100.75',
      workerId: 501,
      jobName: '돌파 매수 전략',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 10, 2, 39),
      CustomerLogCategory.order,
      '마이크로 WTI 원유 12월물 매수 2계약 접수 (돌파 매수 전략 3/5)',
      workerId: 501,
      jobName: '돌파 매수 전략',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 9, 40, 5),
      CustomerLogCategory.worker,
      '삼성전자 거래량 급증 매수 잡 스위치 끔 (보유 유지)',
      workerId: 502,
      jobName: '거래량 급증 매수',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 9, 39, 58),
      CustomerLogCategory.worker,
      '삼성전자 워커 중지',
      workerId: 502,
      jobName: '거래량 급증 매수',
    ),
    CustomerLog(DateTime(2026, 10, 30, 9, 12, 7), CustomerLogCategory.access, 'Android 앱 로그인'),
    CustomerLog(
      DateTime(2026, 10, 30, 8, 51, 12),
      CustomerLogCategory.worker,
      '삼성전자 워커 시작',
      workerId: 502,
      jobName: '거래량 급증 매수',
    ),
    CustomerLog(
      DateTime(2026, 10, 29, 21, 50, 6),
      CustomerLogCategory.error,
      '마이크로 WTI 원유 12월물 매수 거부 · 주문 가능 금액 부족',
      workerId: 501,
      jobName: '갭 상승 진입',
    ),
    CustomerLog(
      DateTime(2026, 10, 29, 21, 45, 30),
      CustomerLogCategory.worker,
      '마이크로 WTI 원유 12월물 워커 시작',
      workerId: 501,
    ),
    CustomerLog(DateTime(2026, 10, 29, 21, 31, 2), CustomerLogCategory.access, 'Android 앱 로그인'),
  ],
  1023: [
    CustomerLog(
      DateTime(2026, 10, 30, 9, 0, 5),
      CustomerLogCategory.worker,
      '눌림목 반등 감시 시작',
      workerId: 503,
      jobName: '눌림목 반등',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 9, 0, 6),
      CustomerLogCategory.worker,
      '추세 추종 대기열 등록',
      workerId: 503,
      jobName: '추세 추종',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 9, 4, 22),
      CustomerLogCategory.order,
      '현대차 매수 5주 체결 @249,500',
      workerId: 512,
      jobName: '갭 상승 추종',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 9, 0, 15),
      CustomerLogCategory.worker,
      '현대차 워커 시작',
      workerId: 512,
      jobName: '갭 상승 추종',
    ),
    CustomerLog(
      DateTime(2026, 10, 29, 23, 6, 31),
      CustomerLogCategory.worker,
      '엔비디아 워커 시작',
      workerId: 514,
      jobName: '지표 조합 매수',
    ),
    CustomerLog(
      DateTime(2026, 10, 29, 15, 45, 9),
      CustomerLogCategory.worker,
      '카카오 워커 중지',
      workerId: 513,
      jobName: '눌림목 매수',
    ),
    CustomerLog(DateTime(2026, 10, 30, 9, 0, 3), CustomerLogCategory.worker, 'SK하이닉스 워커 시작', workerId: 503),
    CustomerLog(DateTime(2026, 10, 30, 8, 55, 19), CustomerLogCategory.access, 'iOS 앱 로그인'),
  ],
  1020: [
    CustomerLog(
      DateTime(2026, 10, 29, 23, 41, 9),
      CustomerLogCategory.order,
      '테슬라 매수 5주 체결 @438',
      workerId: 515,
      jobName: '돌파 추종',
    ),
    CustomerLog(
      DateTime(2026, 10, 28, 22, 31, 20),
      CustomerLogCategory.worker,
      '테슬라 워커 시작',
      workerId: 515,
      jobName: '돌파 추종',
    ),
    CustomerLog(
      DateTime(2026, 10, 27, 23, 50, 41),
      CustomerLogCategory.worker,
      '마이크로 금 12월물 워커 중지',
      workerId: 516,
      jobName: '금 트레일링 진입',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 7, 21, 18),
      CustomerLogCategory.order,
      '엔비디아 매수 5주 접수 (지표 조합 매수 1/2)',
      workerId: 505,
      jobName: '지표 조합 매수',
    ),
    CustomerLog(DateTime(2026, 10, 30, 7, 3, 44), CustomerLogCategory.access, 'Android 앱 로그인'),
    CustomerLog(
      DateTime(2026, 10, 30, 6, 58, 12),
      CustomerLogCategory.error,
      '나스닥100 12월물 잔고 불일치 감지, 고점 이탈 매도 잡 비정상종료',
      workerId: 504,
      jobName: '고점 이탈 매도',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 5, 32, 10),
      CustomerLogCategory.order,
      '나스닥100 12월물 매도 1계약 체결 @23,410',
      workerId: 504,
      jobName: '고점 이탈 매도',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 2, 14, 51),
      CustomerLogCategory.order,
      '나스닥100 12월물 매수 1계약 체결 (청산) @23,402.5',
      workerId: 504,
      jobName: '고점 이탈 매도',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 1, 47, 6),
      CustomerLogCategory.order,
      '나스닥100 12월물 매도 1계약 체결 @23,371.25',
      workerId: 504,
      jobName: '고점 이탈 매도',
    ),
    CustomerLog(DateTime(2026, 10, 29, 22, 12, 33), CustomerLogCategory.access, '앱에서 주문 알림 설정 변경'),
  ],
  1016: [
    CustomerLog(
      DateTime(2026, 10, 29, 8, 58, 40),
      CustomerLogCategory.worker,
      'SK하이닉스 워커 시작',
      workerId: 520,
      jobName: '눌림목 반등',
    ),
    CustomerLog(
      DateTime(2026, 10, 28, 10, 14, 5),
      CustomerLogCategory.worker,
      '카카오 워커 중지',
      workerId: 521,
      jobName: '캔들 방향 추종',
    ),
    CustomerLog(DateTime(2026, 10, 29, 15, 20, 11), CustomerLogCategory.access, 'iOS 앱 로그인'),
    CustomerLog(
      DateTime(2026, 10, 29, 9, 12, 44),
      CustomerLogCategory.order,
      '삼성전자 매수 5주 체결 @97,800',
      workerId: 519,
      jobName: '거래량 급증 매수',
    ),
    CustomerLog(
      DateTime(2026, 10, 29, 8, 58, 2),
      CustomerLogCategory.worker,
      '삼성전자 워커 시작',
      workerId: 519,
      jobName: '거래량 급증 매수',
    ),
  ],
  1017: [
    CustomerLog(
      DateTime(2026, 10, 30, 3, 12, 30),
      CustomerLogCategory.order,
      '유로스톡스50 12월물 매수 1계약 체결 @5,725',
      workerId: 518,
      jobName: '장 초반 돌파',
    ),
    CustomerLog(
      DateTime(2026, 10, 29, 22, 21, 12),
      CustomerLogCategory.worker,
      '나스닥100 12월물 워커 시작',
      workerId: 517,
      jobName: '고점 돌파',
    ),
    CustomerLog(
      DateTime(2026, 10, 29, 16, 6, 3),
      CustomerLogCategory.worker,
      '유로스톡스50 12월물 워커 시작',
      workerId: 518,
      jobName: '장 초반 돌파',
    ),
    CustomerLog(DateTime(2026, 10, 30, 6, 47, 29), CustomerLogCategory.access, 'Android 앱 로그인'),
    CustomerLog(
      DateTime(2026, 10, 30, 5, 12, 0),
      CustomerLogCategory.worker,
      '마이크로 WTI 원유 12월물 손실 한도 도달로 워커 종료',
      workerId: 506,
      jobName: '돌파 매수 전략',
    ),
    CustomerLog(
      DateTime(2026, 10, 30, 5, 11, 58),
      CustomerLogCategory.order,
      '마이크로 WTI 원유 12월물 매도 1계약 체결 (청산) @99.20',
      workerId: 506,
      jobName: '돌파 매수 전략',
    ),
  ],
  1019: [
    CustomerLog(DateTime(2026, 10, 22, 10, 0, 12), CustomerLogCategory.access, 'Android 앱 로그인'),
    CustomerLog(
      DateTime(2026, 10, 21, 23, 40, 2),
      CustomerLogCategory.worker,
      '엔비디아 워커 중지',
      workerId: 523,
      jobName: '지표 조합 매수',
    ),
    CustomerLog(
      DateTime(2026, 10, 21, 22, 30, 51),
      CustomerLogCategory.worker,
      '마이크로 WTI 원유 12월물 워커 중지',
      workerId: 522,
      jobName: '돌파 매수 전략',
    ),
  ],
};
