import '../mock_admin.dart';
import '../mock_data.dart';

/// 회원 상태를 바꾸는 처리. 지금은 샘플 목록(mockMembers)만 바꾼다.
/// API 를 붙이면 각 함수 안에서 dungeon-admin-api 를 부르도록 바꾼다.

/// 회원 처리 이력과 관리자 활동 기록에 함께 남긴다. [from] 을 주면 상태 변화도 기록한다.
void _log(Member m, String text, {ActivityKind kind = ActivityKind.member, MemberStatus? from}) {
  m.history.insert(0, MemberLog(DateTime.now(), currentAdmin, text));
  final change = from == null ? '' : ' (${from.label} → ${m.status.label})';
  logActivity(kind, '${m.username} $text$change', target: m.username);
}

void approveMember(Member m) {
  final from = m.status;
  m.status = MemberStatus.active;
  _log(m, '가입 승인', from: from);
}

/// 가입 거절: 승인 전 회원은 목록에서 지운다.
void rejectMember(Member m) {
  mockMembers.remove(m);
  logActivity(ActivityKind.member, '${m.username} 가입 거절', target: m.username);
}

/// [days] 가 비어 있으면 영구 정지.
void suspendMember(Member m, {required String reason, int? days}) {
  final from = m.status;
  m
    ..status = MemberStatus.suspended
    ..suspendReason = reason
    ..suspendUntil = days == null ? null : DateTime.now().add(Duration(days: days));
  _log(m, '이용 정지 ${days == null ? '영구' : '$days일'} ($reason)', from: from);
}

void unsuspendMember(Member m) {
  final from = m.status;
  m
    ..status = MemberStatus.active
    ..suspendReason = null
    ..suspendUntil = null;
  _log(m, '정지 해제', from: from);
}

/// 접속 차단: 회원 상태는 그대로 두고 앱 접속만 막는다. 관리자가 풀 때까지 유지된다.
void blockAccess(Member m, {required String reason}) {
  m
    ..accessBlockReason = reason
    ..accessBlockedAt = DateTime.now();
  _log(m, '접속 차단 ($reason)');
}

void unblockAccess(Member m) {
  m
    ..accessBlockReason = null
    ..accessBlockedAt = null;
  _log(m, '접속 차단 해제');
}

/// 탈퇴 처리 완료: 회원 정보를 목록에서 지운다.
void completeDeletion(Member m) {
  mockMembers.remove(m);
  logActivity(ActivityKind.member, '${m.username} 탈퇴 처리 완료', target: m.username);
}

void markDormant(Member m) {
  final from = m.status;
  m.status = MemberStatus.dormant;
  _log(m, '휴면 전환', from: from);
}

void releaseDormant(Member m) {
  final from = m.status;
  m.status = MemberStatus.active;
  _log(m, '휴면 해제', from: from);
}

void sendPasswordReset(Member m) => _log(m, '비밀번호 재설정 메일 발송');

/// 마스킹 해제 같은 개인정보 열람도 이력에 남긴다.
void logPrivacyView(Member m, String what) => _log(m, '$what 전체 보기', kind: ActivityKind.view);
