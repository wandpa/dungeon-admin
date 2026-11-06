/// 시스템 상태 샘플. 실제 값은 서버가 구성 요소마다 주기적으로 보고해야 한다.
library;

import 'package:flutter/foundation.dart';

import 'mock_admin.dart';
import 'mock_data.dart';

enum SystemLevel {
  ok('정상'),
  degraded('지연'),
  down('장애');

  const SystemLevel(this.label);
  final String label;
}

class SystemComponent {
  const SystemComponent(this.group, this.name, this.level, this.lastSeen, this.metrics);

  final String group;
  final String name;
  final SystemLevel level;
  final DateTime lastSeen; // 마지막 정상 보고 시각
  final Map<String, String> metrics;
}

enum IncidentStatus {
  open('발생'),
  acknowledged('확인 중'),
  resolved('해결');

  const IncidentStatus(this.label);
  final String label;
}

class SystemIncident {
  SystemIncident(
    this.id,
    this.at,
    this.component,
    this.level,
    this.title,
    this.detail,
    this.affectedMembers,
    this.status, {
    this.handledBy,
    this.handledAt,
  });

  final int id;
  final DateTime at;
  final String component;
  final SystemLevel level;
  final String title;
  final String detail;
  final int affectedMembers;
  IncidentStatus status;
  String? handledBy;
  DateTime? handledAt;
}

/// 대시보드 탭에서 시스템 상태 탭을 열어 달라는 요청. 값이 바뀔 때마다 이동한다.
final systemPageRequest = ValueNotifier<int>(0);

final _checkedAt = DateTime(2026, 10, 30, 10, 45, 12);

final mockComponents = <SystemComponent>[
  SystemComponent('증권사 연결', 'KIS 국내주식 실전', SystemLevel.ok, _checkedAt, const {'응답': '84ms', '세션': '12개'}),
  SystemComponent('증권사 연결', 'KIS 국내주식 모의', SystemLevel.ok, _checkedAt, const {'응답': '132ms', '세션': '4개'}),
  SystemComponent('증권사 연결', 'KIS 해외선물 실전', SystemLevel.degraded, _checkedAt, const {
    '응답': '1,850ms',
    '세션': '9개',
    '최근 실패': '3건',
  }),
  SystemComponent('시세 수신', '국내 시세', SystemLevel.ok, _checkedAt, const {'지연': '0.2초', '구독 종목': '142개'}),
  SystemComponent('시세 수신', '해외선물 시세', SystemLevel.ok, _checkedAt, const {'지연': '0.4초', '구독 종목': '18개'}),
  SystemComponent('주문 엔진', '전략 판정', SystemLevel.ok, _checkedAt, const {'가동 워커': '14개', '판정 지연': '35ms'}),
  SystemComponent('주문 엔진', '주문 처리', SystemLevel.ok, _checkedAt, const {'대기 주문': '1건', '평균 처리': '120ms'}),
  SystemComponent('푸시', 'FCM 발송', SystemLevel.ok, _checkedAt, const {'최근 성공률': '98.2%', '대기': '0건'}),
  SystemComponent('서버', 'API 서버', SystemLevel.ok, _checkedAt, const {'오류율': '0.1%', '응답': '48ms'}),
  SystemComponent('서버', '데이터베이스', SystemLevel.ok, _checkedAt, const {'연결': '32개', '복제 지연': '0초'}),
  SystemComponent('서버', 'Redis', SystemLevel.ok, _checkedAt, const {'메모리': '41%', '응답': '2ms'}),
];

/// 대시보드에 띄울 항목 하나. 값은 해당 구성 요소 중 가장 나쁜 상태다.
class SystemSummary {
  const SystemSummary(this.label, this.level);
  final String label;
  final SystemLevel level;
}

SystemLevel _worst(bool Function(SystemComponent) test) =>
    mockComponents.where(test).map((c) => c.level).fold(SystemLevel.ok, (a, b) => b.index > a.index ? b : a);

List<SystemSummary> get systemSummaries => [
  SystemSummary('서버', _worst((c) => c.group == '서버')),
  SystemSummary('국내 수신', _worst((c) => c.name == '국내 시세')),
  SystemSummary('해외 수신', _worst((c) => c.name == '해외선물 시세')),
  SystemSummary('증권사 연결', _worst((c) => c.group == '증권사 연결')),
  SystemSummary('주문 엔진', _worst((c) => c.group == '주문 엔진')),
  SystemSummary('푸시', _worst((c) => c.group == '푸시')),
];

final mockIncidents = _seedIncidents();

void resetMockIncidents() {
  mockIncidents
    ..clear()
    ..addAll(_seedIncidents());
}

List<SystemIncident> get activeIncidents => [
  for (final i in mockIncidents)
    if (i.status != IncidentStatus.resolved) i,
];

/// 가장 나쁜 구성 요소 상태. 전체 상태로 쓴다.
SystemLevel get overallLevel =>
    mockComponents.map((c) => c.level).fold(SystemLevel.ok, (a, b) => b.index > a.index ? b : a);

void setIncidentStatus(SystemIncident i, IncidentStatus status) {
  if (i.status == status) return;
  final from = i.status;
  i
    ..status = status
    ..handledBy = currentAdmin
    ..handledAt = DateTime.now();
  logActivity(ActivityKind.system, '장애 #${i.id} ${i.title} (${from.label} → ${status.label})');
}

List<SystemIncident> _seedIncidents() => [
  SystemIncident(
    3,
    DateTime(2026, 10, 30, 10, 38),
    'KIS 해외선물 실전',
    SystemLevel.degraded,
    '해외선물 주문 응답 지연',
    '최근 10분 평균 응답이 1,850ms 입니다. 평소 200ms 안팎입니다.',
    3,
    IncidentStatus.open,
  ),
  SystemIncident(
    2,
    DateTime(2026, 10, 30, 6, 58),
    '주문 처리',
    SystemLevel.degraded,
    '잔고 불일치 감지',
    '나스닥100 12월물에서 서버 포지션과 증권사 잔고가 달라 잡 1개를 정지했습니다.',
    1,
    IncidentStatus.acknowledged,
    handledBy: '이운영',
    handledAt: DateTime(2026, 10, 30, 7, 10),
  ),
  SystemIncident(
    1,
    DateTime(2026, 10, 29, 2, 0),
    'FCM 발송',
    SystemLevel.down,
    '푸시 발송 중단',
    '서버 점검 중 02:00~02:40 푸시 발송이 멈췄습니다.',
    212,
    IncidentStatus.resolved,
    handledBy: '이운영',
    handledAt: DateTime(2026, 10, 29, 2, 45),
  ),
];
