import 'package:flutter/material.dart';

import '../mock_consultations.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'member_monitor_page.dart' show MonitorRequest, memberMonitorRequest;

Color consultStatusColor(ConsultStatus s) => switch (s) {
  ConsultStatus.open => AppColors.warning,
  ConsultStatus.inProgress => AppColors.accent,
  ConsultStatus.done => AppColors.success,
};

/// 회사 전체 상담 이력. 처리가 안 끝난 상담을 찾고 회원 모니터링으로 넘어간다.
class ConsultationsPage extends StatefulWidget {
  const ConsultationsPage({super.key});

  @override
  State<ConsultationsPage> createState() => _ConsultationsPageState();
}

class _ConsultationsPageState extends State<ConsultationsPage> {
  String _query = '';
  ConsultStatus? _status; // null 이면 전체

  List<Consultation> get _visible {
    final q = _query.trim().toLowerCase();
    return [
      for (final c in mockConsultations)
        if ((_status == null || c.status == _status) &&
            (q.isEmpty ||
                c.username.toLowerCase().contains(q) ||
                c.content.toLowerCase().contains(q) ||
                c.adminName.toLowerCase().contains(q)))
          c,
    ];
  }

  int _count(ConsultStatus? s) =>
      s == null ? mockConsultations.length : mockConsultations.where((c) => c.status == s).length;

  @override
  Widget build(BuildContext context) {
    final statuses = <ConsultStatus?>[null, ...ConsultStatus.values];
    return AdminPage(
      title: '상담 이력',
      description: '회원 상담을 접수 경로·유형·처리 상태별로 확인합니다. 회원을 누르면 회원 모니터링으로 이동합니다.',
      children: [
        FilterBar(
          hint: '회원·내용·담당자 검색',
          filters: [for (final s in statuses) '${s?.label ?? '전체'} ${_count(s)}'],
          selectedIndex: statuses.indexOf(_status),
          onFilterSelected: (i) => setState(() => _status = statuses[i]),
          onSearchChanged: (v) => setState(() => _query = v),
        ),
        AdminTable(
          columns: const ['접수 시각', '회원', '경로', '유형', '내용', '담당', '상태'],
          emptyText: '조건에 맞는 상담이 없습니다.',
          rows: [
            for (final c in _visible)
              [
                Text(formatDateTime(c.at)),
                TextButton(
                  onPressed: () => memberMonitorRequest.value = MonitorRequest(c.memberId),
                  child: Text(c.username),
                ),
                Text(c.channel.label),
                Text(c.type.label),
                SizedBox(
                  width: 300,
                  child: Tooltip(
                    message: c.linkLabel == null ? c.content : '${c.content}\n연결: ${c.linkLabel}',
                    child: Text(c.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
                Text(c.handledBy ?? c.adminName),
                DropdownButton<ConsultStatus>(
                  value: c.status,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final s in ConsultStatus.values)
                      DropdownMenuItem(
                        value: s,
                        child: Text(s.label, style: TextStyle(color: consultStatusColor(s), fontSize: 13)),
                      ),
                  ],
                  onChanged: (s) {
                    if (s != null) setState(() => setConsultStatus(c, s));
                  },
                ),
              ],
          ],
        ),
      ],
    );
  }
}
