import 'package:flutter/material.dart';

import '../file_download.dart';
import '../live_api.dart';
import '../mock_admin.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'member_actions.dart';
import 'member_detail_dialog.dart';
import 'member_monitor_page.dart' show MonitorRequest, memberMonitorRequest;

class MembersPage extends StatefulWidget {
  const MembersPage({super.key, this.initialMemberId});

  final int? initialMemberId; // 모니터링에서 돌아올 때 보던 회원

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  static const _pageSize = 10;

  String _query = '';
  MemberStatus? _status; // null 이면 전체
  bool _blockedOnly = false; // 접속 차단은 상태와 따로라 필터도 따로 둔다
  int _page = 0;
  final _selectedIds = <int>{};
  late int? _openId = widget.initialMemberId; // 오른쪽 패널에 보여 주는 회원
  bool _wide = false; // 오른쪽 패널을 둘 자리가 있는지

  List<Member> get _filtered {
    final q = _query.trim().toLowerCase();
    return [
      for (final m in currentMembers)
        if ((_status == null || m.status == _status) &&
            (!_blockedOnly || m.accessBlocked) &&
            (q.isEmpty || m.username.toLowerCase().contains(q) || m.email.toLowerCase().contains(q)))
          m,
    ];
  }

  int _count(MemberStatus? s) => s == null ? currentMembers.length : currentMembers.where((m) => m.status == s).length;

  void _setFilter(MemberStatus? s, {bool blocked = false}) => setState(() {
    _status = s;
    _blockedOnly = blocked;
    _page = 0;
    _selectedIds.clear();
  });

  Future<void> _bulk({required bool approve}) async {
    final targets = mockMembers.where((m) => _selectedIds.contains(m.id)).toList();
    final ok = await showConfirmDialog(
      context,
      title: approve ? '가입 승인' : '가입 거절',
      message: approve ? '선택한 ${targets.length}명의 가입을 승인합니다.' : '선택한 ${targets.length}명의 가입을 거절합니다. 거절한 가입 정보는 삭제됩니다.',
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

  /// 지금 필터의 회원을 CSV 로 내려받는다. 이메일은 화면과 같이 가린다.
  Future<void> _exportLive() async {
    try {
      final csv = await liveMembersCsv(q: _query.trim(), status: _status);
      downloadCsv('members_live.csv', csv);
      if (mounted) showMessage(context, '회원을 내보냈습니다.');
    } on LiveApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  void _export(List<Member> members) {
    String cell(String v) {
      // 엑셀이 값을 수식으로 실행하지 않게 막는다.
      final safe = RegExp(r'^[=+\-@]').hasMatch(v) ? "'$v" : v;
      return '"${safe.replaceAll('"', '""')}"';
    }

    final rows = [
      ['번호', '아이디', '이메일', '가입일', '최근 접속', '상태', '접속 차단'],
      for (final m in members)
        [
          m.shownId,
          m.username,
          m.shownEmail,
          formatDateTime(m.joinedAt),
          m.lastLoginAt == null ? '' : formatDateTime(m.lastLoginAt!),
          m.status.label,
          m.accessBlocked ? '차단' : '',
        ],
    ];
    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    downloadCsv('members_$stamp.csv', rows.map((r) => r.map(cell).join(',')).join('\r\n'));
    logActivity(ActivityKind.member, '회원 ${members.length}명 내보내기');
    showMessage(context, '${members.length}명을 내보냈습니다.');
  }

  void _openMonitor(Member m) => memberMonitorRequest.value = MonitorRequest(m.id);

  /// 넓은 화면은 오른쪽 패널에, 좁은 화면은 팝업으로 보여 준다.
  Future<void> _openDetail(Member m) async {
    if (_wide) return setState(() => _openId = m.id);
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
    final selectable = !useLiveData.value && _status == MemberStatus.pending && can(AdminPermission.memberActions);
    final statuses = <MemberStatus?>[null, ...MemberStatus.values];
    final canBlock = !useLiveData.value;
    _wide = MediaQuery.sizeOf(context).width >= 1200;
    // 고른 회원이 목록에서 빠지면 첫 회원을 보여 준다.
    final open = !_wide ? null : visible.where((m) => m.id == _openId).firstOrNull ?? visible.firstOrNull;

    return AdminPage(
      title: '회원 관리',
      description: '가입 회원을 조회하고 승인·정지·차단·탈퇴를 처리합니다.',
      side: !_wide
          ? null
          : open == null
          ? const Text('회원을 고르세요.', style: TextStyle(color: AppColors.textTertiary))
          : MemberDetailView(
              open,
              key: ValueKey(open.id),
              onChanged: () => setState(() => _selectedIds.removeWhere((id) => !mockMembers.any((m) => m.id == id))),
            ),
      actions: [
        OutlinedButton.icon(
          onPressed: !can(AdminPermission.exportMembers)
              ? null
              : useLiveData.value
              ? _exportLive
              : () => _export(filtered),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('엑셀 내보내기'),
        ),
      ],
      children: [
        if (pending > 0 && !selectable) _PendingBanner(count: pending, onTap: () => _setFilter(MemberStatus.pending)),
        FilterBar(
          hint: '아이디·이메일 검색',
          filters: [
            for (final s in statuses) '${s?.label ?? '전체'} ${_count(s)}',
            '접속 차단 ${currentMembers.where((m) => m.accessBlocked).length}',
          ],
          selectedIndex: _blockedOnly ? statuses.length : statuses.indexOf(_status),
          onFilterSelected: (i) => i == statuses.length ? _setFilter(null, blocked: true) : _setFilter(statuses[i]),
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
          // 버튼이 화면 밖으로 밀리지 않게 맨 왼쪽에 둔다. 테스트 DB 회원은 차단할 수 없어 끝 칸이 없다.
          columns: ['보기', '번호', '아이디', '이메일', '가입일', '최근 접속', '상태', if (canBlock) ''],
          buttonColumns: {0, if (canBlock) 7},
          // 줄을 누르면 상세, 두 번 누르면 그 회원의 워커 목록이다. 승인 전 회원은 워커가 없다.
          onRowTap: (i) => _openDetail(visible[i]),
          highlightedRow: open == null ? null : visible.indexOf(open),
          onRowDoubleTap: (i) {
            if (visible[i].status != MemberStatus.pending) _openMonitor(visible[i]);
          },
          emptyText: '조건에 맞는 회원이 없습니다.',
          selected: selectable
              ? {
                  for (final (i, m) in visible.indexed)
                    if (_selectedIds.contains(m.id)) i,
                }
              : null,
          onSelectChanged: (i, v) =>
              setState(() => v ? _selectedIds.add(visible[i].id) : _selectedIds.remove(visible[i].id)),
          onSelectAll: (v) => setState(() {
            for (final m in visible) {
              v ? _selectedIds.add(m.id) : _selectedIds.remove(m.id);
            }
          }),
          rows: [
            for (final m in visible)
              [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(style: _rowButton, onPressed: () => _openDetail(m), child: const Text('상세')),
                    // 승인 전 회원은 로그인한 적이 없어 모니터링할 내용이 없다.
                    if (m.status != MemberStatus.pending)
                      TextButton(style: _rowButton, onPressed: () => _openMonitor(m), child: const Text('모니터링')),
                  ],
                ),
                Text(m.shownId),
                InkWell(
                  onTap: () => _openDetail(m),
                  // 아이디를 두 번 눌러도 상세가 먼저 열리지 않게 한다.
                  onDoubleTap: m.status == MemberStatus.pending ? null : () => _openMonitor(m),
                  child: Text(m.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(m.shownEmail),
                Text(formatDateTime(m.joinedAt)),
                Text(m.lastLoginAt == null ? '-' : formatDateTime(m.lastLoginAt!)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusBadge(m.status.label, color: memberStatusColor(m.status)),
                    if (m.accessBlocked) ...[const SizedBox(width: 4), const StatusBadge('접속 차단', color: AppColors.up)],
                  ],
                ),
                if (canBlock)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (m.status != MemberStatus.pending && !m.isLive && can(AdminPermission.memberActions))
                        m.accessBlocked
                            ? TextButton(
                                style: _rowButton,
                                onPressed: () async {
                                  if (await unblockMemberAccess(context, m) && mounted) setState(() {});
                                },
                                child: const Text('해제'),
                              )
                            : TextButton(
                                style: _rowButton.merge(TextButton.styleFrom(foregroundColor: AppColors.up)),
                                onPressed: () async {
                                  if (await blockMemberAccess(context, m) && mounted) setState(() {});
                                },
                                child: const Text('차단'),
                              ),
                    ],
                  ),
              ],
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '총 ${filtered.length}명 · ${page + 1} / $pageCount',
              style: const TextStyle(color: AppColors.textTertiary),
            ),
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

final _rowButton = TextButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 6),
  minimumSize: const Size(0, 32),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

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
          Text('가입 승인을 기다리는 회원이 $count명 있습니다.', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextButton(onPressed: onTap, child: const Text('승인 대기 보기')),
        ],
      ),
    );
  }
}
