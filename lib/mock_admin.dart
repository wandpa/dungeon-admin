/// 관리자 계정·권한·활동 기록 샘플. 비밀번호를 검사하는 곳이 화면뿐이라
/// 실제 인증이 아니다. API 를 붙이면 서버 인증으로 바꾼다.
library;

import 'package:flutter/foundation.dart';

import 'mock_data.dart';

enum AdminPermission {
  memberActions('회원 승인·정지·차단·탈퇴'),
  exportMembers('회원 내보내기'),
  sendPush('푸시 발송'),
  editNotices('공지 관리'),
  handleIncidents('장애 처리'),
  manageSymbols('종목 마스터 관리'),
  viewActivity('활동 기록 조회'),
  manageAdmins('관리자 계정 관리');

  const AdminPermission(this.label);
  final String label;
}

enum AdminRole {
  superAdmin('최고 관리자', AdminPermission.values),
  operator('운영자', [
    AdminPermission.memberActions,
    AdminPermission.exportMembers,
    AdminPermission.sendPush,
    AdminPermission.editNotices,
    AdminPermission.handleIncidents,
    AdminPermission.manageSymbols,
    AdminPermission.viewActivity,
  ]),
  consultant('상담 직원', []);

  const AdminRole(this.label, this.permissions);
  final String label;
  final List<AdminPermission> permissions;
}

class AdminUser {
  AdminUser(this.id, this.loginId, this.name, this.role, {this.active = true, this.lastLoginAt});

  final int id;
  final String loginId;
  final String name;
  AdminRole role;
  bool active;
  DateTime? lastLoginAt;
}

enum ActivityKind {
  access('접속'),
  view('열람'),
  member('회원 처리'),
  consult('상담'),
  push('푸시'),
  notice('공지'),
  system('시스템'),
  symbol('종목'),
  admin('계정');

  const ActivityKind(this.label);
  final String label;
}

class AdminActivity {
  const AdminActivity(this.at, this.adminName, this.kind, this.text, {this.target = ''});
  final DateTime at;
  final String adminName;
  final ActivityKind kind;
  final String text;
  final String target; // 처리한 회원 아이디. 회원과 무관하면 비어 있다
}

/// 샘플 계정의 공통 비밀번호.
/// 로컬 확인용 로그인 비밀번호. 실제 인증을 붙이기 전까지만 쓴다.
const samplePassword = '11111111';

final mockAdmins = _seedAdmins();

/// 최신 기록이 앞에 온다.
final mockActivities = _seedActivities();

final signedInAdmin = ValueNotifier<AdminUser?>(null);

bool can(AdminPermission p) => signedInAdmin.value?.role.permissions.contains(p) ?? false;

/// 활동을 기록한다. 고객 정보 열람과 처리 내역을 추적하기 위한 것이다.
void logActivity(ActivityKind kind, String text, {String target = ''}) {
  mockActivities.insert(0, AdminActivity(DateTime.now(), currentAdmin, kind, text, target: target));
}

/// 성공하면 null, 실패하면 안내 문구를 돌려준다.
String? signIn(String loginId, String password) {
  final matches = mockAdmins.where((a) => a.loginId == loginId.trim());
  if (matches.isEmpty || password != samplePassword) return '아이디 또는 비밀번호가 맞지 않습니다.';
  final admin = matches.first;
  if (!admin.active) return '사용이 중지된 계정입니다.';
  admin.lastLoginAt = DateTime.now();
  currentAdmin = admin.name;
  signedInAdmin.value = admin;
  logActivity(ActivityKind.access, '로그인');
  return null;
}

void signOut() {
  logActivity(ActivityKind.access, '로그아웃');
  signedInAdmin.value = null;
}

void resetMockAdmins() {
  signedInAdmin.value = null;
  mockAdmins
    ..clear()
    ..addAll(_seedAdmins());
  mockActivities
    ..clear()
    ..addAll(_seedActivities());
}

List<AdminUser> _seedAdmins() => [
  AdminUser(1, 'admin', '김대표', AdminRole.superAdmin, lastLoginAt: DateTime(2026, 10, 30, 8, 30)),
  AdminUser(2, 'operator', '이운영', AdminRole.operator, lastLoginAt: DateTime(2026, 10, 30, 8, 55)),
  AdminUser(3, 'cs', '박상담', AdminRole.consultant, lastLoginAt: DateTime(2026, 10, 30, 9, 2)),
  AdminUser(4, 'cs2', '최퇴사', AdminRole.consultant, active: false, lastLoginAt: DateTime(2026, 9, 30, 18, 0)),
];

List<AdminActivity> _seedActivities() => [
  AdminActivity(DateTime(2026, 10, 30, 9, 15), '박상담', ActivityKind.view, 'uptrend99 회원 모니터링 열람', target: 'uptrend99'),
  AdminActivity(DateTime(2026, 10, 30, 9, 2), '박상담', ActivityKind.access, '로그인'),
  AdminActivity(DateTime(2026, 10, 30, 8, 58), '이운영', ActivityKind.notice, '「10/29(목) 새벽 서버 점검 안내」 게시'),
  AdminActivity(DateTime(2026, 10, 30, 8, 30), '이운영', ActivityKind.push, '「오늘의 던전이 열렸습니다」 전체 1,018명 발송'),
  AdminActivity(
    DateTime(2026, 10, 29, 21, 30),
    '이운영',
    ActivityKind.member,
    'risingkang 가입 승인 (승인 대기 → 정상)',
    target: 'risingkang',
  ),
  AdminActivity(
    DateTime(2026, 10, 22, 11, 0),
    '이운영',
    ActivityKind.member,
    'goldraider 이용 정지 30일 (신호 내용 무단 재배포) (정상 → 정지)',
    target: 'goldraider',
  ),
  AdminActivity(
    DateTime(2026, 10, 9, 10, 0),
    '이운영',
    ActivityKind.member,
    'quietbuyer 휴면 전환 (정상 → 휴면)',
    target: 'quietbuyer',
  ),
];
