import 'package:flutter/material.dart';

import 'consultations_page.dart';
import 'member_monitor_page.dart';
import 'member_positions_page.dart';
import 'members_page.dart';

enum _Tab {
  list('회원 목록'),
  monitor('회원 모니터링'),
  positions('회원 포지션'),
  consultations('상담 이력');

  const _Tab(this.label);
  final String label;
}

/// 회원 관리 메뉴. 회원 목록, 모니터링, 전체 회원 포지션, 상담 이력을 한곳에서 본다.
class MembersHubPage extends StatefulWidget {
  const MembersHubPage({super.key});

  @override
  State<MembersHubPage> createState() => _MembersHubPageState();
}

class _MembersHubPageState extends State<MembersHubPage> {
  // 다른 화면에서 회원을 열어 달라고 왔으면 모니터링부터 보여 준다.
  late _Tab _tab = memberMonitorRequest.value != null ? _Tab.monitor : _Tab.list;

  @override
  void initState() {
    super.initState();
    memberMonitorRequest.addListener(_onRequest);
  }

  @override
  void dispose() {
    memberMonitorRequest.removeListener(_onRequest);
    super.dispose();
  }

  void _onRequest() {
    if (memberMonitorRequest.value != null) setState(() => _tab = _Tab.monitor);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Wrap(
            spacing: 6,
            children: [
              for (final t in _Tab.values)
                ChoiceChip(
                  label: Text(t.label),
                  visualDensity: VisualDensity.compact,
                  selected: _tab == t,
                  onSelected: (_) => setState(() => _tab = t),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (_tab) {
            _Tab.list => const MembersPage(),
            _Tab.monitor => const MemberMonitorPage(),
            _Tab.positions => const MemberPositionsPage(),
            _Tab.consultations => const ConsultationsPage(),
          },
        ),
      ],
    );
  }
}
