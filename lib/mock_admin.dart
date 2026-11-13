/// 관리자 계정·권한·활동 기록 샘플. 비밀번호를 검사하는 곳이 화면뿐이라
/// 실제 인증이 아니다. API 를 붙이면 서버 인증으로 바꾼다.
library;

import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'mock_data.dart';
import 'view_store.dart';

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

/// 관리자 화면의 대화면(위쪽 메뉴)과 그 안의 소화면(탭).
class AdminScreen {
  const AdminScreen(this.label, this.api, [this.children = const []]);
  final String label;
  final String api; // API 의 화면 key 에서 부모 key 를 뺀 끝부분
  final List<AdminScreen> children;
}

/// 회원 모니터링 안의 탭. 상담 흐름 순서다.
const monitorTabs = ['워커', '잡', '잡 내역', '거래', '포지션', '로그', '계좌', '알림', '신호', '전략', '관심종목', '종목'];

const adminScreenTree = [
  AdminScreen('대시보드', 'dashboard', [AdminScreen('회원 현황', 'overview'), AdminScreen('시스템', 'system')]),
  AdminScreen('회원 관리', 'members', [
    AdminScreen('회원 목록', 'list'),
    AdminScreen('회원 모니터링', 'monitor', [
      AdminScreen('워커', 'workers'),
      AdminScreen('잡', 'jobs'),
      AdminScreen('잡 내역', 'jobHistory'),
      AdminScreen('거래', 'trades'),
      AdminScreen('포지션', 'positions'),
      AdminScreen('로그', 'logs'),
      AdminScreen('계좌', 'accounts'),
      AdminScreen('알림', 'notifications'),
      AdminScreen('신호', 'signals'),
      AdminScreen('전략', 'strategies'),
      AdminScreen('관심종목', 'watchlist'),
      AdminScreen('종목', 'symbols'),
    ]),
    AdminScreen('상담 이력', 'consult'),
  ]),
  AdminScreen('종목 마스터', 'symbols'),
  AdminScreen('푸시 알림', 'push'),
  AdminScreen('공지사항', 'notices'),
  AdminScreen('관리자', 'admins'),
];

/// 화면 키는 대화면부터 이어 붙인 경로다. 예: 회원 관리 › 회원 모니터링 › 워커
String screenKey(List<String> path) => path.join(' › ');

String monitorTabKey(String tab) => screenKey(['회원 관리', '회원 모니터링', tab]);

/// 대화면 이름 목록.
final adminScreens = [for (final s in adminScreenTree) s.label];

/// 화면 키 → 같은 부모 아래 형제 키들. 표를 그릴 때와 마지막 하나 검사에 쓴다.
final _siblings = <String, List<String>>{};

/// 화면 키 → 부모 키. 대화면은 없다.
final _parents = <String, String>{};

/// 화면 키 ↔ API key(dashboard.overview 형식).
final _apiOf = <String, String>{};
final _keyOfApi = <String, String>{};

/// 표에 그릴 순서(키, 깊이, 이름).
final adminScreenRows = () {
  final rows = <({String key, int depth, String label})>[];
  void walk(List<AdminScreen> list, List<String> path, String apiPrefix) {
    final keys = [for (final s in list) screenKey([...path, s.label])];
    for (final (i, s) in list.indexed) {
      final key = keys[i];
      final api = '$apiPrefix${s.api}';
      _apiOf[key] = api;
      _keyOfApi[api] = key;
      _siblings[key] = keys;
      if (path.isNotEmpty) _parents[key] = screenKey(path);
      rows.add((key: key, depth: path.length, label: s.label));
      walk(s.children, [...path, s.label], '$api.');
    }
  }

  walk(adminScreenTree, [], '');
  return rows;
}();

Set<String> get _allKeys => {for (final r in adminScreenRows) r.key};

/// 처음 값. 상담 직원은 관리자 화면(활동 기록)을 보지 않는다.
Map<AdminRole, Set<String>> _defaultRoleScreens() => {
  AdminRole.operator: {..._allKeys},
  AdminRole.consultant: {..._allKeys}..remove('관리자'),
};

const _roleScreensKey = 'roleScreens';

/// 등급별로 켠 화면 키. 최고 관리자는 늘 모든 화면을 본다.
/// 관리자 설정 테이블(C-1)이 생기기 전이라 이 브라우저에만 저장된다.
final roleScreens = ValueNotifier<Map<AdminRole, Set<String>>>(_loadRoleScreens());

Map<AdminRole, Set<String>> _loadRoleScreens() {
  adminScreenRows; // 부모·형제 표를 먼저 만든다
  final map = _defaultRoleScreens();
  try {
    final saved = jsonDecode(readView(_roleScreensKey) ?? '{}') as Map<String, dynamic>;
    for (final r in map.keys) {
      final list = saved[r.name];
      if (list is List) map[r] = {for (final s in list) if (_allKeys.contains(s)) '$s'};
    }
  } catch (_) {
    // 저장값이 깨졌으면 처음 값으로 둔다.
  }
  return map;
}

/// 이 화면 자체가 켜져 있는가(부모는 따지지 않는다).
bool roleScreenOn(AdminRole role, String key) =>
    role == AdminRole.superAdmin || (roleScreens.value[role]?.contains(key) ?? false);

/// 부모 화면까지 모두 켜져 있어야 보인다.
bool roleCanSee(AdminRole role, String key) {
  for (String? k = key; k != null; k = _parents[k]) {
    if (!roleScreenOn(role, k)) return false;
  }
  return true;
}

/// 부모 화면이 꺼져 있으면 그 아래 소화면은 고를 수 없다.
bool roleParentOn(AdminRole role, String key) {
  final p = _parents[key];
  return p == null || roleCanSee(role, p);
}

/// 로그인한 관리자가 이 화면을 볼 수 있는가.
bool canSee(String key) {
  adminScreenRows;
  final role = signedInAdmin.value?.role;
  return role != null && roleCanSee(role, key);
}

/// 같은 부모 아래에서 마지막 남은 화면인가. 형제마다 하나는 남아야 한다.
bool isLastRoleScreen(AdminRole role, String key) {
  adminScreenRows;
  final on = roleScreens.value[role] ?? const <String>{};
  return on.contains(key) && (_siblings[key] ?? [key]).where(on.contains).length <= 1;
}

/// 이 등급이 켠 화면을 API key 로 바꾼다. [key] 를 주면 [on] 대로 켜거나 끈 뒤의 값이다.
List<String> roleScreensForApi(AdminRole role, {String? key, bool on = true}) {
  adminScreenRows;
  final set = {...?roleScreens.value[role]};
  if (key != null) on ? set.add(key) : set.remove(key);
  return [for (final k in set) ?_apiOf[k]];
}

/// API 응답(roles[].screens)으로 등급별 화면을 덮어쓴다. 최고 관리자는 늘 전부라 받지 않는다.
void applyRoleScreensFromApi(AdminRole role, List<Object?> apiKeys) {
  adminScreenRows;
  if (role == AdminRole.superAdmin) return;
  final next = {for (final e in roleScreens.value.entries) e.key: {...e.value}};
  next[role] = {for (final a in apiKeys) ?_keyOfApi[a]};
  roleScreens.value = next;
}

/// 등급의 화면 보기를 켜거나 끈다. 최고 관리자 것은 바꿀 수 없다.
void setRoleScreen(AdminRole role, String key, bool on) {
  if (role == AdminRole.superAdmin) return;
  if (!on && isLastRoleScreen(role, key)) return; // 같은 묶음에 볼 화면이 하나는 있어야 한다
  final next = {for (final e in roleScreens.value.entries) e.key: {...e.value}};
  on ? next[role]!.add(key) : next[role]!.remove(key);
  roleScreens.value = next;
  writeView(_roleScreensKey, jsonEncode({for (final e in next.entries) e.key.name: e.value.toList()}));
  logActivity(ActivityKind.admin, '${role.label} 화면 보기 · $key ${on ? '켬' : '끔'}');
}

void resetRoleScreens() {
  roleScreens.value = _defaultRoleScreens();
  writeView(_roleScreensKey, '{}');
}

/// 활동을 기록한다. 고객 정보 열람과 처리 내역을 추적하기 위한 것이다.
void logActivity(ActivityKind kind, String text, {String target = ''}) {
  mockActivities.insert(0, AdminActivity(DateTime.now(), currentAdmin, kind, text, target: target));
}

/// 성공하면 null, 실패하면 안내 문구를 돌려준다.
String? signIn(String loginId, String password) {
  final matches = mockAdmins.where((a) => a.loginId == loginId.trim());
  if (matches.isEmpty || password != samplePassword) return '아이디나 비밀번호가 맞지 않습니다. 다시 입력해 주세요.';
  final admin = matches.first;
  if (!admin.active) return '사용이 중지된 계정입니다. 최고 관리자에게 계정을 다시 켜 달라고 요청하세요.';
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
  resetRoleScreens();
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
