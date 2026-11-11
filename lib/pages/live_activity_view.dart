import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'live_view.dart';

/// 서버가 남긴 관리자 활동 기록. 지금은 API 메모리에 있어 API 를 다시 켜면 사라진다.
class LiveActivityView extends StatefulWidget {
  const LiveActivityView({super.key});

  @override
  State<LiveActivityView> createState() => _LiveActivityViewState();
}

const _kinds = {
  'access': '접속',
  'view': '열람',
  'member': '회원 처리',
  'consult': '상담',
  'push': '푸시',
  'notice': '공지',
  'signal': '신호',
  'system': '시스템',
  'symbol': '종목',
  'admin': '계정',
};

class _LiveActivityViewState extends State<LiveActivityView> {
  static const _pageSize = 20;

  String _query = '';
  String? _kind;
  int? _adminId;
  DateTimeRange? _range;
  int _page = 0;
  List<Map<String, dynamic>> _admins = const [];

  @override
  void initState() {
    super.initState();
    adminGet('/admins/names').then((body) {
      if (mounted) setState(() => _admins = ((body as Map)['items'] as List).cast<Map<String, dynamic>>());
    }, onError: (_) {});
  }

  void _filter(VoidCallback change) => setState(() {
    change();
    _page = 0;
  });

  Future<Map<String, dynamic>> _load() async {
    final r = _range;
    final q = [
      'page=${_page + 1}',
      'pageSize=$_pageSize',
      'sample=false', // 미리 넣어 둔 샘플 기록은 뺀다
      if (_query.trim().isNotEmpty) 'q=${Uri.encodeQueryComponent(_query.trim())}',
      if (_kind != null) 'kind=$_kind',
      if (_adminId != null) 'adminId=$_adminId',
      if (r != null) 'from=${Uri.encodeQueryComponent(r.start.toUtc().toIso8601String())}',
      if (r != null) 'to=${Uri.encodeQueryComponent(r.end.add(const Duration(days: 1)).toUtc().toIso8601String())}',
    ];
    return await adminGet('/activities?${q.join('&')}') as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final kinds = <String?>[null, ..._kinds.keys];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterBar(
          hint: '관리자·회원·내용 검색',
          filters: [for (final k in kinds) k == null ? '전체' : _kinds[k]!],
          selectedIndex: kinds.indexOf(_kind),
          onFilterSelected: (i) => _filter(() => _kind = kinds[i]),
          onSearchChanged: (v) => _filter(() => _query = v),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<int?>(
              value: _adminId,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<int?>(child: Text('전체 처리자')),
                for (final a in _admins) DropdownMenuItem<int?>(value: a['id'] as int, child: Text('${a['name']}')),
              ],
              onChanged: (v) => _filter(() => _adminId = v),
            ),
            DateRangeFilter(range: _range, onChanged: (r) => _filter(() => _range = r)),
            const Text(
              '서버가 남긴 기록입니다. 아직 DB 에 저장하지 않아 API 를 다시 켜면 사라집니다 (C-6).',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LiveLoader<Map<String, dynamic>>(
          key: ValueKey((_query, _kind, _adminId, _range, _page)),
          load: _load,
          builder: (context, body) {
            final rows = (body['items'] as List).cast<Map<String, dynamic>>();
            final total = body['total'] as int? ?? rows.length;
            final pageCount = (total / _pageSize).ceil().clamp(1, 1 << 30);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminTable(
                  exportName: '활동_기록',
                  columns: const ['시각', '처리자', '구분', '대상 회원', '내용'],
                  emptyText: '조건에 맞는 기록이 없습니다.',
                  rows: [
                    for (final a in rows)
                      [
                        Text(liveTime(a['at']) == null ? '-' : formatDateTime(liveTime(a['at'])!, seconds: true)),
                        Text('${a['adminName'] ?? '-'}'),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusBadge(_kinds[a['kind']] ?? '${a['kind']}', color: AppColors.textSecondary),
                            if (a['sample'] == true) ...[
                              const SizedBox(width: 4),
                              const StatusBadge('샘플', color: AppColors.textTertiary),
                            ],
                          ],
                        ),
                        Text('${a['memberUsername'] ?? '-'}'),
                        SizedBox(width: 520, child: Text('${a['text'] ?? ''}')),
                      ],
                  ],
                ),
                Pager(
                  page: _page.clamp(0, pageCount - 1),
                  pageCount: pageCount,
                  summary: '총 ${formatNumber(total)}건',
                  onChanged: (p) => setState(() => _page = p),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
