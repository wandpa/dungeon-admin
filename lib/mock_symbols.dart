/// 선물 상품 마스터와 월물 샘플. 앱과 같이 상품 아래 월물이 있고, 월물 하나가 곧 종목이다.
/// 틱 값은 앱 상품 응답, 시간은 앱 MarketStatus 에 맞춘 항목이다.
/// 시간은 한국시간(KST)이다. 해외 상품은 서머타임 때 관리자가 시간을 옮긴다.
/// 시간과 만기일은 예시 값이며 실제 거래소와 대조되지 않았다.
library;

import 'mock_admin.dart';
import 'mock_data.dart';
import 'mock_workers.dart';

/// 월물 하나. [code] 가 워커가 쓰는 종목코드다.
class ContractMonth {
  ContractMonth(this.code, this.month, this.expiry, {this.active = true, this.sessionOpen, this.sessionClose});

  final String code;
  String month; // YYYYMM
  DateTime expiry;
  bool active;
  String? sessionOpen; // 비어 있으면 상품 시간을 쓴다
  String? sessionClose;

  // 거래 정보. 실제로는 시세에서 받는 값이다.
  DateTime? firstTrade;
  double lastPrice = 0;
  double change = 0;
  int volume = 0;
  int openInterest = 0;

  bool get expired => expiry.isBefore(mockSymbolToday);
}

class MasterSymbol {
  MasterSymbol({
    required this.productCode,
    required this.name,
    required this.marketType,
    required this.exchange,
    required this.currency,
    required this.tickSize,
    required this.tickValue,
    required this.sessionOpen,
    required this.sessionClose,
    required this.orderOpen,
    required this.orderClose,
    required this.timeZone,
    this.dstRule = '없음',
    List<ContractMonth>? months,
    this.breakTime = '',
    this.autoCloseAt,
    this.holidays = '',
    this.active = true,
  }) : months = months ?? [];

  final String productCode;
  String name;
  final String marketType; // 국내선물 | 해외선물
  String exchange;
  String currency;
  double tickSize;
  double tickValue;
  String sessionOpen; // 장 시작 HH:mm (KST)
  String sessionClose; // 장 종료 HH:mm (KST)
  String orderOpen; // 주문 가능 시작 HH:mm (KST)
  String orderClose; // 주문 가능 종료 HH:mm (KST)
  String timeZone; // 거래소 타임존
  String dstRule; // 서머타임 구분: 미국 | 유럽 | 없음
  String breakTime; // 휴식 구간. 비어 있으면 없음
  String? autoCloseAt; // 장 마감 자동 청산 시각. 비어 있으면 앱 기본 규칙을 따른다
  String holidays;
  bool active;
  final List<ContractMonth> months;

  /// 앱과 같이 계약승수는 틱 가치 ÷ 틱 크기다.
  double get multiplier => tickValue / tickSize;

  String openOf(ContractMonth m) => m.sessionOpen ?? sessionOpen;
  String closeOf(ContractMonth m) => m.sessionClose ?? sessionClose;

  /// 거래 중인 월물을 만기가 빠른 순서로 준다. 만기가 지났거나 사용 중지한 월물은 뺀다.
  List<ContractMonth> get liveMonths =>
      months.where((m) => m.active && !m.expired).toList()..sort((a, b) => a.expiry.compareTo(b.expiry));

  ContractMonth? get nearMonth => liveMonths.firstOrNull;

  /// 최근월물·차월물·차차월물·차차차월물. 거래 중이 아니면 빈 문자열이다.
  String monthLabel(ContractMonth m) {
    final i = liveMonths.indexOf(m);
    if (i < 0) return '';
    if (i == 0) return '최근월물';
    return i <= 3 ? '${'차' * i}월물' : '${i + 1}번째 월물';
  }
}

/// 글 속의 HH:mm 을 모두 [hours] 만큼 옮긴다. 24시를 넘으면 다음 날로 돌아간다.
String shiftTimes(String text, int hours) => text.replaceAllMapped(RegExp(r'\b(\d{2}):(\d{2})\b'), (x) {
  final h = (int.parse(x[1]!) + hours) % 24;
  return '${h.toString().padLeft(2, '0')}:${x[2]}';
});

const dstRules = ['없음', '미국', '유럽'];

/// 지금 서머타임이 적용 중인가. 샘플 날짜(2026-10-30) 기준 미국은 적용 중, 유럽은 끝난 상태다.
final dstActive = {'미국': true, '유럽': false};

/// 다음 전환일. 샘플 값이며, 전환을 적용하면 지운다.
final dstNextChange = <String, DateTime?>{'미국': DateTime(2026, 11, 1), '유럽': DateTime(2027, 3, 28)};

/// 전환일이 이 날수 안으로 들어오면 대시보드에 알린다.
const dstAlertDays = 14;

/// 곧 전환해야 하는 서머타임. 예: 미국 서머타임 종료 D-2
List<String> get dstAlerts => [
  for (final MapEntry(key: rule, value: at) in dstNextChange.entries)
    if (at != null && at.difference(mockSymbolToday).inDays <= dstAlertDays)
      '$rule 서머타임 ${dstActive[rule]! ? '종료' : '시작'} D-${at.difference(mockSymbolToday).inDays}',
];

/// 서머타임을 시작·종료한다. 시작하면 한국시간이 1시간 앞당겨지고, 종료하면 늦춰진다.
void applyDstChange(String rule) {
  final starting = !dstActive[rule]!;
  final hours = starting ? -1 : 1;
  for (final s in mockSymbols.where((s) => s.dstRule == rule)) {
    final before = '${s.sessionOpen}~${s.sessionClose}';
    final auto = s.autoCloseAt;
    s
      ..sessionOpen = shiftTimes(s.sessionOpen, hours)
      ..sessionClose = shiftTimes(s.sessionClose, hours)
      ..orderOpen = shiftTimes(s.orderOpen, hours)
      ..orderClose = shiftTimes(s.orderClose, hours)
      ..breakTime = shiftTimes(s.breakTime, hours)
      ..autoCloseAt = auto == null ? null : shiftTimes(auto, hours);
    for (final c in s.months) {
      final open = c.sessionOpen, close = c.sessionClose;
      c
        ..sessionOpen = open == null ? null : shiftTimes(open, hours)
        ..sessionClose = close == null ? null : shiftTimes(close, hours);
    }
    logSymbolChange(
      '${s.productCode} $rule 서머타임 ${starting ? '시작' : '종료'}: 장 시간 $before → ${s.sessionOpen}~${s.sessionClose}',
    );
  }
  dstActive[rule] = starting;
  dstNextChange[rule] = null;
}

const marketTypes = ['국내선물', '해외선물'];
const currencies = ['KRW', 'USD', 'HKD', 'EUR'];

/// 샘플 데이터의 마지막 날을 오늘로 본다.
final mockSymbolToday = DateTime(2026, 10, 30);

final mockSymbols = _seedSymbols();

void resetMockSymbols() {
  dstActive
    ..['미국'] = true
    ..['유럽'] = false;
  dstNextChange
    ..['미국'] = DateTime(2026, 11, 1)
    ..['유럽'] = DateTime(2027, 3, 28);
  mockSymbols
    ..clear()
    ..addAll(_seedSymbols());
}

/// 틱 크기. 선물 월물이 아니면(주식) null 이다.
double? tickSizeOf(String code) {
  for (final s in mockSymbols) {
    if (s.months.any((m) => m.code == code)) return s.tickSize;
  }
  return null;
}

/// 이 월물을 쓰는 워커 수.
int workersOnMonth(String code) {
  var count = 0;
  for (final m in mockMembers) {
    count += workersOf(m.id).where((w) => w.symbolCode == code).length;
  }
  return count;
}

/// 이 상품의 모든 월물을 쓰는 워커 수.
int workersOnProduct(MasterSymbol s) => s.months.fold(0, (n, m) => n + workersOnMonth(m.code));

void logSymbolChange(String text) => logActivity(ActivityKind.symbol, text);

/// 샘플 거래 정보를 채운다. 최근월물일수록 거래가 많다.
List<MasterSymbol> _seedSymbols() {
  const prices = {
    '101': 453.0,
    '106': 912.5,
    'MCL': 101.1,
    'NQ': 23415.25,
    'MGC': 2752.0,
    'HSI': 25950.0,
    'FESX': 5742.0,
  };
  const volumes = [184320, 42110, 9820, 1840];
  const interests = [96540, 38210, 12480, 3260];
  final symbols = _baseSymbols();
  for (final s in symbols) {
    for (final (i, c) in s.months.indexed) {
      c
        ..firstTrade = c.expiry.subtract(const Duration(days: 400))
        ..lastPrice = prices[s.productCode]! + s.tickSize * i * 4
        ..change = s.tickSize * (i.isEven ? 6 : -3)
        ..volume = volumes[i % volumes.length]
        ..openInterest = interests[i % interests.length];
    }
  }
  return symbols;
}

List<MasterSymbol> _baseSymbols() => [
  MasterSymbol(
    productCode: '101',
    name: '코스피200',
    marketType: '국내선물',
    exchange: 'KRX',
    currency: 'KRW',
    tickSize: 0.05,
    tickValue: 12500,
    sessionOpen: '08:45',
    sessionClose: '15:45',
    orderOpen: '08:30',
    orderClose: '15:45',
    timeZone: 'Asia/Seoul',
    holidays: '2026-12-25, 2026-12-31',
    months: [
      ContractMonth('101Z6', '202612', DateTime(2026, 12, 10)),
      ContractMonth('101H7', '202703', DateTime(2027, 3, 11)),
      ContractMonth('101M7', '202706', DateTime(2027, 6, 10)),
    ],
  ),
  MasterSymbol(
    productCode: '106',
    name: '코스닥150',
    marketType: '국내선물',
    exchange: 'KRX',
    currency: 'KRW',
    tickSize: 0.1,
    tickValue: 1000,
    sessionOpen: '08:45',
    sessionClose: '15:45',
    orderOpen: '08:30',
    orderClose: '15:45',
    timeZone: 'Asia/Seoul',
    holidays: '2026-12-25, 2026-12-31',
    months: [
      ContractMonth('106Z6', '202612', DateTime(2026, 12, 10)),
      ContractMonth('106H7', '202703', DateTime(2027, 3, 11)),
    ],
  ),
  MasterSymbol(
    productCode: 'MCL',
    name: '마이크로 WTI 원유',
    marketType: '해외선물',
    exchange: 'CME',
    currency: 'USD',
    tickSize: 0.01,
    tickValue: 1,
    sessionOpen: '07:00',
    sessionClose: '06:00',
    orderOpen: '07:00',
    orderClose: '06:00',
    timeZone: 'America/Chicago',
    dstRule: '미국',
    breakTime: '06:00-07:00',
    holidays: '2026-11-26',
    months: [
      ContractMonth('MCLZ26', '202612', DateTime(2026, 11, 17)),
      ContractMonth('MCLF27', '202701', DateTime(2026, 12, 17)),
      ContractMonth('MCLG27', '202702', DateTime(2027, 1, 20)),
      ContractMonth('MCLJ27', '202704', DateTime(2027, 3, 22)),
    ],
  ),
  MasterSymbol(
    productCode: 'NQ',
    name: '나스닥100',
    marketType: '해외선물',
    exchange: 'CME',
    currency: 'USD',
    tickSize: 0.25,
    tickValue: 5,
    sessionOpen: '07:00',
    sessionClose: '06:00',
    orderOpen: '07:00',
    orderClose: '06:00',
    timeZone: 'America/Chicago',
    dstRule: '미국',
    breakTime: '06:00-07:00',
    holidays: '2026-11-26',
    months: [
      ContractMonth('NQZ26', '202612', DateTime(2026, 12, 18)),
      ContractMonth('NQH27', '202703', DateTime(2027, 3, 19)),
      ContractMonth('NQM27', '202706', DateTime(2027, 6, 18)),
      ContractMonth('NQU27', '202709', DateTime(2027, 9, 17)),
    ],
  ),
  MasterSymbol(
    productCode: 'MGC',
    name: '마이크로 금',
    marketType: '해외선물',
    exchange: 'CME',
    currency: 'USD',
    tickSize: 0.1,
    tickValue: 1,
    sessionOpen: '07:00',
    sessionClose: '06:00',
    orderOpen: '07:00',
    orderClose: '06:00',
    timeZone: 'America/Chicago',
    dstRule: '미국',
    breakTime: '06:00-07:00',
    holidays: '2026-11-26',
    months: [
      ContractMonth('MGCZ26', '202612', DateTime(2026, 12, 29)),
      ContractMonth('MGCG27', '202702', DateTime(2027, 2, 24)),
      ContractMonth('MGCJ27', '202704', DateTime(2027, 4, 28)),
      ContractMonth('MGCM27', '202706', DateTime(2027, 6, 28)),
    ],
  ),
  MasterSymbol(
    productCode: 'HSI',
    name: '항셍지수',
    marketType: '해외선물',
    exchange: 'HKEX',
    currency: 'HKD',
    tickSize: 1,
    tickValue: 50,
    sessionOpen: '10:15',
    sessionClose: '04:00',
    orderOpen: '10:15',
    orderClose: '04:00',
    timeZone: 'Asia/Hong_Kong',
    breakTime: '13:00-14:00, 17:30-18:15',
    holidays: '2026-12-25',
    months: [
      ContractMonth('HSIX26', '202611', DateTime(2026, 11, 27)),
      ContractMonth('HSIZ26', '202612', DateTime(2026, 12, 30)),
      ContractMonth('HSIF27', '202701', DateTime(2027, 1, 28)),
      ContractMonth('HSIH27', '202703', DateTime(2027, 3, 30)),
    ],
  ),
  MasterSymbol(
    productCode: 'FESX',
    name: '유로스톡스50',
    marketType: '해외선물',
    exchange: 'EUREX',
    currency: 'EUR',
    tickSize: 1,
    tickValue: 10,
    sessionOpen: '09:10',
    sessionClose: '06:00',
    orderOpen: '09:10',
    orderClose: '06:00',
    timeZone: 'Europe/Berlin',
    dstRule: '유럽',
    holidays: '2026-12-25',
    months: [
      ContractMonth('FESXZ26', '202612', DateTime(2026, 12, 18)),
      ContractMonth('FESXH27', '202703', DateTime(2027, 3, 19)),
      ContractMonth('FESXM27', '202706', DateTime(2027, 6, 18)),
      ContractMonth('FESXU27', '202709', DateTime(2027, 9, 17)),
    ],
  ),
];
