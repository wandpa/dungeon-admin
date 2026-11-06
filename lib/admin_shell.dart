import 'package:flutter/material.dart';

import 'mock_admin.dart';
import 'mock_data.dart';
import 'pages/admin_users_page.dart';
import 'pages/dashboard_hub_page.dart';
import 'pages/live_notifications_page.dart';
import 'pages/live_symbol_page.dart';
import 'pages/member_monitor_page.dart';
import 'pages/members_hub_page.dart';
import 'pages/notices_page.dart';
import 'pages/push_page.dart';
import 'pages/symbol_master_page.dart';
import 'theme.dart';

class _Menu {
  const _Menu(this.label, this.icon, this.page, {this.permission});
  final String label;
  final IconData icon;
  final Widget page;
  final AdminPermission? permission; // 비어 있으면 모두에게 보인다
}

const _menus = [
  _Menu('대시보드', Icons.space_dashboard_outlined, DashboardHubPage()),
  _Menu('회원 관리', Icons.people_outline, MembersHubPage()),
  _Menu('종목 마스터', Icons.schedule, SymbolMasterPage()),
  _Menu('푸시 알림', Icons.notifications_outlined, PushPage()),
  _Menu('공지사항', Icons.campaign_outlined, NoticesPage()),
  _Menu('관리자', Icons.admin_panel_settings_outlined, AdminUsersPage(), permission: AdminPermission.viewActivity),
];

/// 왼쪽 메뉴 + 본문. 화면이 좁으면 메뉴가 서랍(Drawer)으로 바뀐다.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  /// 지금 관리자에게 보이는 메뉴.
  List<_Menu> get _visible => [
    for (final m in _menus)
      if (m.permission == null || can(m.permission!)) m,
  ];

  void _select(int i) => setState(() => _index = i);

  /// 테스트 DB 를 볼 때는 조회 전용 화면으로 바꾼다.
  Widget _shown(Widget page) {
    if (!useLiveData.value) return page;
    return switch (page) {
      SymbolMasterPage() => const LiveSymbolPage(),
      PushPage() => const LiveNotificationsPage(),
      _ => page,
    };
  }

  @override
  void initState() {
    super.initState();
    memberMonitorRequest.addListener(_openMonitor);
    pushTargetRequest.addListener(_openPush);
  }

  @override
  void dispose() {
    memberMonitorRequest.removeListener(_openMonitor);
    pushTargetRequest.removeListener(_openPush);
    super.dispose();
  }

  /// 다른 화면의 요청으로 메뉴를 옮긴다. 대상은 열린 화면이 요청값을 읽어 고른다.
  void _openMonitor() {
    if (memberMonitorRequest.value == null) return;
    _select(_visible.indexWhere((m) => m.page is MembersHubPage));
  }

  void _openPush() {
    if (pushTargetRequest.value == null) return;
    _select(_visible.indexWhere((m) => m.page is PushPage));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final menus = _visible;
    final index = _index.clamp(0, menus.length - 1);
    final sidebar = _Sidebar(
      menus: menus,
      selected: index,
      onSelect: (i) {
        _select(i);
        if (!wide) Navigator.of(context).pop();
      },
    );

    return Scaffold(
      appBar: wide ? null : AppBar(backgroundColor: AppColors.surfaceSoft, title: Text(menus[index].label)),
      drawer: wide ? null : Drawer(backgroundColor: AppColors.surfaceSoft, child: sidebar),
      body: Row(
        children: [
          if (wide) SizedBox(width: 232, child: sidebar),
          // 웹은 기본으로 글자를 고를 수 없어 본문 전체를 복사할 수 있게 연다.
          Expanded(child: SelectionArea(child: _shown(menus[index].page))),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.menus, required this.selected, required this.onSelect});

  final List<_Menu> menus;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final admin = signedInAdmin.value;
    // Container 대신 Material 이어야 선택된 메뉴(ListTile) 배경이 보인다.
    return Material(
      color: AppColors.surfaceSoft,
      shape: const Border(right: BorderSide(color: AppColors.border)),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('던전우상향', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('관리자', style: TextStyle(color: AppColors.accent, fontSize: 13)),
                ],
              ),
            ),
            for (final (i, m) in menus.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: ListTile(
                  selected: i == selected,
                  selectedTileColor: AppColors.brand.withValues(alpha: 0.18),
                  selectedColor: AppColors.textPrimary,
                  iconColor: AppColors.textTertiary,
                  textColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: Icon(m.icon),
                  title: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => onSelect(i),
                ),
              ),
            const Spacer(),
            if (admin != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(admin.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(admin.role.label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(tooltip: '로그아웃', onPressed: signOut, icon: const Icon(Icons.logout, size: 20)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Text(
                useLiveData.value ? '테스트 DB 조회 · 공지·관리자는 샘플' : '샘플 데이터',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
