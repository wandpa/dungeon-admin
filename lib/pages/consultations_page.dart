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
  static const _pageSize = 20;

  String _query = '';
  ConsultStatus? _status; // null 이면 전체
  ConsultChannel? _channel;
  ConsultType? _type;
  DateTimeRange? _range;
  int _page = 0;
  Consultation? _opened; // 내용을 펼쳐 볼 상담

  List<Consultation> get _filtered {
    final q = _query.trim().toLowerCase();
    return [
      for (final c in mockConsultations)
        if ((_status == null || c.status == _status) &&
            (_channel == null || c.channel == _channel) &&
            (_type == null || c.type == _type) &&
            inDateRange(c.at, _range) &&
            (q.isEmpty ||
                c.username.toLowerCase().contains(q) ||
                c.content.toLowerCase().contains(q) ||
                c.adminName.toLowerCase().contains(q)))
          c,
    ];
  }

  int _count(ConsultStatus? s) =>
      s == null ? mockConsultations.length : mockConsultations.where((c) => c.status == s).length;

  /// 필터가 바뀌면 첫 쪽으로 돌아간다.
  void _filter(VoidCallback change) => setState(() {
    change();
    _page = 0;
  });

  Widget _dropdown<T>(String hint, T? value, List<T> values, String Function(T) label, ValueChanged<T?> onChanged) {
    return DropdownButton<T?>(
      value: value,
      hint: Text(hint),
      underline: const SizedBox.shrink(),
      items: [
        DropdownMenuItem<T?>(child: Text(hint)),
        for (final v in values) DropdownMenuItem<T?>(value: v, child: Text(label(v))),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final statuses = <ConsultStatus?>[null, ...ConsultStatus.values];
    final filtered = _filtered;
    final pageCount = (filtered.length / _pageSize).ceil().clamp(1, 1 << 30);
    final page = _page.clamp(0, pageCount - 1);
    final opened = _opened;
    return AdminPage(
      title: '상담 이력',
      description: '회원 상담을 접수 경로·유형·처리 상태별로 확인합니다. 내용을 누르면 전체가 보이고, 회원을 누르면 회원 모니터링으로 이동합니다.',
      children: [
        if (useLiveData.value) const SampleNotice('샘플 상담입니다. 실제 회원의 상담 이력이 아니며, 상담 API 연결 전입니다.'),
        FilterBar(
          hint: '회원·내용·담당자 검색',
          filters: [for (final s in statuses) '${s?.label ?? '전체'} ${_count(s)}'],
          selectedIndex: statuses.indexOf(_status),
          onFilterSelected: (i) => _filter(() => _status = statuses[i]),
          onSearchChanged: (v) => _filter(() => _query = v),
        ),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _dropdown('전체 경로', _channel, ConsultChannel.values, (c) => c.label, (v) => _filter(() => _channel = v)),
            _dropdown('전체 유형', _type, ConsultType.values, (t) => t.label, (v) => _filter(() => _type = v)),
            DateRangeFilter(range: _range, onChanged: (r) => _filter(() => _range = r)),
          ],
        ),
        if (opened != null)
          Panel(
            title: '상담 #${opened.id} · ${opened.username}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(opened.content),
                const SizedBox(height: 8),
                Text(
                  [
                    '${opened.channel.label} · ${opened.type.label}',
                    '접수 ${formatDateTime(opened.at)} ${opened.adminName}',
                    if (opened.handledBy != null) '처리 ${formatDateTime(opened.handledAt!)} ${opened.handledBy}',
                    if (opened.linkLabel != null) '연결 ${opened.linkLabel}',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => setState(() => _opened = null), child: const Text('닫기')),
                ),
              ],
            ),
          ),
        AdminTable(
          columns: const ['접수 시각', '회원', '경로', '유형', '내용', '담당', '상태'],
          emptyText: '조건에 맞는 상담이 없습니다.',
          rows: [
            for (final c in filtered.skip(page * _pageSize).take(_pageSize))
              [
                Text(formatDateTime(c.at)),
                TextButton(
                  onPressed: () => memberMonitorRequest.value = MonitorRequest(c.memberId),
                  child: Text(c.username),
                ),
                Text(c.channel.label),
                Text(c.type.label),
                InkWell(
                  onTap: () => setState(() => _opened = c),
                  child: SizedBox(width: 300, child: Text(c.content, maxLines: 2, overflow: TextOverflow.ellipsis)),
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
        Pager(
          page: page,
          pageCount: pageCount,
          summary: '총 ${filtered.length}건',
          onChanged: (p) => setState(() => _page = p),
        ),
      ],
    );
  }
}
