import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_admin.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

/// 테스트 DB 회원의 로그인·기기 이력과 관리자 열람 기록. 패널을 펼칠 때 받는다.
class LiveMemberAccessPanels extends StatelessWidget {
  const LiveMemberAccessPanels(this.member, {super.key});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final base = '/members/${member.liveId}';
    String time(Object? v) => liveTime(v) == null ? '-' : formatDateTime(liveTime(v)!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LivePagedPanel(
          key: ValueKey('sessions-${member.id}'),
          title: '로그인 이력',
          path: '$base/sessions',
          note: '앱 로그인 때 발급된 토큰 기준입니다. 기기·IP 는 서버가 기록하지 않아 비어 있습니다.',
          columns: const ['로그인', '만료', '상태'],
          row: (r) => [
            Text(time(r['issuedAt'])),
            Text(time(r['expiresAt'])),
            StatusBadge(
              r['status'] == 'active' ? '사용 중' : '만료',
              color: r['status'] == 'active' ? AppColors.success : AppColors.textTertiary,
            ),
          ],
          emptyText: '로그인 기록이 없습니다.',
          memberLiveId: member.liveId,
        ),
        const SizedBox(height: 8),
        _LivePagedPanel(
          key: ValueKey('devices-${member.id}'),
          title: '기기',
          path: '$base/devices',
          note: '푸시를 받는 기기입니다.',
          columns: const ['기기', '등록', '최근 갱신'],
          row: (r) => [Text(r['device'] as String? ?? '-'), Text(time(r['registeredAt'])), Text(time(r['updatedAt']))],
          emptyText: '등록된 기기가 없습니다. 푸시를 받을 수 없습니다.',
          memberLiveId: member.liveId,
        ),
        if (can(AdminPermission.viewActivity)) ...[
          const SizedBox(height: 8),
          _LivePagedPanel(
            key: ValueKey('views-${member.id}'),
            title: '관리자 열람 기록',
            path: '$base/view-logs',
            note: '이 회원 정보를 본 관리자입니다. 지금은 API 메모리에만 있어 API 를 다시 켜면 사라집니다.',
            columns: const ['시각', '관리자', '내용'],
            row: (r) => [
              Text(time(r['at'])),
              Text(r['adminName'] as String? ?? '-'),
              Text(r['text'] as String? ?? '-'),
            ],
            emptyText: '열람 기록이 없습니다.',
            memberLiveId: member.liveId,
          ),
        ],
      ],
    );
  }
}

/// 펼치면 첫 쪽을 받고, 더 있으면 "더 보기" 로 이어 받는다.
class _LivePagedPanel extends StatefulWidget {
  const _LivePagedPanel({
    super.key,
    required this.title,
    required this.path,
    required this.note,
    required this.columns,
    required this.row,
    required this.emptyText,
    required this.memberLiveId,
  });

  final String title;
  final String path;
  final String note;
  final List<String> columns;
  final List<Widget> Function(Map<String, dynamic>) row;
  final String emptyText;
  final String? memberLiveId;

  @override
  State<_LivePagedPanel> createState() => _LivePagedPanelState();
}

class _LivePagedPanelState extends State<_LivePagedPanel> {
  static const _pageSize = 20;
  bool _open = false;
  bool _loading = false;
  String? _error;
  final _rows = <Map<String, dynamic>>[];
  int _page = 0;
  int _total = 0;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await liveGet('${widget.path}?page=${_page + 1}&pageSize=$_pageSize') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _rows.addAll((body['items'] as List).cast<Map<String, dynamic>>());
        _page++;
        _total = body['total'] as int? ?? _rows.length;
      });
    } on LiveApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open && _page == 0 && !_loading) _load();
  }

  @override
  Widget build(BuildContext context) {
    final head = Row(
      children: [
        Expanded(
          child: Text(widget.note, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ),
        TextButton(onPressed: _toggle, child: Text(_open ? '접기' : '보기')),
      ],
    );
    return Panel(
      title: _page == 0 ? widget.title : '${widget.title} $_total건',
      child: !_open
          ? head
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                head,
                const SizedBox(height: 8),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: AppColors.up))
                else if (_page > 0)
                  AdminTable(
                    exportName: widget.title.replaceAll(' ', '_'),
                    exportMemberLiveId: widget.memberLiveId,
                    columns: widget.columns,
                    emptyText: widget.emptyText,
                    rows: [for (final r in _rows) widget.row(r)],
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  )
                else if (_error == null && _rows.length < _total)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: _load, child: Text('더 보기 (${_rows.length}/$_total)')),
                  ),
              ],
            ),
    );
  }
}
