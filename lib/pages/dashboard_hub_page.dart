import 'package:flutter/material.dart';

import '../mock_admin.dart';
import '../mock_data.dart';
import '../mock_system.dart';
import 'dashboard_page.dart';
import 'live_system_page.dart';
import 'system_page.dart';

enum _Tab {
  dashboard('회원 현황'),
  system('시스템');

  const _Tab(this.label);
  final String label;
}

/// 대시보드 메뉴. 회원 현황과 시스템을 나눠서 본다.
class DashboardHubPage extends StatefulWidget {
  const DashboardHubPage({super.key});

  @override
  State<DashboardHubPage> createState() => _DashboardHubPageState();
}

class _DashboardHubPageState extends State<DashboardHubPage> {
  _Tab _tab = _Tab.dashboard;

  @override
  void initState() {
    super.initState();
    systemPageRequest.addListener(_onRequest);
  }

  @override
  void dispose() {
    systemPageRequest.removeListener(_onRequest);
    super.dispose();
  }

  void _onRequest() => setState(() => _tab = _Tab.system);

  @override
  Widget build(BuildContext context) {
    // 최고 관리자가 이 등급에게 끈 소화면은 빠진다.
    final tabs = [for (final t in _Tab.values) if (canSee(screenKey(['대시보드', t.label]))) t];
    final tab = tabs.contains(_tab) ? _tab : tabs.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Wrap(
            spacing: 6,
            children: [
              for (final t in tabs)
                ChoiceChip(
                  label: Text(t.label),
                  visualDensity: VisualDensity.compact,
                  selected: tab == t,
                  onSelected: (_) => setState(() => _tab = t),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (tab) {
            _Tab.dashboard => useLiveData.value ? const LiveDashboardPage() : const DashboardPage(),
            _Tab.system => useLiveData.value ? const LiveSystemPage() : const SystemPage(),
          },
        ),
      ],
    );
  }
}
