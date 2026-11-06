import 'package:flutter/material.dart';

import 'live_api.dart';
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
import 'widgets/admin_page.dart';

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

/// 위쪽 메뉴 + 열린 화면 탭 + 본문 + 상태줄. 열어 둔 화면은 탭을 옮겨도 보던 자리를 유지한다.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _open = <String>[]; // 열린 화면의 메뉴 이름
  final _revision = <String, int>{}; // 다른 화면의 요청으로 새로 열 때 올린다
  String? _current;

  /// 지금 관리자에게 보이는 메뉴.
  List<_Menu> get _visible => [
    for (final m in _menus)
      if (m.permission == null || can(m.permission!)) m,
  ];

  void _select(_Menu m) => setState(() {
    if (!_open.contains(m.label)) _open.add(m.label);
    _current = m.label;
  });

  /// 탭을 닫는다. 마지막 탭까지 닫으면 기본 화면인 대시보드로 돌아간다.
  void _close(String label) => setState(() {
    final at = _open.indexOf(label);
    _open.removeAt(at);
    if (_open.isEmpty) _open.add(_visible.first.label);
    if (_current == label) _current = _open[at.clamp(0, _open.length - 1)];
  });

  void _move(int from, int to) => setState(() {
    _open.insert(to, _open.removeAt(from));
  });

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
    liveStatus.addListener(_reportMembers);
    _open.add(_visible.first.label);
    _current = _open.first;
  }

  @override
  void dispose() {
    memberMonitorRequest.removeListener(_openMonitor);
    pushTargetRequest.removeListener(_openPush);
    liveStatus.removeListener(_reportMembers);
    super.dispose();
  }

  /// 요청은 화면을 만들 때 읽으므로 열려 있던 화면도 새로 만든다.
  void _reopen(bool Function(_Menu) match) {
    final menu = _visible.where(match).firstOrNull;
    if (menu == null) return;
    _revision.update(menu.label, (v) => v + 1, ifAbsent: () => 1);
    _select(menu);
  }

  void _openMonitor() {
    if (memberMonitorRequest.value != null) _reopen((m) => m.page is MembersHubPage);
  }

  void _openPush() {
    if (pushTargetRequest.value != null) _reopen((m) => m.page is PushPage);
  }

  void _reportMembers() {
    final s = liveStatus.value;
    adminStatus.value = s.loading
        ? '조회 중입니다.'
        : s.error != null
        ? '조회하지 못했습니다. ${s.error}'
        : '조회가 완료되었습니다(회원 ${liveMembers.length}건).';
  }

  @override
  Widget build(BuildContext context) {
    final menus = _visible;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MenuBar(menus: menus, current: _current, onSelect: _select),
          _OpenTabs(
            tabs: _open,
            current: _current,
            // 대시보드 하나만 남으면 닫아도 다시 대시보드라 닫는 단추를 두지 않는다.
            closable: _open.length > 1 || _open.single != menus.first.label,
            onSelect: (t) => setState(() => _current = t),
            onClose: _close,
            onMove: _move,
          ),
          Expanded(
            child: IndexedStack(
              index: _open.indexOf(_current!),
              children: [
                for (final label in _open)
                  // 웹은 기본으로 글자를 고를 수 없어 본문 전체를 복사할 수 있게 연다.
                  SelectionArea(
                    key: ValueKey((label, _revision[label] ?? 0)),
                    child: _shown(menus.firstWhere((m) => m.label == label).page),
                  ),
              ],
            ),
          ),
          const _StatusBar(),
        ],
      ),
    );
  }
}

class _MenuBar extends StatelessWidget {
  const _MenuBar({required this.menus, required this.current, required this.onSelect});

  final List<_Menu> menus;
  final String? current;
  final ValueChanged<_Menu> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.strip,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Image.asset('assets/admin_icon.png', width: 28, height: 28),
            const SizedBox(width: 8),
            const Text('던전우상향', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            const Text(
              '관리자',
              style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 20),
            for (final m in menus)
              AdminMenuItem(label: m.label, icon: m.icon, selected: m.label == current, onTap: () => onSelect(m)),
          ],
        ),
      ),
    );
  }
}

/// 위쪽 메뉴 한 칸: 아이콘 + 이름.
class AdminMenuItem extends StatelessWidget {
  const AdminMenuItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brand : AppColors.textSecondary;
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 84,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 열린 화면 탭. 끌어서 순서를 바꾼다.
class _OpenTabs extends StatelessWidget {
  const _OpenTabs({
    required this.tabs,
    required this.current,
    required this.closable,
    required this.onSelect,
    required this.onClose,
    required this.onMove,
  });

  final List<String> tabs;
  final String? current;
  final bool closable;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;
  final void Function(int from, int to) onMove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.only(left: 8),
      height: 30,
      child: ReorderableListView(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        onReorderItem: onMove,
        children: [
          for (final (i, t) in tabs.indexed)
            ReorderableDragStartListener(
              key: ValueKey(t),
              index: i,
              child: Material(
                color: t == current ? AppColors.surface : Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(t),
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: AppColors.grid)),
                    ),
                    padding: EdgeInsets.only(left: 12, right: closable ? 4 : 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t,
                          style: TextStyle(
                            color: t == current ? AppColors.brand : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (closable)
                          IconButton(
                            tooltip: '$t 닫기',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                            iconSize: 14,
                            onPressed: () => onClose(t),
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 맨 아래 줄: 조회 결과, 데이터 출처, 관리자, 로그아웃.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(color: AppColors.textSecondary, fontSize: 12);
    final admin = signedInAdmin.value;
    return Container(
      color: AppColors.strip,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: adminStatus,
              builder: (context, text, _) => Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 800)
            Text(useLiveData.value ? '테스트 DB 조회 · 공지·관리자는 샘플' : '샘플 데이터', style: small),
          if (admin != null) ...[
            const SizedBox(width: 16),
            Text('${admin.name} · ${admin.role.label}', style: small.copyWith(fontWeight: FontWeight.w700)),
            IconButton(
              tooltip: '로그아웃',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: signOut,
              icon: const Icon(Icons.logout, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}
