import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_admin.dart';
import '../mock_consultations.dart';
import '../mock_data.dart';
import '../mock_workers.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'member_access_panels.dart';
import 'member_actions.dart';
import 'member_edit_panel.dart';
import 'member_monitor_page.dart' show MonitorRequest, memberMonitorRequest;
import 'members_page.dart' show memberStatusColor;
import 'push_page.dart' show pushTargetRequest;

/// 오른쪽 패널을 둘 자리가 없는 화면에서 쓰는 팝업.
Future<void> showMemberDetail(BuildContext context, Member member) => showDialog<void>(
  context: context,
  builder: (dialog) => Dialog(
    backgroundColor: AppColors.background,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MemberDetailView(member, onClose: () => Navigator.pop(dialog)),
      ),
    ),
  ),
);

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

/// 회원 상세 내용. 팝업이면 [onClose] 로 닫고, 패널이면 [onChanged] 로 목록을 다시 그린다.
class MemberDetailView extends StatefulWidget {
  const MemberDetailView(this.member, {super.key, this.onClose, this.onChanged});

  final Member member;
  final VoidCallback? onClose;
  final VoidCallback? onChanged;

  @override
  State<MemberDetailView> createState() => _MemberDetailViewState();
}

/// 테스트 DB 회원의 처리 입력 칸. 저장 API 가 없어 마지막 단계에서 안내만 한다.
class _LiveAction {
  const _LiveAction(this.title, this.message, this.confirmText, {this.reasonHint, this.periods = false});

  final String title;
  final String message;
  final String confirmText;
  final String? reasonHint; // 있으면 사유를 받는다
  final bool periods; // 정지 기간을 고른다
}

const _suspendPeriods = ['7일', '30일', '영구'];

class _MemberDetailViewState extends State<MemberDetailView> {
  final _memo = TextEditingController();
  bool _showEmail = false;
  String? _liveEmail; // 테스트 DB 회원의 전체 이메일
  ConsultChannel _channel = ConsultChannel.phone;
  ConsultType _type = ConsultType.order;
  bool _changingGrade = false;
  String? _newGrade;
  _LiveAction? _action;
  final _actionReason = TextEditingController();
  String _period = _suspendPeriods.first;

  Member get m => widget.member;

  @override
  void initState() {
    super.initState();
    // 테스트 DB 회원 상세를 열면 서버가 열람 기록을 남긴다. 화면 값은 목록에서 받은 것을 쓴다.
    if (m.isLive) logLiveMemberView(m);
  }

  @override
  void dispose() {
    _memo.dispose();
    _actionReason.dispose();
    super.dispose();
  }

  void _openAction(_LiveAction action) => setState(() {
    _action = action;
    _changingGrade = false;
    _actionReason.clear();
    _period = _suspendPeriods.first;
  });

  void _closeAction() => setState(() => _action = null);

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
    if (m.isLive) return _openAction(_LiveAction(title, message, confirmText));
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
    widget.onChanged?.call();
    if (closes) widget.onClose?.call();
  }

  /// 처리한 뒤 이 화면과 목록을 함께 고친다.
  void _changed() {
    setState(() {});
    widget.onChanged?.call();
  }

  Future<void> _suspend() async {
    if (m.isLive) {
      return _openAction(
        _LiveAction('이용 정지', '${m.username} 회원의 이용을 정지합니다.', '정지', reasonHint: '정지 사유 (회원에게 안내됩니다)', periods: true),
      );
    }
    final result = await showDialog<(String, int?)>(context: context, builder: (_) => const _SuspendDialog());
    if (result == null || !mounted) return;
    final (reason, days) = result;
    suspendMember(m, reason: reason, days: days);
    _changed();
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
    if (m.isLive) return showNotConnected(context); // 상담은 테스트 DB 에 저장할 곳이 없다
    setState(() => addConsultation(m, _channel, _type, text));
    _memo.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            if (widget.onClose != null)
              IconButton(tooltip: '닫기', onPressed: widget.onClose, icon: const Icon(Icons.close)),
          ],
        ),
        const SizedBox(height: 16),
        MemberEditPanel(m, infoCells: _infoRows()),
        const SizedBox(height: 8),
        Panel(
          title: '처리',
          child: can(AdminPermission.memberActions)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: _actionButtons()),
                    if (_changingGrade) ...[const SizedBox(height: 8), _gradeRow()],
                    if (_action != null) ...[const SizedBox(height: 8), _actionForm(_action!)],
                  ],
                )
              : const Text('이 권한은 조회와 상담 기록만 할 수 있습니다.', style: TextStyle(color: AppColors.textTertiary)),
        ),
        ...[
          const SizedBox(height: 8),
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
                      items: [for (final c in ConsultChannel.values) DropdownMenuItem(value: c, child: Text(c.label))],
                      onChanged: (c) => setState(() => _channel = c ?? _channel),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<ConsultType>(
                      value: _type,
                      underline: const SizedBox.shrink(),
                      items: [for (final t in ConsultType.values) DropdownMenuItem(value: t, child: Text(t.label))],
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _logs(m.history, '처리 이력이 없습니다.')),
          ),
          if (m.isLive) ...[const SizedBox(height: 12), LiveMemberAccessPanels(m)],
        ],
      ],
    );
  }

  List<FormCell> _infoRows() => [
    FormCell(
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
    FormCell('가입일', Text(formatDateTime(m.joinedAt))),
    FormCell('최근 접속', Text(m.lastLoginAt == null ? '-' : formatDateTime(m.lastLoginAt!))),
    FormCell('기기', Text(m.device)),
    if (m.isLive)
      FormCell(
        '봉 단위',
        Text(m.customCandleUnits == null ? '-' : m.customCandleUnits!),
      ),
    // 앱은 가입 때 동의를 받지만 서버에 보내지 않아 기록이 없다.
    const FormCell('이용약관 동의', Text('-')),
    const FormCell('개인정보 동의', Text('-')),
    if (!m.isLive) FormCell('푸시 수신', Text(m.pushAgreed ? '동의' : '거부')),
    FormCell('관심종목', Text('${m.watchlistCount}개')),
    if (m.status == MemberStatus.suspended) ...[
      FormCell('정지 사유', Text(m.suspendReason ?? '-')),
      FormCell('정지 종료', Text(m.suspendUntil == null ? '영구' : formatDateTime(m.suspendUntil!))),
    ],
    if (m.accessBlocked) ...[
      FormCell('차단 사유', Text(m.accessBlockReason ?? '-')),
      FormCell('차단 일시', Text(formatDateTime(m.accessBlockedAt!))),
    ],
    if (m.status == MemberStatus.deleteRequested && m.deleteRequestedAt != null)
      FormCell('탈퇴 요청일', Text(formatDateTime(m.deleteRequestedAt!))),
  ];

  /// 처리 칸 안에서 사유·기간을 받는다. 마지막 버튼은 저장 API 가 없어 안내만 한다.
  Widget _actionForm(_LiveAction a) {
    final needsReason = a.reasonHint != null;
    final ready = !needsReason || _actionReason.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.grid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(a.message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (needsReason) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _actionReason,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: a.reasonHint),
            ),
          ],
          if (a.periods) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final p in _suspendPeriods)
                  ChoiceChip(label: Text(p), selected: p == _period, onSelected: (_) => setState(() => _period = p)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: _closeAction, child: const Text('취소')),
              const SizedBox(width: 6),
              FilledButton(onPressed: ready ? () => showNotConnected(context) : null, child: Text(a.confirmText)),
            ],
          ),
        ],
      ),
    );
  }

  /// 팝업 없이 처리 칸 안에서 등급을 고른다. 저장 API 가 없어 지금은 안내만 한다.
  Widget _gradeRow() => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          initialValue: _newGrade,
          hint: const Text('변경할 회원등급', style: TextStyle(fontSize: 13)),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          items: [for (final g in memberGrades) DropdownMenuItem(value: g, child: Text(g))],
          onChanged: (v) => setState(() => _newGrade = v),
        ),
      ),
      const SizedBox(width: 6),
      FilledButton(onPressed: _newGrade == null ? null : () => showNotConnected(context), child: const Text('변경')),
      const SizedBox(width: 6),
      OutlinedButton(
        onPressed: () => setState(() {
          _changingGrade = false;
          _newGrade = null;
        }),
        child: const Text('취소'),
      ),
    ],
  );

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
                if (m.isLive) {
                  return _openAction(_LiveAction('차단 해제', '${m.username} 회원이 다시 앱에 접속할 수 있습니다.', '해제'));
                }
                if (await unblockMemberAccess(context, m) && mounted) _changed();
              },
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('차단 해제'),
            )
          : OutlinedButton.icon(
              onPressed: () async {
                if (m.isLive) {
                  return _openAction(
                    _LiveAction(
                      '접속 차단',
                      '${m.username} 회원의 앱 접속을 막습니다. 돌고 있는 워커는 멈추지 않습니다.',
                      '차단',
                      reasonHint: '차단 사유',
                    ),
                  );
                }
                if (await blockMemberAccess(context, m) && mounted) _changed();
              },
              icon: const Icon(Icons.phonelink_lock, size: 18),
              label: const Text('접속 차단'),
            ),
    if (m.status != MemberStatus.pending)
      OutlinedButton.icon(
        onPressed: () => setState(() {
          _changingGrade = !_changingGrade;
          _action = null;
        }),
        icon: const Icon(Icons.workspace_premium_outlined, size: 18),
        label: const Text('회원등급 변경'),
      ),
    if (m.status != MemberStatus.pending)
      OutlinedButton.icon(
        onPressed: () {
          widget.onClose?.call();
          memberMonitorRequest.value = MonitorRequest(m.id, logs: true);
        },
        icon: const Icon(Icons.receipt_long_outlined, size: 18),
        label: const Text('고객 상세 로그 보기'),
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
          widget.onClose?.call();
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
