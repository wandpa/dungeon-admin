import 'package:flutter/material.dart';

import '../mock_admin.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

/// 활동 기록과 관리자 계정. 계정 탭은 최고 관리자에게만 보인다.
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  static const _activityLimit = 100;

  bool _showAccounts = false;
  String _query = '';
  ActivityKind? _kind; // null 이면 전체

  final _name = TextEditingController();
  final _loginId = TextEditingController();
  AdminRole _newRole = AdminRole.consultant;

  @override
  void dispose() {
    _name.dispose();
    _loginId.dispose();
    super.dispose();
  }

  List<AdminActivity> get _activities {
    final q = _query.trim().toLowerCase();
    return [
      for (final a in mockActivities)
        if ((_kind == null || a.kind == _kind) &&
            (q.isEmpty ||
                a.text.toLowerCase().contains(q) ||
                a.adminName.toLowerCase().contains(q) ||
                a.target.toLowerCase().contains(q)))
          a,
    ];
  }

  void _addAdmin() {
    final name = _name.text.trim();
    final loginId = _loginId.text.trim();
    if (name.isEmpty || loginId.isEmpty) return;
    if (mockAdmins.any((a) => a.loginId == loginId)) {
      showMessage(context, '이미 있는 아이디입니다.');
      return;
    }
    setState(() {
      final id = mockAdmins.map((a) => a.id).fold(0, (m, v) => v > m ? v : m) + 1;
      mockAdmins.add(AdminUser(id, loginId, name, _newRole));
      logActivity(ActivityKind.admin, '$name($loginId) 계정 추가 · ${_newRole.label}');
      _name.clear();
      _loginId.clear();
    });
    showMessage(context, '계정을 추가했습니다.');
  }

  void _changeRole(AdminUser a, AdminRole role) {
    setState(() {
      a.role = role;
      logActivity(ActivityKind.admin, '${a.name} 권한 변경 → ${role.label}');
    });
  }

  Future<void> _toggleActive(AdminUser a) async {
    final ok = await showConfirmDialog(
      context,
      title: a.active ? '계정 사용 중지' : '계정 다시 사용',
      message: a.active ? '${a.name} 계정으로 더 이상 로그인할 수 없게 합니다.' : '${a.name} 계정을 다시 사용할 수 있게 합니다.',
      confirmText: a.active ? '사용 중지' : '다시 사용',
      destructive: a.active,
    );
    if (!ok || !mounted) return;
    setState(() {
      a.active = !a.active;
      logActivity(ActivityKind.admin, '${a.name} 계정 ${a.active ? '다시 사용' : '사용 중지'}');
    });
  }

  void _resetPassword(AdminUser a) {
    logActivity(ActivityKind.admin, '${a.name} 비밀번호 초기화');
    setState(() {});
    showMessage(context, '비밀번호를 초기화했습니다.');
  }

  List<Widget> _activityView() {
    final kinds = <ActivityKind?>[null, ...ActivityKind.values];
    final list = _activities;
    return [
      FilterBar(
        hint: '관리자·회원·내용 검색',
        filters: [for (final k in kinds) k?.label ?? '전체'],
        selectedIndex: kinds.indexOf(_kind),
        onFilterSelected: (i) => setState(() => _kind = kinds[i]),
        onSearchChanged: (v) => setState(() => _query = v),
      ),
      AdminTable(
        columns: const ['시각', '처리자', '구분', '대상 회원', '내용'],
        emptyText: '조건에 맞는 기록이 없습니다.',
        rows: [
          for (final a in list.take(_activityLimit))
            [
              Text(formatDateTime(a.at, seconds: true)),
              Text(a.adminName),
              StatusBadge(a.kind.label, color: AppColors.textSecondary),
              Text(a.target.isEmpty ? '-' : a.target),
              Text(a.text),
            ],
        ],
      ),
      if (list.length > _activityLimit)
        Text('최근 $_activityLimit건만 표시합니다.', style: const TextStyle(color: AppColors.textTertiary)),
    ];
  }

  List<Widget> _accountView() {
    final me = signedInAdmin.value;
    return [
      Panel(
        title: '계정 추가',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: '이름'),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _loginId,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: '아이디'),
              ),
            ),
            DropdownButton<AdminRole>(
              value: _newRole,
              items: [for (final r in AdminRole.values) DropdownMenuItem(value: r, child: Text(r.label))],
              onChanged: (r) => setState(() => _newRole = r ?? _newRole),
            ),
            FilledButton(
              onPressed: _name.text.trim().isEmpty || _loginId.text.trim().isEmpty ? null : _addAdmin,
              child: const Text('추가'),
            ),
          ],
        ),
      ),
      AdminTable(
        columns: const ['이름', '아이디', '권한', '최근 접속', '상태', ''],
        rows: [
          for (final a in mockAdmins)
            [
              Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(a.loginId),
              // 자기 권한을 스스로 낮춰 최고 관리자가 없어지는 일을 막는다.
              identical(a, me)
                  ? Text(a.role.label)
                  : DropdownButton<AdminRole>(
                      value: a.role,
                      underline: const SizedBox.shrink(),
                      items: [for (final r in AdminRole.values) DropdownMenuItem(value: r, child: Text(r.label))],
                      onChanged: (r) {
                        if (r != null) _changeRole(a, r);
                      },
                    ),
              Text(a.lastLoginAt == null ? '-' : formatDateTime(a.lastLoginAt!)),
              StatusBadge(
                a.active ? '사용 중' : '사용 중지',
                color: a.active ? AppColors.success : AppColors.textTertiary,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () => _resetPassword(a), child: const Text('비밀번호 초기화')),
                  if (!identical(a, me))
                    TextButton(onPressed: () => _toggleActive(a), child: Text(a.active ? '사용 중지' : '다시 사용')),
                ],
              ),
            ],
        ],
      ),
      Panel(
        title: '권한별 기능',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in AdminRole.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      TextSpan(text: '${r.label}  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(
                        text: r.permissions.isEmpty
                            ? '조회와 상담 기록만'
                            : r.permissions.map((p) => p.label).join(', '),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final canManage = can(AdminPermission.manageAdmins);
    final accounts = canManage && _showAccounts;
    return AdminPage(
      title: '관리자',
      description: '관리자 활동 기록을 확인합니다. 최고 관리자는 계정과 권한도 관리합니다.',
      children: [
        if (canManage)
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: const Text('활동 기록'),
                selected: !accounts,
                onSelected: (_) => setState(() => _showAccounts = false),
              ),
              ChoiceChip(
                label: const Text('계정 관리'),
                selected: accounts,
                onSelected: (_) => setState(() => _showAccounts = true),
              ),
            ],
          ),
        ...(accounts ? _accountView() : _activityView()),
      ],
    );
  }
}
