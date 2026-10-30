import 'package:flutter/material.dart';

import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'member_actions.dart';
import 'members_page.dart' show memberStatusColor;

Future<void> showMemberDetail(BuildContext context, Member member) =>
    showDialog<void>(context: context, builder: (_) => _MemberDetailDialog(member));

class _MemberDetailDialog extends StatefulWidget {
  const _MemberDetailDialog(this.member);

  final Member member;

  @override
  State<_MemberDetailDialog> createState() => _MemberDetailDialogState();
}

class _MemberDetailDialogState extends State<_MemberDetailDialog> {
  final _memo = TextEditingController();
  bool _showEmail = false;

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
    final ok = await showConfirmDialog(context,
        title: title, message: message, confirmText: confirmText, destructive: destructive);
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

  void _addMemo() {
    final text = _memo.text.trim();
    if (text.isEmpty) return;
    setState(() => addMemo(m, text));
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
                        Text('#${m.id}', style: const TextStyle(color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Panel(title: '기본 정보', child: Column(children: _infoRows())),
              const SizedBox(height: 12),
              Panel(
                title: '처리',
                child: Wrap(spacing: 8, runSpacing: 8, children: _actionButtons()),
              ),
              const SizedBox(height: 12),
              Panel(
                title: '관리자 메모',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    ..._logs(m.memos, '메모가 없습니다.'),
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
              Text(_showEmail ? m.email : maskEmail(m.email)),
              if (!_showEmail)
                TextButton(
                  onPressed: () => setState(() {
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
        _InfoRow('푸시 수신', Text(m.pushAgreed ? '동의' : '거부')),
        _InfoRow('관심종목', Text('${m.watchlistCount}개')),
        if (m.status == MemberStatus.suspended) ...[
          _InfoRow('정지 사유', Text(m.suspendReason ?? '-')),
          _InfoRow('정지 종료', Text(m.suspendUntil == null ? '영구' : formatDateTime(m.suspendUntil!))),
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
        if (m.status == MemberStatus.active || m.status == MemberStatus.dormant)
          OutlinedButton.icon(
            onPressed: _suspend,
            icon: const Icon(Icons.block, size: 18),
            label: const Text('이용 정지'),
          ),
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
        if (m.status != MemberStatus.pending && m.status != MemberStatus.deleteRequested) ...[
          OutlinedButton.icon(
            onPressed: () => showNotConnected(context),
            icon: const Icon(Icons.lock_reset, size: 18),
            label: const Text('비밀번호 재설정 메일'),
          ),
          OutlinedButton.icon(
            onPressed: () => showNotConnected(context),
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
                  Text('${formatDateTime(l.at)} · ${l.actor}',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
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
