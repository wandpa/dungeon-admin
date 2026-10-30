import 'package:flutter/material.dart';

import 'pages/dashboard_page.dart';
import 'pages/members_page.dart';
import 'pages/notices_page.dart';
import 'pages/push_page.dart';
import 'pages/signals_page.dart';
import 'theme.dart';

class _Menu {
  const _Menu(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

const _menus = [
  _Menu('대시보드', Icons.space_dashboard_outlined, DashboardPage()),
  _Menu('회원 관리', Icons.people_outline, MembersPage()),
  _Menu('신호 관리', Icons.show_chart, SignalsPage()),
  _Menu('푸시 알림', Icons.notifications_outlined, PushPage()),
  _Menu('공지사항', Icons.campaign_outlined, NoticesPage()),
];

/// 왼쪽 메뉴 + 본문. 화면이 좁으면 메뉴가 서랍(Drawer)으로 바뀐다.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final sidebar = _Sidebar(
      selected: _index,
      onSelect: (i) {
        _select(i);
        if (!wide) Navigator.of(context).pop();
      },
    );

    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: AppColors.surfaceSoft,
              title: Text(_menus[_index].label),
            ),
      drawer: wide ? null : Drawer(backgroundColor: AppColors.surfaceSoft, child: sidebar),
      body: Row(
        children: [
          if (wide) SizedBox(width: 232, child: sidebar),
          Expanded(child: _menus[_index].page),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
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
            for (final (i, m) in _menus.indexed)
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
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '샘플 데이터 · API 연결 전',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
