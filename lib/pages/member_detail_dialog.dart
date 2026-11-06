import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_admin.dart';
import '../mock_consultations.dart';
import '../mock_data.dart';
import '../mock_workers.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'member_actions.dart';
import 'members_page.dart' show memberStatusColor;
import 'push_page.dart' show pushTargetRequest;

Future<void> showMemberDetail(BuildContext context, Member member) =>
    showDialog<void>(context: context, builder: (_) => _MemberDetailDialog(member));

/// 차단 사유를 받아 접속을 막는다. 처리했으면 true.
Future<bool> blockMemberAccess(BuildContext context, Member m) async {
  final reason = await showDialog<String>(context: context, builder: (_) => _BlockAccessDialog(m));
  if (reason == null || !context.mounted) return false;
  blockAccess(m, reason: reason);
  showMessage(context, '${m.username} 회원의 접속을 차단했습니다.');
  return true;
}

/// 확인을 받은 뒤 접속 차단을 푼다. 처리했으면 true.
Future<bool> unblockMemberAccess(BuildContext context, Member m) async {
  final ok = await showConfirmDialog(
    context,
    title: '차단 해제',
    message: '${m.username} 회원이 다시 앱에 접속할 수 있습니다.',
    confirmText: '해제',
  );
  if (!ok || !context.mounted) return false;
  unblockAccess(m);
  showMessage(context, '접속 차단을 해제했습니다.');
  return true;
}

class _MemberDetailDialog extends StatefulWidget {
  const _MemberDetailDialog(this.member);

  final Member member;

  @override
  State<_MemberDetailDialog> createState() => _MemberDetailDialogState();
}

class _MemberDetailDialogState extends State<_MemberDetailDialog> {
  final _memo = TextEditingController();
  bool _showEmail = false;
  String? _liveEmail; // 테스트 DB 회원의 전체 이메일
  ConsultChannel _channel = ConsultChannel.phone;
  ConsultType _type = ConsultType.order;

  Member get m => widget.member;

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  /// 확인을 받은 뒤 처리한다. [closes] 면 처리 후 창을 닫는다(거절·탈퇴처럼 회원이 사라질 때).
  Future<void> _act({
    required String title,
    required String message,
    required String confirmText,
    required String done,
    required VoidCallback action,
    bool destructive = false,
    bool closes = false,
  }) async {
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      destructive: destructive,
    );
    if (!ok || !mounted) return;
    setState(action);
    showMessage(context, done);
    if (closes) Navigator.pop(context);
  }

  Future<void> _suspend() async {
    final result = await showDialog<(String, int?)>(context: context, builder: (_) => const _SuspendDialog());
    if (result == null || !mounted) return;
    final (reason, days) = result;
    setState(() => suspendMember(m, reason: reason, days: days));
    showMessage(context, '${m.username} 회원을 정지했습니다.');
  }

  Future<void> _showLiveEmail() async {
    try {
      final email = await liveEmail(m);
      if (mounted) {
        setState(() {
          _liveEmail = email;
          _showEmail = true;
        });
      }
    } on LiveApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  void _addMemo() {
    final text = _memo.text.trim();
    if (text.isEmpty) return;
    setState(() => addConsultation(m, _channel, _type, text));
    _memo.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(m.username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        StatusBadge(m.status.label, color: memberStatusColor(m.status)),
                        if (m.accessBlocked) const StatusBadge('접속 차단', color: AppColors.up),
                        Text('#${m.shownId}', style: const TextStyle(color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                  IconButton(tooltip: '닫기', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              Panel(
                title: '기본 정보',
                child: Column(children: _infoRows()),
              ),
              const SizedBox(height: 12),
              Panel(
                title: '처리',
                child: m.isLive
                    ? const Text('테스트 DB 회원은 조회만 할 수 있습니다.', style: TextStyle(color: AppColors.textTertiary))
                    : can(AdminPermission.memberActions)
                    ? Wrap(spacing: 8, runSpacing: 8, children: _actionButtons())
                    : const Text('이 권한은 조회와 상담 기록만 할 수 있습니다.', style: TextStyle(color: AppColors.textTertiary)),
              ),
              if (!m.isLive) ...[
                const SizedBox(height: 12),
                Panel(
                  title: '상담 이력',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          DropdownButton<ConsultChannel>(
                            value: _channel,
                            underline: const SizedBox.shrink(),
                            items: [
                              for (final c in ConsultChannel.values) DropdownMenuItem(value: c, child: Text(c.label)),
                            ],
                            onChanged: (c) => setState(() => _channel = c ?? _channel),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<ConsultType>(
                            value: _type,
                            underline: const SizedBox.shrink(),
                            items: [
                              for (final t in ConsultType.values) DropdownMenuItem(value: t, child: Text(t.label)),
                            ],
                            onChanged: (t) => setState(() => _type = t ?? _type),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _memo,
                              onSubmitted: (_) => _addMemo(),
                              decoration: const InputDecoration(hintText: '상담·문의 내용을 남겨 두세요'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(onPressed: _addMemo, child: const Text('추가')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._logs([
                        for (final c in consultationsOf(m.id))
                          MemberLog(
                            c.at,
                            c.adminName,
                            '[${c.status.label}] ${c.channel.label} · ${c.type.label}: ${c.content}',
                          ),
                      ], '상담 이력이 없습니다.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Panel(
                  title: '처리 이력',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _logs(m.history, '처리 이력이 없습니다.'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _infoRows() => [
    _InfoRow(
      '이메일',
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(_liveEmail ?? (_showEmail ? m.email : m.shownEmail)),
          if (!_showEmail)
            TextButton(
              onPressed: m.isLive
                  ? _showLiveEmail
                  : () => setState(() {
                      _showEmail = true;
                      logPrivacyView(m, '이메일');
                    }),
              child: const Text('전체 보기'),
            ),
        ],
      ),
    ),
    _InfoRow('가입일', Text(formatDateTime(m.joinedAt))),
    _InfoRow('최근 접속', Text(m.lastLoginAt == null ? '-' : formatDateTime(m.lastLoginAt!))),
    _InfoRow('기기', Text(m.device)),
    if (!m.isLive) _InfoRow('푸시 수신', Text(m.pushAgreed ? '동의' : '거부')),
    _InfoRow('관심종목', Text('${m.watchlistCount}개')),
    if (m.status == MemberStatus.suspended) ...[
      _InfoRow('정지 사유', Text(m.suspendReason ?? '-')),
      _InfoRow('정지 종료', Text(m.suspendUntil == null ? '영구' : formatDateTime(m.suspendUntil!))),
    ],
    if (m.accessBlocked) ...[
      _InfoRow('차단 사유', Text(m.accessBlockReason ?? '-')),
      _InfoRow('차단 일시', Text(formatDateTime(m.accessBlockedAt!))),
    ],
    if (m.status == MemberStatus.deleteRequested && m.deleteRequestedAt != null)
      _InfoRow('탈퇴 요청일', Text(formatDateTime(m.deleteRequestedAt!))),
  ];

  List<Widget> _actionButtons() => [
    if (m.status == MemberStatus.pending) ...[
      FilledButton.icon(
        onPressed: () => _act(
          title: '가입 승인',
          message: '${m.username} 회원의 가입을 승인합니다.',
          confirmText: '승인',
          done: '가입을 승인했습니다.',
          action: () => approveMember(m),
        ),
        icon: const Icon(Icons.check, size: 18),
        label: const Text('가입 승인'),
      ),
      OutlinedButton.icon(
        onPressed: () => _act(
          title: '가입 거절',
          message: '${m.username} 회원의 가입을 거절합니다. 가입 정보는 삭제됩니다.',
          confirmText: '거절',
          done: '가입을 거절했습니다.',
          action: () => rejectMember(m),
          destructive: true,
          closes: true,
        ),
        icon: const Icon(Icons.close, size: 18),
        label: const Text('가입 거절'),
      ),
    ],
    if (m.status == MemberStatus.active)
      OutlinedButton.icon(
        onPressed: () => _act(
          title: '휴면 전환',
          message: '${m.username} 회원을 휴면으로 전환합니다.',
          confirmText: '휴면 전환',
          done: '휴면으로 전환했습니다.',
          action: () => markDormant(m),
        ),
        icon: const Icon(Icons.bedtime_outlined, size: 18),
        label: const Text('휴면 전환'),
      ),
    if (m.status == MemberStatus.dormant)
      FilledButton.icon(
        onPressed: () => _act(
          title: '휴면 해제',
          message: '${m.username} 회원의 휴면을 해제합니다.',
          confirmText: '해제',
          done: '휴면을 해제했습니다.',
          action: () => releaseDormant(m),
        ),
        icon: const Icon(Icons.wb_sunny_outlined, size: 18),
        label: const Text('휴면 해제'),
      ),
    if (m.status == MemberStatus.active || m.status == MemberStatus.dormant)
      OutlinedButton.icon(onPressed: _suspend, icon: const Icon(Icons.block, size: 18), label: const Text('이용 정지')),
    if (m.status == MemberStatus.suspended)
      FilledButton.icon(
        onPressed: () => _act(
          title: '정지 해제',
          message: '${m.username} 회원의 이용 정지를 해제합니다.',
          confirmText: '해제',
          done: '정지를 해제했습니다.',
          action: () => unsuspendMember(m),
        ),
        icon: const Icon(Icons.lock_open, size: 18),
        label: const Text('정지 해제'),
      ),
    if (m.status == MemberStatus.deleteRequested)
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppColors.up),
        onPressed: () => _act(
          title: '탈퇴 처리',
          message: '${m.username} 회원의 탈퇴를 완료합니다. 회원 정보가 삭제되며 되돌릴 수 없습니다.',
          confirmText: '탈퇴 처리',
          done: '탈퇴 처리를 완료했습니다.',
          action: () => completeDeletion(m),
          destructive: true,
          closes: true,
        ),
        icon: const Icon(Icons.person_remove_outlined, size: 18),
        label: const Text('탈퇴 처리 완료'),
      ),
    if (m.status != MemberStatus.pending)
      m.accessBlocked
          ? FilledButton.icon(
              onPressed: () async {
                if (await unblockMemberAccess(context, m) && mounted) setState(() {});
              },
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('차단 해제'),
            )
          : OutlinedButton.icon(
              onPressed: () async {
                if (await blockMemberAccess(context, m) && mounted) setState(() {});
              },
              icon: const Icon(Icons.phonelink_lock, size: 18),
              label: const Text('접속 차단'),
            ),
    if (m.status != MemberStatus.pending && m.status != MemberStatus.deleteRequested) ...[
      OutlinedButton.icon(
        onPressed: () => _act(
          title: '비밀번호 재설정 메일',
          message: '${m.username} 회원에게 비밀번호 재설정 메일을 보냅니다.',
          confirmText: '보내기',
          done: '재설정 메일을 보냈습니다.',
          action: () => sendPasswordReset(m),
        ),
        icon: const Icon(Icons.lock_reset, size: 18),
        label: const Text('비밀번호 재설정 메일'),
      ),
      OutlinedButton.icon(
        // 작성은 푸시 화면에서 한다. 이 회원을 받는 사람으로 골라 둔 채 연다.
        onPressed: () {
          Navigator.pop(context);
          pushTargetRequest.value = m.id;
        },
        icon: const Icon(Icons.notifications_outlined, size: 18),
        label: const Text('푸시 보내기'),
      ),
    ],
  ];

  List<Widget> _logs(List<MemberLog> logs, String empty) => logs.isEmpty
      ? [Text(empty, style: const TextStyle(color: AppColors.textTertiary))]
      : [
          for (final l in logs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.text),
                  const SizedBox(height: 2),
                  Text(
                    '${formatDateTime(l.at)} · ${l.actor}',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
        ];
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(color: AppColors.textTertiary)),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }
}

/// 차단 사유를 받는다. 돌고 있는 워커는 멈추지 않으므로 함께 알려 준다.
class _BlockAccessDialog extends StatefulWidget {
  const _BlockAccessDialog(this.member);

  final Member member;

  @override
  State<_BlockAccessDialog> createState() => _BlockAccessDialogState();
}

class _BlockAccessDialogState extends State<_BlockAccessDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final reason = _reason.text.trim();
    final running = workersOf(m.id).where((w) => w.status == WorkerStatus.running).length;
    return AlertDialog(
      title: const Text('접속 차단'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${m.username} 회원의 앱 접속을 바로 끊고, 해제할 때까지 로그인을 막습니다.'),
            if (running > 0) ...[
              const SizedBox(height: 8),
              Text(
                '가동 중인 워커 $running개는 멈추지 않습니다. 회원이 앱에서 직접 끌 수 없게 됩니다.',
                style: const TextStyle(color: AppColors.warning),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: '차단 사유'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.up),
          onPressed: reason.isEmpty ? null : () => Navigator.pop(context, reason),
          child: const Text('차단'),
        ),
      ],
    );
  }
}

/// 정지 사유와 기간을 받는다. 기간이 null 이면 영구 정지.
class _SuspendDialog extends StatefulWidget {
  const _SuspendDialog();

  @override
  State<_SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends State<_SuspendDialog> {
  static const _periods = <(String, int?)>[('7일', 7), ('30일', 30), ('영구', null)];

  final _reason = TextEditingController();
  int _period = 0;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _reason.text.trim();
    return AlertDialog(
      title: const Text('이용 정지'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _reason,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: '정지 사유 (회원에게 안내됩니다)'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final (i, (label, _)) in _periods.indexed)
                  ChoiceChip(
                    label: Text(label),
                    selected: i == _period,
                    onSelected: (_) => setState(() => _period = i),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.up),
          onPressed: reason.isEmpty ? null : () => Navigator.pop(context, (reason, _periods[_period].$2)),
          child: const Text('정지'),
        ),
      ],
    );
  }
}
