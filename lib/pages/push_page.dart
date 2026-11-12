import 'package:flutter/material.dart';

import '../mock_accounts.dart';
import '../mock_admin.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

enum _TargetMode {
  all('전체'),
  group('특정 그룹'),
  users('사용자 검색');

  const _TargetMode(this.label);
  final String label;
}

/// 회원 상세에서 이 회원에게 푸시를 쓰겠다는 요청. 값은 회원 번호다.
final pushTargetRequest = ValueNotifier<int?>(null);

class PushPage extends StatefulWidget {
  const PushPage({super.key});

  @override
  State<PushPage> createState() => _PushPageState();
}

class _PushPageState extends State<PushPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _search = TextEditingController();

  _TargetMode _mode = _TargetMode.all;
  PushGroup _group = pushGroups.first;
  final _userIds = <int>{};

  @override
  void initState() {
    super.initState();
    final id = pushTargetRequest.value;
    pushTargetRequest.value = null;
    if (id != null) {
      _mode = _TargetMode.users;
      _userIds.add(id);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _search.dispose();
    super.dispose();
  }

  /// 고른 조건에 해당하는 회원. 받을 수 없는 회원도 포함되며 [_blocked] 로 가른다.
  List<Member> get _targets => switch (_mode) {
    _TargetMode.all => pushableMembers(),
    _TargetMode.group => pushableMembers().where(_group.includes).toList(),
    _TargetMode.users => [
      for (final m in mockMembers)
        if (_userIds.contains(m.id)) m,
    ],
  };

  String get _targetLabel => switch (_mode) {
    _TargetMode.all => '전체',
    _TargetMode.group => _group.label,
    _TargetMode.users =>
      _targets.length == 1 ? _targets.first.username : '${_targets.first.username} 외 ${_targets.length - 1}명',
  };

  List<Member> get _searchResults {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final m in pushableMembers())
        if (!_userIds.contains(m.id) && (m.username.toLowerCase().contains(q) || m.email.toLowerCase().contains(q))) m,
    ].take(5).toList();
  }

  Future<void> _send(List<Member> receivers) async {
    final title = _title.text.trim();
    final ok = await showConfirmDialog(
      context,
      title: '푸시 보내기',
      message: '「$title」을(를) $_targetLabel 대상 ${receivers.length}명에게 보냅니다.\n보낸 뒤에는 취소할 수 없습니다.',
      confirmText: '보내기',
    );
    if (!ok || !mounted) return;
    setState(() {
      sendPush(title, _body.text.trim(), _targetLabel, receivers);
      _title.clear();
      _body.clear();
      _search.clear();
      _userIds.clear();
    });
    showMessage(context, '${receivers.length}명에게 보냈습니다.');
  }

  Widget _chips<T>(
    Iterable<T> values,
    String Function(T) label,
    bool Function(T) selected,
    ValueChanged<T> onSelected,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v), style: const TextStyle(fontSize: 13)),
            visualDensity: VisualDensity.compact,
            selected: selected(v),
            onSelected: (_) => onSelected(v),
          ),
      ],
    );
  }

  Widget _userPicker() {
    final selected = _targets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 20), hintText: '아이디·이메일 검색'),
        ),
        for (final m in _searchResults)
          ListTile(
            dense: true,
            title: Text(m.username, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(maskEmail(m.email), style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            trailing: pushBlockReason(m) == null
                ? const Icon(Icons.add, size: 18, color: AppColors.accent)
                : Text(pushBlockReason(m)!, style: const TextStyle(color: AppColors.warning, fontSize: 12)),
            onTap: () => setState(() {
              _userIds.add(m.id);
              _search.clear();
            }),
          ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in selected)
                InputChip(
                  label: Text(m.username, style: const TextStyle(fontSize: 13)),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => setState(() => _userIds.remove(m.id)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _recipients(List<Member> receivers, List<Member> blocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('받는 사람', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        _chips(_TargetMode.values, (m) => m.label, (m) => m == _mode, (m) => setState(() => _mode = m)),
        const SizedBox(height: 12),
        switch (_mode) {
          _TargetMode.all => const Text('승인된 모든 회원에게 보냅니다.', style: TextStyle(color: AppColors.textTertiary)),
          _TargetMode.group => _chips(
            pushGroups,
            (g) => '${g.label} ${pushableMembers().where(g.includes).length}',
            (g) => g == _group,
            (g) => setState(() => _group = g),
          ),
          _TargetMode.users => _userPicker(),
        },
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 13),
            children: [
              TextSpan(
                text: '발송 ${receivers.length}명',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (blocked.isNotEmpty)
                TextSpan(
                  text: ' · 제외 ${blocked.length}명',
                  style: const TextStyle(color: AppColors.warning),
                ),
            ],
          ),
        ),
        if (blocked.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            blocked.map((m) => '${m.username}(${pushBlockReason(m)})').join(', '),
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final targets = _targets;
    final receivers = targets.where((m) => pushBlockReason(m) == null).toList();
    final blocked = targets.where((m) => pushBlockReason(m) != null).toList();
    final canSend = _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty && receivers.isNotEmpty;

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '제목'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _body,
          onChanged: (_) => setState(() {}),
          minLines: 4,
          maxLines: 6,
          decoration: const InputDecoration(hintText: '내용'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: canSend ? () => _send(receivers) : null,
            icon: const Icon(Icons.send, size: 18),
            label: Text('${receivers.length}명에게 보내기'),
          ),
        ),
      ],
    );

    return AdminPage(
      title: '푸시 알림',
      description: '전체, 특정 그룹, 검색한 사용자에게 푸시 알림을 보내고 발송 이력을 확인합니다.',
      children: [
        if (!can(AdminPermission.sendPush))
          const Panel(
            child: Text('이 권한은 발송 이력만 볼 수 있습니다.', style: TextStyle(color: AppColors.textTertiary)),
          )
        else
          Panel(
            title: '새 알림 보내기',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final recipients = _recipients(receivers, blocked);
                if (constraints.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [recipients, const SizedBox(height: 16), form],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: recipients),
                    const SizedBox(width: 24),
                    Expanded(child: form),
                  ],
                );
              },
            ),
          ),
        AdminTable(
          columns: const ['번호', '제목', '내용', '대상', '발송 시각', '발송', '열람'],
          rows: [
            for (final p in mockPushes)
              [
                Text('${p.id}'),
                Text(p.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                SizedBox(width: 260, child: Text(p.body, overflow: TextOverflow.ellipsis)),
                Text(p.target),
                Text(formatDateTime(p.sentAt)),
                Text(formatNumber(p.sentCount)),
                Text(
                  '${formatNumber(p.openCount)} (${(p.openCount / p.sentCount * 100).round()}%)',
                  style: const TextStyle(color: AppColors.accent),
                ),
              ],
          ],
        ),
      ],
    );
  }
}
