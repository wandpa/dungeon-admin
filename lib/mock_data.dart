/// API 연결 전까지 화면을 채우는 샘플 데이터.
///
/// 필드 이름은 dungeon-app 이 받는 응답(신호: symbolCode·symbolName·marketType·
/// alertName·side·price·triggeredAt)에 맞춰 두어, 나중에 API 로 바꾸기 쉽게 한다.
library;

class Member {
  const Member(this.id, this.username, this.email, this.joinedAt, this.lastLoginAt, this.status);
  final int id;
  final String username;
  final String email;
  final DateTime joinedAt;
  final DateTime lastLoginAt;
  final MemberStatus status;
}

enum MemberStatus {
  active('정상'),
  dormant('휴면'),
  suspended('정지'),
  deleteRequested('탈퇴 요청');

  const MemberStatus(this.label);
  final String label;
}

class Signal {
  const Signal(this.id, this.symbolCode, this.symbolName, this.marketType, this.alertName,
      this.side, this.price, this.triggeredAt);
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
  const PushMessage(this.id, this.title, this.body, this.target, this.sentAt, this.sentCount,
      this.openCount);
  final int id;
  final String title;
  final String body;
  final String target;
  final DateTime sentAt;
  final int sentCount;
  final int openCount;
}

class Notice {
  const Notice(this.id, this.title, this.author, this.createdAt, this.views, this.pinned,
      this.published);
  final int id;
  final String title;
  final String author;
  final DateTime createdAt;
  final int views;
  final bool pinned;
  final bool published;
}

final mockMembers = <Member>[
  Member(1024, 'risingkang', 'kang@example.com', DateTime(2026, 10, 29, 21, 4),
      DateTime(2026, 10, 30, 9, 12), MemberStatus.active),
  Member(1023, 'bottomhunter', 'hunter@example.com', DateTime(2026, 10, 29, 14, 37),
      DateTime(2026, 10, 30, 8, 55), MemberStatus.active),
  Member(1022, 'f_rank_trader', 'frank@example.com', DateTime(2026, 10, 28, 11, 2),
      DateTime(2026, 10, 29, 22, 40), MemberStatus.active),
  Member(1021, 'dungeon_walker', 'walker@example.com', DateTime(2026, 10, 27, 19, 20),
      DateTime(2026, 10, 27, 19, 31), MemberStatus.deleteRequested),
  Member(1020, 'uptrend99', 'up99@example.com', DateTime(2026, 10, 25, 8, 45),
      DateTime(2026, 10, 30, 7, 3), MemberStatus.active),
  Member(1019, 'goldraider', 'gold@example.com', DateTime(2026, 10, 21, 16, 10),
      DateTime(2026, 10, 22, 10, 0), MemberStatus.suspended),
  Member(1018, 'quietbuyer', 'quiet@example.com', DateTime(2026, 7, 2, 13, 5),
      DateTime(2026, 7, 9, 18, 44), MemberStatus.dormant),
];

final mockSignals = <Signal>[
  Signal(58231, 'MCLZ26', '마이크로 WTI 원유 12월물', '해외선물', '돌파 매수', 'buy', 100.75,
      DateTime(2026, 10, 30, 11, 3, 23)),
  Signal(58230, '005930', '삼성전자', '국내주식', '거래량 급증', 'buy', 98400,
      DateTime(2026, 10, 30, 10, 48, 2)),
  Signal(58229, 'NQZ26', '나스닥100 12월물', '해외선물', '고점 이탈', 'sell', 23415.25,
      DateTime(2026, 10, 30, 10, 21, 40)),
  Signal(58228, '000660', 'SK하이닉스', '국내주식', '눌림목 반등', 'buy', 312500,
      DateTime(2026, 10, 30, 9, 57, 11)),
  Signal(58227, 'NVDA', '엔비디아', '해외주식', '추세 이탈', 'sell', 214.37,
      DateTime(2026, 10, 30, 9, 31, 5)),
  Signal(58226, '101Z6', '코스피200 12월물', '국내선물', '돌파 매수', 'buy', 452.1,
      DateTime(2026, 10, 30, 9, 2, 48)),
];

final mockPushes = <PushMessage>[
  PushMessage(312, '오늘의 던전이 열렸습니다', '장 시작 전 체크할 신호 3개를 확인하세요.', '전체', DateTime(2026, 10, 30, 8, 30),
      1018, 412),
  PushMessage(311, '[점검] 10/29 새벽 서버 점검 안내', '02:00~04:00 실시간 신호가 일시 중단됩니다.', '전체',
      DateTime(2026, 10, 28, 18, 0), 1009, 233),
  PushMessage(310, '해외선물 신호가 추가되었습니다', '원유·나스닥 선물 신호를 받아보세요.', '해외선물 구독자',
      DateTime(2026, 10, 27, 9, 0), 286, 141),
];

final mockNotices = <Notice>[
  Notice(41, '던전우상향 정식 출시 안내', '운영팀', DateTime(2026, 10, 29, 10, 0), 1532, true, true),
  Notice(40, '10/29(목) 새벽 서버 점검 안내', '운영팀', DateTime(2026, 10, 28, 17, 40), 864, false, true),
  Notice(39, '해외선물 신호 서비스 오픈', '운영팀', DateTime(2026, 10, 27, 9, 0), 701, false, true),
  Notice(38, '개인정보처리방침 개정 예정 안내', '운영팀', DateTime(2026, 10, 26, 15, 20), 0, false, false),
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
