import 'package:flutter/material.dart';

import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'member_actions.dart';
import 'member_detail_dialog.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  static const _pageSize = 10;

  String _query = '';
  MemberStatus? _status; // null 이면 전체
  int _page = 0;
  final _selectedIds = <int>{};

  List<Member> get _filtered {
    final q = _query.trim().toLowerCase();
    return [
      for (final m in mockMembers)
        if ((_status == null || m.status == _status) &&
            (q.isEmpty || m.username.toLowerCase().contains(q) || m.email.toLowerCase().contains(q)))
          m,
    ];
  }

  int _count(MemberStatus? s) => s == null ? mockMembers.length : mockMembers.where((m) => m.status == s).length;

  void _setFilter(MemberStatus? s) => setState(() {
        _status = s;
        _page = 0;
        _selectedIds.clear();
      });

  Future<void> _bulk({required bool approve}) async {
    final targets = mockMembers.where((m) => _selectedIds.contains(m.id)).toList();
    final ok = await showConfirmDialog(
      context,
      title: approve ? '가입 승인' : '가입 거절',
      message: approve
          ? '선택한 ${targets.length}명의 가입을 승인합니다.'
          : '선택한 ${targets.length}명의 가입을 거절합니다. 거절한 가입 정보는 삭제됩니다.',
      confirmText: approve ? '승인' : '거절',
      destructive: !approve,
    );
    if (!ok || !mounted) return;
    setState(() {
      for (final m in targets) {
        approve ? approveMember(m) : rejectMember(m);
      }
      _selectedIds.clear();
    });
    showMessage(context, '${targets.length}명을 ${approve ? '승인' : '거절'}했습니다.');
  }

  Future<void> _openDetail(Member m) async {
    await showMemberDetail(context, m);
    if (mounted) setState(() => _selectedIds.removeWhere((id) => !mockMembers.any((m) => m.id == id)));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pageCount = (filtered.length / _pageSize).ceil().clamp(1, 1 << 30);
    final page = _page.clamp(0, pageCount - 1);
    final visible = filtered.skip(page * _pageSize).take(_pageSize).toList();
    final pending = _count(MemberStatus.pending);
    final selectable = _status == MemberStatus.pending;
    final statuses = <MemberStatus?>[null, ...MemberStatus.values];

    return AdminPage(
      title: '회원 관리',
      description: '가입 회원을 조회하고 승인·정지·탈퇴를 처리합니다.',
      actions: [
        OutlinedButton.icon(
          onPressed: () => showNotConnected(context),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('엑셀 내보내기'),
        ),
      ],
      children: [
        if (pending > 0 && !selectable)
          _PendingBanner(count: pending, onTap: () => _setFilter(MemberStatus.pending)),
        FilterBar(
          hint: '아이디·이메일 검색',
          filters: [for (final s in statuses) '${s?.label ?? '전체'} ${_count(s)}'],
          selectedIndex: statuses.indexOf(_status),
          onFilterSelected: (i) => _setFilter(statuses[i]),
          onSearchChanged: (v) => setState(() {
            _query = v;
            _page = 0;
          }),
        ),
        if (selectable)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${_selectedIds.length}명 선택됨', style: const TextStyle(color: AppColors.textTertiary)),
              FilledButton.icon(
                onPressed: _selectedIds.isEmpty ? null : () => _bulk(approve: true),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('선택 승인'),
              ),
              OutlinedButton.icon(
                onPressed: _selectedIds.isEmpty ? null : () => _bulk(approve: false),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('선택 거절'),
              ),
            ],
          ),
        AdminTable(
          columns: const ['번호', '아이디', '이메일', '가입일', '최근 접속', '상태', ''],
          emptyText: '조건에 맞는 회원이 없습니다.',
          selected: selectable
              ? {for (final (i, m) in visible.indexed) if (_selectedIds.contains(m.id)) i}
              : null,
          onSelectChanged: (i, v) => setState(() => v ? _selectedIds.add(visible[i].id) : _selectedIds.remove(visible[i].id)),
          onSelectAll: (v) => setState(() {
            for (final m in visible) {
              v ? _selectedIds.add(m.id) : _selectedIds.remove(m.id);
            }
          }),
          rows: [
            for (final m in visible)
              [
                Text('${m.id}'),
                InkWell(
                  onTap: () => _openDetail(m),
                  child: Text(m.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(maskEmail(m.email)),
                Text(formatDateTime(m.joinedAt)),
                Text(m.lastLoginAt == null ? '-' : formatDateTime(m.lastLoginAt!)),
                StatusBadge(m.status.label, color: memberStatusColor(m.status)),
                TextButton(onPressed: () => _openDetail(m), child: const Text('상세')),
              ],
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('총 ${filtered.length}명 · ${page + 1} / $pageCount',
                style: const TextStyle(color: AppColors.textTertiary)),
            IconButton(
              tooltip: '이전 페이지',
              onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: '다음 페이지',
              onPressed: page < pageCount - 1 ? () => setState(() => _page = page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

Color memberStatusColor(MemberStatus s) => switch (s) {
      MemberStatus.pending => AppColors.accent,
      MemberStatus.active => AppColors.success,
      MemberStatus.dormant => AppColors.textTertiary,
      MemberStatus.suspended => AppColors.up,
      MemberStatus.deleteRequested => AppColors.warning,
    };

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.how_to_reg_outlined, color: AppColors.accent),
          Text('가입 승인을 기다리는 회원이 $count명 있습니다.',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          TextButton(onPressed: onTap, child: const Text('승인 대기 보기')),
        ],
      ),
    );
  }
}
