import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_admin.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'live_view.dart';
import 'push_page.dart' show pushTargetRequest;

const _pageSize = 20;

enum _Target {
  all('전체 회원'),
  grade('회원등급'),
  members('회원 선택');

  const _Target(this.label);
  final String label;
}

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
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _search = TextEditingController();
  final _targetIds = <int>{}; // 회원 목록을 다시 받아도 이어지게 번호로 둔다
  final _grades = <String>{};
  _Target _target = _Target.all;

  @override
  void initState() {
    super.initState();
    // 회원 상세의 푸시 보내기로 왔으면 그 회원을 받는 사람으로 골라 둔다.
    final id = pushTargetRequest.value;
    pushTargetRequest.value = null;
    if (id != null) {
      _targetIds.add(id);
      _target = _Target.members;
    }
    ensureLiveMembers().then((_) {
      if (mounted) setState(() {});
    }, onError: (_) {}); // 목록을 못 받으면 아래 표가 오류를 보여 준다
  }

  @override
  void dispose() {
    _debounce.dispose();
    _title.dispose();
    _body.dispose();
    _search.dispose();
    super.dispose();
  }

  Widget _composer() {
    final members = [
      for (final m in currentMembers)
        if (m.status != MemberStatus.pending) m,
    ];
    final targets = [
      for (final m in members)
        if (_targetIds.contains(m.id)) m,
    ];
    final q = _search.text.trim().toLowerCase();
    final found = q.isEmpty
        ? const <Member>[]
        : [
            for (final m in members)
              if (!_targetIds.contains(m.id) &&
                  (m.username.toLowerCase().contains(q) || m.shownEmail.toLowerCase().contains(q)))
                m,
          ].take(5).toList();
    final grades = [
      for (final g in memberGrades)
        if (_grades.contains(g)) g,
    ];
    // 받는 사람을 고르지 않았으면 보낼 수 없다. 마지막 회원을 뺐다고 전체로 나가면 안 된다.
    final receiver = switch (_target) {
      _Target.all => '전체 회원',
      _Target.grade => grades.isEmpty ? null : '${grades.join('·')} 등급',
      _Target.members => switch (targets.length) {
        0 => null,
        1 => targets.single.username,
        final n => '${targets.first.username} 외 ${n - 1}명',
      },
    };
    final ready = receiver != null && _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;
    return Panel(
      title: '새 알림 보내기',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 64,
                child: Text('받는 사람', style: TextStyle(fontWeight: FontWeight.w500)),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in _Target.values)
                    ChoiceChip(
                      label: Text(t.label),
                      visualDensity: VisualDensity.compact,
                      selected: t == _target,
                      onSelected: (_) => setState(() => _target = t),
                    ),
                ],
              ),
            ],
          ),
          if (_target == _Target.grade) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 64),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final g in memberGrades)
                    FilterChip(
                      label: Text(g),
                      visualDensity: VisualDensity.compact,
                      selected: _grades.contains(g),
                      onSelected: (on) => setState(() => on ? _grades.add(g) : _grades.remove(g)),
                    ),
                ],
              ),
            ),
          ],
          if (_target == _Target.members) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 64),
              child: Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: '회원 아이디·이메일 검색',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in targets)
                          InputChip(
                            label: Text(m.username),
                            visualDensity: VisualDensity.compact,
                            onDeleted: () => setState(() => _targetIds.remove(m.id)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (q.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 64, top: 4),
                child: SizedBox(
                  width: 280,
                  child: found.isEmpty
                      ? const Text('찾는 회원이 없습니다.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final m in found)
                              ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                title: Text(m.username, style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text(m.shownEmail, style: const TextStyle(fontSize: 12)),
                                trailing: const Icon(Icons.add, size: 18, color: AppColors.accent),
                                onTap: () => setState(() {
                                  _targetIds.add(m.id);
                                  _search.clear();
                                }),
                              ),
                          ],
                        ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: '제목'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            onChanged: (_) => setState(() {}),
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: '내용'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text('발송 API 연결 전입니다. 지금은 보내지지 않습니다.', style: TextStyle(color: AppColors.warning, fontSize: 12)),
              ),
              FilledButton.icon(
                onPressed: ready ? () => showNotConnected(context) : null,
                icon: const Icon(Icons.send, size: 18),
                label: Text(receiver == null ? '받는 사람을 고르세요' : '$receiver에게 보내기'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _load() => liveNotifications(_query, page: _page, pageSize: _pageSize);

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: '푸시 알림',
      description: '회원에게 알림을 보내고, 회원이 받은 알림을 조회합니다.',
      children: [
        if (can(AdminPermission.sendPush)) _composer(),
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
                  exportName: '알림_발송_내역',
                  columns: const ['보낸 시각', '회원', '제목', '내용', '읽음'],
                  emptyText: '알림이 없습니다.',
                  rows: [
                    for (final n in rows)
                      [
                        Text(formatDateTime(liveTime(n['sentAt'])!)),
                        Text(n['username'] as String? ?? '-'),
                        Text(liveNotificationTitle(n['title'] as String?)),
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
