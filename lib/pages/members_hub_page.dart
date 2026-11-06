import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_data.dart';
import '../theme.dart';
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
    liveStatus.addListener(_rebuild);
    useLiveData.addListener(_rebuild);
    if (useLiveData.value && liveStatus.value.revision == 0) refreshLiveMembers();
  }

  @override
  void dispose() {
    memberMonitorRequest.removeListener(_onRequest);
    liveStatus.removeListener(_rebuild);
    useLiveData.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _onRequest() {
    if (memberMonitorRequest.value == null) return;
    setState(() => _tab = _Tab.monitor);
  }

  @override
  Widget build(BuildContext context) {
    final live = useLiveData.value;
    final status = liveStatus.value;
    // 전체 회원 포지션과 상담 이력은 테스트 DB 경로가 없다.
    final tabs = live ? const [_Tab.list, _Tab.monitor] : _Tab.values;
    final tab = tabs.contains(_tab) ? _tab : _Tab.list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final t in tabs)
                ChoiceChip(
                  label: Text(t.label),
                  visualDensity: VisualDensity.compact,
                  selected: tab == t,
                  onSelected: (_) => setState(() => _tab = t),
                ),
              if (live)
                IconButton(
                  tooltip: '다시 불러오기',
                  visualDensity: VisualDensity.compact,
                  onPressed: status.loading ? null : refreshLiveMembers,
                  icon: const Icon(Icons.refresh, size: 20),
                ),
            ],
          ),
        ),
        if (live && status.loading)
          const Padding(padding: EdgeInsets.fromLTRB(24, 8, 24, 0), child: LinearProgressIndicator()),
        if (live && status.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text('${status.error} API 서버가 실행 중인지 확인하세요.', style: const TextStyle(color: AppColors.up)),
          ),
        Expanded(
          child: KeyedSubtree(
            // 모니터링은 보던 워커·잡을 유지해야 하므로 새로 만들지 않고 스스로 다시 받는다.
            key: ValueKey((live, tab == _Tab.monitor ? 0 : status.revision)),
            child: switch (tab) {
              _Tab.list => const MembersPage(),
              _Tab.monitor => const MemberMonitorPage(),
              _Tab.positions => const MemberPositionsPage(),
              _Tab.consultations => const ConsultationsPage(),
            },
          ),
        ),
      ],
    );
  }
}
