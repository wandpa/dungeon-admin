/// 상담 이력 샘플. 언제 어떤 경로로 무슨 문의를 받았고 누가 어떻게 처리했는지 남긴다.
library;

import 'mock_admin.dart';
import 'mock_data.dart';

enum ConsultChannel {
  phone('전화'),
  kakao('카카오톡'),
  email('이메일'),
  app('앱 문의'),
  other('기타');

  const ConsultChannel(this.label);
  final String label;
}

enum ConsultType {
  order('주문·체결'),
  worker('워커·잡'),
  account('계좌·잔고'),
  notification('알림'),
  member('회원·가입'),
  other('기타');

  const ConsultType(this.label);
  final String label;
}

enum ConsultStatus {
  open('접수'),
  inProgress('처리 중'),
  done('완료');

  const ConsultStatus(this.label);
  final String label;
}

class Consultation {
  Consultation(
    this.id,
    this.memberId,
    this.username,
    this.at,
    this.adminName,
    this.channel,
    this.type,
    this.content,
    this.status, {
    this.workerId,
    this.workerName,
    this.jobName,
    this.handledBy,
    this.handledAt,
  });

  final int id;
  final int memberId;
  final String username;
  final DateTime at;
  final String adminName; // 접수한 관리자
  final ConsultChannel channel;
  final ConsultType type;
  final String content;
  ConsultStatus status;
  final int? workerId; // 상담 당시 보던 워커·잡
  final String? workerName;
  final String? jobName;
  String? handledBy; // 마지막으로 상태를 바꾼 관리자
  DateTime? handledAt;

  String? get linkLabel => workerName == null ? null : [workerName, ?jobName].join(' · ');
}

/// 최신 상담이 앞에 온다.
final mockConsultations = _seedConsultations();

void resetMockConsultations() {
  mockConsultations
    ..clear()
    ..addAll(_seedConsultations());
}

List<Consultation> consultationsOf(int memberId) => [
  for (final c in mockConsultations)
    if (c.memberId == memberId) c,
];

void addConsultation(
  Member m,
  ConsultChannel channel,
  ConsultType type,
  String content, {
  int? workerId,
  String? workerName,
  String? jobName,
}) {
  final id = mockConsultations.map((c) => c.id).fold(0, (a, b) => a > b ? a : b) + 1;
  mockConsultations.insert(
    0,
    Consultation(
      id,
      m.id,
      m.username,
      DateTime.now(),
      currentAdmin,
      channel,
      type,
      content,
      ConsultStatus.open,
      workerId: workerId,
      workerName: workerName,
      jobName: jobName,
    ),
  );
  logActivity(ActivityKind.consult, '${m.username} 상담 접수 · ${channel.label} · ${type.label}', target: m.username);
}

void setConsultStatus(Consultation c, ConsultStatus status) {
  if (c.status == status) return;
  final from = c.status;
  c
    ..status = status
    ..handledBy = currentAdmin
    ..handledAt = DateTime.now();
  logActivity(ActivityKind.consult, '${c.username} 상담 #${c.id} (${from.label} → ${status.label})', target: c.username);
}

List<Consultation> _seedConsultations() => [
  Consultation(
    5,
    1024,
    'risingkang',
    DateTime(2026, 10, 30, 9, 20),
    '박상담',
    ConsultChannel.kakao,
    ConsultType.order,
    '갭 상승 진입 잡이 왜 멈췄는지 문의. 거부 사유 안내 후 입금 확인 대기.',
    ConsultStatus.inProgress,
    workerId: 501,
    workerName: '마이크로 WTI 원유 12월물',
    jobName: '갭 상승 진입',
    handledBy: '박상담',
    handledAt: DateTime(2026, 10, 30, 9, 25),
  ),
  Consultation(
    4,
    1020,
    'uptrend99',
    DateTime(2026, 10, 30, 7, 30),
    '박상담',
    ConsultChannel.phone,
    ConsultType.worker,
    '나스닥 잡이 멈췄다는 문의. 앱 잔고와 증권사 잔고 차이 확인 필요.',
    ConsultStatus.open,
    workerId: 504,
    workerName: '나스닥100 12월물',
    jobName: '고점 이탈 매도',
  ),
  Consultation(
    3,
    1020,
    'uptrend99',
    DateTime(2026, 10, 28, 15, 0),
    '박상담',
    ConsultChannel.phone,
    ConsultType.other,
    '해외선물 신호 지연 문의 → 점검 안내함',
    ConsultStatus.done,
    handledBy: '박상담',
    handledAt: DateTime(2026, 10, 28, 15, 10),
  ),
  Consultation(
    2,
    1019,
    'goldraider',
    DateTime(2026, 10, 23, 10, 40),
    '이운영',
    ConsultChannel.email,
    ConsultType.member,
    '이용 정지 사유 문의. 무단 재배포 내용과 해제일 안내.',
    ConsultStatus.done,
    handledBy: '이운영',
    handledAt: DateTime(2026, 10, 23, 11, 0),
  ),
  Consultation(
    1,
    1018,
    'quietbuyer',
    DateTime(2026, 7, 10, 14, 5),
    '박상담',
    ConsultChannel.app,
    ConsultType.notification,
    '푸시가 오지 않는다는 문의. 기기 알림 권한 켜는 방법 안내.',
    ConsultStatus.done,
    handledBy: '박상담',
    handledAt: DateTime(2026, 7, 10, 14, 20),
  ),
];
