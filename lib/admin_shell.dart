import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'live_admin.dart';
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

/// 메뉴를 볼 수 있는지는 최고 관리자가 등급별로 고른다(roleScreens).
class _Menu {
  const _Menu(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

const _menus = [
  _Menu('대시보드', Icons.space_dashboard_outlined, DashboardHubPage()),
  _Menu('회원 관리', Icons.people_outline, MembersHubPage()),
  _Menu('종목 마스터', Icons.schedule, SymbolMasterPage()),
  _Menu('푸시 알림', Icons.notifications_outlined, PushPage()),
  _Menu('공지사항', Icons.campaign_outlined, NoticesPage()),
  _Menu('관리자', Icons.admin_panel_settings_outlined, AdminUsersPage()),
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
      if (canSee(m.label)) m,
  ];

  /// 최고 관리자가 화면 보기를 바꾸면 메뉴를 다시 그리고, 못 보게 된 탭은 닫는다.
  void _screensChanged() => setState(() {
    final visible = {for (final m in _visible) m.label};
    _open.removeWhere((l) => !visible.contains(l));
    if (_open.isEmpty) _open.add(_visible.first.label);
    if (!_open.contains(_current)) _current = _open.first;
  });

  void _select(_Menu m) => _show(m.label);

  /// 다른 화면으로 가면 상태줄의 조회 결과는 그 화면 것이 아니므로 지운다.
  void _show(String label) => setState(() {
    if (!_open.contains(label)) _open.add(label);
    if (_current != label) adminStatus.value = '준비되었습니다.';
    _current = label;
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
    roleScreens.addListener(_screensChanged);
    if (useLiveData.value) loadLiveRoleScreens(); // 서버에 저장된 등급별 화면
    _open.add(_visible.first.label);
    _current = _open.first;
  }

  @override
  void dispose() {
    memberMonitorRequest.removeListener(_openMonitor);
    pushTargetRequest.removeListener(_openPush);
    liveStatus.removeListener(_reportMembers);
    roleScreens.removeListener(_screensChanged);
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
            onSelect: _show,
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
    // 좁은 화면에서 메뉴가 옆으로 숨지 않게 다음 줄로 넘긴다.
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page, vertical: 10),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 28),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: AssetImage('assets/admin_icon.png'), width: 24, height: 24),
                SizedBox(width: 8),
                Text('던전우상향', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(width: 6),
                Text('관리자', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              ],
            ),
          ),
          for (final m in menus)
            AdminMenuItem(label: m.label, icon: m.icon, selected: m.label == current, onTap: () => onSelect(m)),
        ],
      ),
    );
  }
}

/// 위쪽 메뉴 한 칸: 아이콘 + 이름.
class AdminMenuItem extends StatefulWidget {
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
  State<AdminMenuItem> createState() => _AdminMenuItemState();
}

class _AdminMenuItemState extends State<AdminMenuItem> {
  bool _focused = false; // 키보드로 와 있는가

  @override
  Widget build(BuildContext context) {
    final AdminMenuItem(:label, :icon, :selected, :onTap) = widget;
    // 선택은 한 단계 올라온 면과 강조색 아이콘으로 보인다.
    // 키보드 위치는 선택과 헷갈리지 않게 바탕이 아니라 강조색 테두리로 보인다.
    return Material(
      color: selected ? AppColors.strip : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onTap,
        onFocusChange: (v) => setState(() => _focused = v),
        borderRadius: BorderRadius.circular(AppRadius.control),
        hoverColor: AppColors.surfaceSoft,
        focusColor: Colors.transparent,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: _focused ? AppColors.brand : Colors.transparent, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.brand : AppColors.textTertiary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.only(left: AppSpace.page - 4),
      height: 36,
      child: ReorderableListView(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        onReorderItem: onMove,
        children: [
          for (final (i, t) in tabs.indexed)
            ReorderableDragStartListener(
              key: ValueKey(t),
              index: i,
              // 끌기 대신 키보드로도 순서를 바꾼다: 탭에 와서 Alt + ← / →.
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
                    if (i > 0) onMove(i, i - 1);
                  },
                  const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () {
                    if (i < tabs.length - 1) onMove(i, i + 1);
                  },
                },
                child: Material(
                  color: t == current ? AppColors.surface : Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelect(t),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: const BorderSide(color: AppColors.border),
                          bottom: BorderSide(color: t == current ? AppColors.brand : Colors.transparent, width: 2),
                        ),
                      ),
                      padding: EdgeInsets.only(left: 12, right: closable ? 4 : 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            hint: 'Alt + 왼쪽·오른쪽 화살표로 순서 바꾸기',
                            child: Tooltip(
                              message: '끌거나 Alt + ← / → 로 순서를 바꿉니다',
                              excludeFromSemantics: true,
                              waitDuration: const Duration(seconds: 1),
                              child: Text(
                                t,
                                style: TextStyle(
                                  color: t == current ? AppColors.textPrimary : AppColors.textTertiary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          if (closable)
                            IconButton(
                              tooltip: '$t 닫기',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
    const small = TextStyle(color: AppColors.textTertiary, fontSize: 12);
    final admin = signedInAdmin.value;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: adminStatus,
              builder: (context, text, _) => Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 800)
            Text(useLiveData.value ? '테스트 DB 조회 · 공지·등급별 화면은 목업 API' : '샘플 데이터', style: small),
          if (admin != null) ...[
            const SizedBox(width: 16),
            Text('${admin.name} · ${admin.role.label}', style: small.copyWith(color: AppColors.textSecondary)),
            IconButton(
              tooltip: '로그아웃',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: liveSignOut,
              icon: const Icon(Icons.logout, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}
