/// API 연결 전까지 화면을 채우는 샘플 데이터.
///
/// 필드 이름은 dungeon-app 이 받는 응답(신호: symbolCode·symbolName·marketType·
/// alertName·side·price·triggeredAt)에 맞춰 두어, 나중에 API 로 바꾸기 쉽게 한다.
library;

import 'package:flutter/foundation.dart';

/// 회원. 관리자 화면에서 상태를 바꾸므로 일부 필드는 바뀔 수 있다.
class Member {
  Member(
    this.id,
    this.username,
    this.email,
    this.joinedAt,
    this.lastLoginAt,
    this.status, {
    this.device = 'Android',
    this.pushAgreed = true,
    this.watchlistCount = 0,
    this.suspendReason,
    this.suspendUntil,
    this.deleteRequestedAt,
    this.accessBlockReason,
    this.accessBlockedAt,
    this.liveId,
    this.liveWorkerCount = 0,
    this.liveRunningCount = 0,
    List<MemberLog>? history,
  }) : history = history ?? [];

  final int id;
  final String username;
  final String email;
  final DateTime joinedAt;
  final DateTime? lastLoginAt; // 승인 전에는 로그인할 수 없어 비어 있다.
  MemberStatus status;
  final String device;
  final bool pushAgreed;
  final int watchlistCount;
  String? suspendReason;
  DateTime? suspendUntil; // 비어 있으면 영구 정지
  final DateTime? deleteRequestedAt;
  String? accessBlockReason;
  DateTime? accessBlockedAt; // 회원 상태와 따로 둔다. 비어 있으면 차단 아님
  final List<MemberLog> history; // 관리자 처리 이력

  final String? liveId; // 테스트 DB 회원의 GUID. 샘플 회원은 비어 있다
  final int liveWorkerCount;
  final int liveRunningCount;

  bool get accessBlocked => accessBlockedAt != null;
  bool get isLive => liveId != null;

  /// 테스트 DB 회원의 이메일은 서버가 이미 가려서 준다.
  String get shownEmail => isLive ? email : maskEmail(email);

  /// 목록에 보여 줄 번호. 테스트 DB 회원은 GUID 앞부분이다.
  String get shownId => isLive ? liveId!.substring(0, 8) : '$id';
}

enum MemberStatus {
  pending('승인 대기'),
  active('정상'),
  dormant('휴면'),
  suspended('정지'),
  deleteRequested('탈퇴 요청');

  const MemberStatus(this.label);
  final String label;
}

/// 회원 처리 이력 한 줄.
class MemberLog {
  const MemberLog(this.at, this.actor, this.text);
  final DateTime at;
  final String actor;
  final String text;
}

/// 처리 이력에 남는 관리자 이름. 로그인하면 그 관리자로 바뀐다.
String currentAdmin = '관리자';

class Signal {
  Signal(
    this.id,
    this.symbolCode,
    this.symbolName,
    this.marketType,
    this.alertName,
    this.side,
    this.price,
    this.triggeredAt,
  );
  final int id;
  final String symbolCode;
  final String symbolName;
  final String marketType;
  final String alertName;
  final String side; // buy | sell
  final double price;
  final DateTime triggeredAt;
}

class PushMessage {
  const PushMessage(this.id, this.title, this.body, this.target, this.sentAt, this.sentCount, this.openCount);
  final int id;
  final String title;
  final String body;
  final String target;
  final DateTime sentAt;
  final int sentCount;
  final int openCount;
}

enum NoticeStatus {
  published('게시'),
  scheduled('예약'),
  draft('임시저장');

  const NoticeStatus(this.label);
  final String label;
}

/// 공지. 관리자 화면에서 고칠 수 있어 일부 필드는 바뀐다.
const noticeCategories = ['공지', '점검', '업데이트', '이벤트'];

class Notice {
  Notice(
    this.id,
    this.title,
    this.body,
    this.author,
    this.createdAt,
    this.views,
    this.pinned,
    this.status, {
    this.publishAt,
    this.updatedAt,
    this.category = '공지',
    this.grades = const {},
    this.popup = false,
    this.endAt,
  });

  final int id;
  String title;
  String body;
  final String author;
  final DateTime createdAt;
  final int views;
  bool pinned;
  NoticeStatus status;
  DateTime? publishAt; // 예약 게시 시각
  DateTime? updatedAt;
  String category;
  Set<String> grades; // 볼 수 있는 회원등급. 비어 있으면 전체
  bool popup; // 앱을 열 때 팝업으로 보여 준다
  DateTime? endAt; // 게시 종료 시각. 비어 있으면 내릴 때까지 게시

  String get audience => grades.isEmpty ? '전체' : grades.join('·');
}

final mockMembers = _seedMembers();

/// 테스트 DB 회원의 화면용 ID 는 이 값부터 시작해 샘플 ID 와 겹치지 않는다.
const liveIdBase = 1000000;

/// 켜면 회원 목록·모니터링이 테스트 DB 를 본다. 앱을 실행하면 켜지고, 테스트는 샘플로 돈다.
final useLiveData = ValueNotifier<bool>(false);

final liveMembers = <Member>[];

/// 회원 목록·모니터링이 보는 회원.
List<Member> get currentMembers => useLiveData.value ? liveMembers : mockMembers;

/// 샘플 회원을 처음 상태로 되돌린다. 화면에서 승인·정지 등을 하면 이 목록이 바뀐다.
void resetMockMembers() {
  mockMembers
    ..clear()
    ..addAll(_seedMembers());
}

List<Member> _seedMembers() => [
  Member(
    1027,
    'newbie_slime',
    'slime@example.com',
    DateTime(2026, 10, 30, 10, 41),
    null,
    MemberStatus.pending,
    device: 'iOS',
  ),
  Member(1026, 'dawn_scalper', 'dawn@example.com', DateTime(2026, 10, 30, 7, 15), null, MemberStatus.pending),
  Member(
    1025,
    'k_futures',
    'kfut@example.com',
    DateTime(2026, 10, 29, 23, 58),
    null,
    MemberStatus.pending,
    pushAgreed: false,
  ),
  Member(
    1024,
    'risingkang',
    'kang@example.com',
    DateTime(2026, 10, 29, 21, 4),
    DateTime(2026, 10, 30, 9, 12),
    MemberStatus.active,
    watchlistCount: 12,
    history: [MemberLog(DateTime(2026, 10, 29, 21, 30), '이운영', '가입 승인')],
  ),
  Member(
    1023,
    'bottomhunter',
    'hunter@example.com',
    DateTime(2026, 10, 29, 14, 37),
    DateTime(2026, 10, 30, 8, 55),
    MemberStatus.active,
    device: 'iOS',
    watchlistCount: 5,
  ),
  Member(
    1022,
    'f_rank_trader',
    'frank@example.com',
    DateTime(2026, 10, 28, 11, 2),
    DateTime(2026, 10, 29, 22, 40),
    MemberStatus.active,
    device: 'Web',
    watchlistCount: 3,
  ),
  Member(
    1021,
    'dungeon_walker',
    'walker@example.com',
    DateTime(2026, 10, 27, 19, 20),
    DateTime(2026, 10, 27, 19, 31),
    MemberStatus.deleteRequested,
    deleteRequestedAt: DateTime(2026, 10, 29, 13, 2),
  ),
  Member(
    1020,
    'uptrend99',
    'up99@example.com',
    DateTime(2026, 10, 25, 8, 45),
    DateTime(2026, 10, 30, 7, 3),
    MemberStatus.active,
    watchlistCount: 20,
  ),
  Member(
    1019,
    'goldraider',
    'gold@example.com',
    DateTime(2026, 10, 21, 16, 10),
    DateTime(2026, 10, 22, 10, 0),
    MemberStatus.suspended,
    suspendReason: '신호 내용 무단 재배포',
    suspendUntil: DateTime(2026, 11, 21),
    history: [MemberLog(DateTime(2026, 10, 22, 11, 0), '이운영', '이용 정지 30일 (신호 내용 무단 재배포)')],
  ),
  Member(
    1018,
    'quietbuyer',
    'quiet@example.com',
    DateTime(2026, 7, 2, 13, 5),
    DateTime(2026, 7, 9, 18, 44),
    MemberStatus.dormant,
    pushAgreed: false,
  ),
  Member(
    1017,
    'oil_knight',
    'knight@example.com',
    DateTime(2026, 6, 18, 9, 30),
    DateTime(2026, 10, 30, 6, 47),
    MemberStatus.active,
    watchlistCount: 8,
  ),
  Member(
    1016,
    'samsung_tank',
    'tank@example.com',
    DateTime(2026, 6, 11, 20, 12),
    DateTime(2026, 10, 29, 15, 20),
    MemberStatus.active,
    device: 'iOS',
    watchlistCount: 4,
  ),
];

final mockSignals = <Signal>[
  Signal(58231, 'MCLZ26', '마이크로 WTI 원유 12월물', '해외선물', '돌파 매수', 'buy', 100.75, DateTime(2026, 10, 30, 11, 3, 23)),
  Signal(58230, '005930', '삼성전자', '국내주식', '거래량 급증', 'buy', 98400, DateTime(2026, 10, 30, 10, 48, 2)),
  Signal(58229, 'NQZ26', '나스닥100 12월물', '해외선물', '고점 이탈', 'sell', 23415.25, DateTime(2026, 10, 30, 10, 21, 40)),
  Signal(58228, '000660', 'SK하이닉스', '국내주식', '눌림목 반등', 'buy', 312500, DateTime(2026, 10, 30, 9, 57, 11)),
  Signal(58227, 'NVDA', '엔비디아', '해외주식', '추세 이탈', 'sell', 214.37, DateTime(2026, 10, 30, 9, 31, 5)),
  Signal(58226, '101Z6', '코스피200 12월물', '국내선물', '돌파 매수', 'buy', 452.1, DateTime(2026, 10, 30, 9, 2, 48)),
];

final mockPushes = <PushMessage>[
  PushMessage(312, '오늘의 던전이 열렸습니다', '장 시작 전 체크할 신호 3개를 확인하세요.', '전체', DateTime(2026, 10, 30, 8, 30), 1018, 412),
  PushMessage(
    311,
    '[점검] 10/29 새벽 서버 점검 안내',
    '02:00~04:00 실시간 신호가 일시 중단됩니다.',
    '전체',
    DateTime(2026, 10, 28, 18, 0),
    1009,
    233,
  ),
  PushMessage(310, '해외선물 신호가 추가되었습니다', '원유·나스닥 선물 신호를 받아보세요.', '해외선물 구독자', DateTime(2026, 10, 27, 9, 0), 286, 141),
];

final mockNotices = _seedNotices();

/// 샘플 공지를 처음 상태로 되돌린다.
void resetMockNotices() {
  mockNotices
    ..clear()
    ..addAll(_seedNotices());
}

List<Notice> _seedNotices() => [
  Notice(
    41,
    '던전우상향 정식 출시 안내',
    '던전우상향이 정식 출시되었습니다. 앱에서 워커와 전략을 만들어 보세요.',
    '운영팀',
    DateTime(2026, 10, 29, 10, 0),
    1532,
    true,
    NoticeStatus.published,
  ),
  Notice(
    40,
    '10/29(목) 새벽 서버 점검 안내',
    '10월 29일 02:00~04:00 서버 점검으로 실시간 신호가 일시 중단됩니다.',
    '운영팀',
    DateTime(2026, 10, 28, 17, 40),
    864,
    false,
    NoticeStatus.published,
    category: '점검',
  ),
  Notice(
    39,
    '해외선물 신호 서비스 오픈',
    '원유·나스닥 등 해외선물 신호를 받아 보실 수 있습니다.',
    '운영팀',
    DateTime(2026, 10, 27, 9, 0),
    701,
    false,
    NoticeStatus.published,
    category: '업데이트',
  ),
  Notice(
    38,
    '개인정보처리방침 개정 예정 안내',
    '개인정보처리방침이 개정될 예정입니다. 세부 내용은 추후 안내드립니다.',
    '운영팀',
    DateTime(2026, 10, 26, 15, 20),
    0,
    false,
    NoticeStatus.draft,
  ),
  Notice(
    37,
    '11월 정기 점검 안내',
    '11월 정기 점검 일정을 안내드립니다.',
    '운영팀',
    DateTime(2026, 10, 30, 11, 30),
    0,
    false,
    NoticeStatus.scheduled,
    publishAt: DateTime(2026, 11, 10, 9, 0),
    category: '점검',
  ),
];

String formatDateTime(DateTime t, {bool seconds = false}) {
  String two(int v) => v.toString().padLeft(2, '0');
  final base = '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  return seconds ? '$base:${two(t.second)}' : base;
}

String formatNumber(num v) {
  final parts = v.toString().split('.');
  final intPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
}

/// 목록에서는 이메일 앞 두 글자만 보여준다. 예: kang@example.com → ka**@example.com
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final id = email.substring(0, at);
  final keep = id.length <= 2 ? 1 : 2;
  return '${id.substring(0, keep)}${'*' * (id.length - keep)}${email.substring(at)}';
}
