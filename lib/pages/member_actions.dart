import '../mock_data.dart';

/// 회원 상태를 바꾸는 처리. 지금은 샘플 목록(mockMembers)만 바꾼다.
/// API 를 붙이면 각 함수 안에서 dungeon-admin-api 를 부르도록 바꾼다.

void _log(Member m, String text) => m.history.insert(0, MemberLog(DateTime.now(), currentAdmin, text));

void approveMember(Member m) {
  m.status = MemberStatus.active;
  _log(m, '가입 승인');
}

/// 가입 거절: 승인 전 회원은 목록에서 지운다.
void rejectMember(Member m) => mockMembers.remove(m);

/// [days] 가 비어 있으면 영구 정지.
void suspendMember(Member m, {required String reason, int? days}) {
  m
    ..status = MemberStatus.suspended
    ..suspendReason = reason
    ..suspendUntil = days == null ? null : DateTime.now().add(Duration(days: days));
  _log(m, '이용 정지 ${days == null ? '영구' : '$days일'} ($reason)');
}

void unsuspendMember(Member m) {
  m
    ..status = MemberStatus.active
    ..suspendReason = null
    ..suspendUntil = null;
  _log(m, '정지 해제');
}

/// 탈퇴 처리 완료: 회원 정보를 목록에서 지운다.
void completeDeletion(Member m) => mockMembers.remove(m);

void addMemo(Member m, String text) => m.memos.insert(0, MemberLog(DateTime.now(), currentAdmin, text));

/// 마스킹 해제 같은 개인정보 열람도 이력에 남긴다.
void logPrivacyView(Member m, String what) => _log(m, '$what 전체 보기');
