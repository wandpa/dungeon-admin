import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_data.dart' show formatDateTime;
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'live_view.dart';

const _pageSize = 20;

/// 앱이 회원에게 보낸 알림 내역. 관리자 푸시 발송 이력이 아니라서 발송 수와 열람률은 없다.
class LiveNotificationsPage extends StatefulWidget {
  const LiveNotificationsPage({super.key});

  @override
  State<LiveNotificationsPage> createState() => _LiveNotificationsPageState();
}

class _LiveNotificationsPageState extends State<LiveNotificationsPage> {
  final _debounce = SearchDebounce();
  String _query = '';
  int _page = 1;

  @override
  void dispose() {
    _debounce.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() => liveNotifications(_query, page: _page, pageSize: _pageSize);

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: '푸시 알림',
      description: '회원이 받은 알림을 조회합니다. 테스트 DB 에서는 발송할 수 없습니다.',
      children: [
        FilterBar(
          hint: '아이디·내용 검색',
          onSearchChanged: (v) => _debounce(() {
            if (mounted) {
              setState(() {
                _query = v;
                _page = 1;
              });
            }
          }),
        ),
        LiveLoader<Map<String, dynamic>>(
          key: ValueKey((_query, _page)),
          load: _load,
          builder: (context, body) {
            final rows = (body['items'] as List).cast<Map<String, dynamic>>();
            final counts = body['counts'] as Map<String, dynamic>? ?? const {};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _query.trim().isEmpty
                      ? '전체 ${counts['all'] ?? '-'}건 · 안 읽음 ${counts['unread'] ?? '-'}건'
                      : '검색 결과 ${body['total'] ?? '-'}건',
                  style: const TextStyle(color: AppColors.textTertiary),
                ),
                const SizedBox(height: 8),
                AdminTable(
                  columns: const ['보낸 시각', '회원', '제목', '내용', '읽음'],
                  emptyText: '알림이 없습니다.',
                  rows: [
                    for (final n in rows)
                      [
                        Text(formatDateTime(liveTime(n['sentAt'])!)),
                        Text(n['username'] as String? ?? '-'),
                        Text(n['title'] as String? ?? '-'),
                        SizedBox(width: 560, child: Text(n['body'] as String? ?? '-')),
                        Text(n['isRead'] == true ? '읽음' : '안 읽음'),
                      ],
                  ],
                ),
                LivePager(
                  total: body['total'] as int? ?? 0,
                  page: _page,
                  pageSize: _pageSize,
                  onPage: (p) => setState(() => _page = p),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
