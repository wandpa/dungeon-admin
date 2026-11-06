import 'package:flutter/material.dart';

import '../mock_accounts.dart';
import '../mock_admin.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'member_edit_panel.dart' show memberGrades;

Color _statusColor(NoticeStatus s) => switch (s) {
  NoticeStatus.published => AppColors.success,
  NoticeStatus.scheduled => AppColors.accent,
  NoticeStatus.draft => AppColors.textTertiary,
};

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  String _query = '';
  NoticeStatus? _status; // null 이면 전체

  bool _editing = false; // 작성·수정 패널이 열려 있는가
  Notice? _target; // 수정 중인 공지. 새 공지면 null
  bool _pinned = false;
  bool _notifyPush = false;
  DateTime? _publishAt; // 예약 게시 시각
  String _category = noticeCategories.first;
  final _grades = <String>{}; // 비어 있으면 전체 회원
  bool _popup = false;
  DateTime? _endAt; // 게시 종료 시각

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// 고정 공지가 먼저, 그다음 최신순.
  List<Notice> get _visible {
    final q = _query.trim().toLowerCase();
    return [
      for (final n in mockNotices)
        if ((_status == null || n.status == _status) &&
            (q.isEmpty || n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q)))
          n,
    ]..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  int _count(NoticeStatus? s) => s == null ? mockNotices.length : mockNotices.where((n) => n.status == s).length;

  void _open(Notice? n) => setState(() {
    _editing = true;
    _target = n;
    _title.text = n?.title ?? '';
    _body.text = n?.body ?? '';
    _pinned = n?.pinned ?? false;
    _publishAt = n?.status == NoticeStatus.scheduled ? n?.publishAt : null;
    _notifyPush = false;
    _category = n?.category ?? noticeCategories.first;
    _grades
      ..clear()
      ..addAll(n?.grades ?? const {});
    _popup = n?.popup ?? false;
    _endAt = n?.endAt;
  });

  void _close() => setState(() {
    _editing = false;
    _target = null;
  });

  bool get _valid => _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _publishAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time == null || !mounted) return;
    setState(() {
      _publishAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _notifyPush = false;
    });
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      helpText: '게시 종료일',
      initialDate: _endAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() => _endAt = DateTime(date.year, date.month, date.day, 23, 59));
  }

  void _write(NoticeStatus status) {
    final n = _target;
    final now = DateTime.now();
    if (n == null) {
      mockNotices.add(
        Notice(
          (mockNotices.map((e) => e.id).fold(0, (a, b) => a > b ? a : b)) + 1,
          _title.text.trim(),
          _body.text.trim(),
          currentAdmin,
          now,
          0,
          _pinned,
          status,
          publishAt: _publishAt,
          category: _category,
          grades: {..._grades},
          popup: _popup,
          endAt: _endAt,
        ),
      );
    } else {
      n
        ..title = _title.text.trim()
        ..body = _body.text.trim()
        ..pinned = _pinned
        ..status = status
        ..publishAt = _publishAt
        ..updatedAt = now
        ..category = _category
        ..grades = {..._grades}
        ..popup = _popup
        ..endAt = _endAt;
    }
  }

  void _saveDraft() {
    setState(() {
      _publishAt = null;
      _write(NoticeStatus.draft);
      logActivity(ActivityKind.notice, '「${_title.text.trim()}」 임시저장');
      _editing = false;
      _target = null;
    });
    showMessage(context, '임시저장했습니다.');
  }

  /// 게시·예약. 사용자에게 보이게 되므로 확인을 받는다.
  Future<void> _publish() async {
    final scheduled = _publishAt != null;
    final receivers = pushableMembers().where((m) => pushBlockReason(m) == null).toList();
    final title = _title.text.trim();
    final ok = await showConfirmDialog(
      context,
      title: scheduled ? '예약 게시' : '공지 게시',
      message: scheduled
          ? '「$title」을(를) ${formatDateTime(_publishAt!)}에 게시합니다.'
          : '「$title」을(를) 사용자에게 게시합니다.${_notifyPush ? '\n${receivers.length}명에게 푸시도 보냅니다.' : ''}',
      confirmText: scheduled ? '예약' : '게시',
    );
    if (!ok || !mounted) return;
    final push = _notifyPush && !scheduled;
    setState(() {
      _write(scheduled ? NoticeStatus.scheduled : NoticeStatus.published);
      logActivity(ActivityKind.notice, '「$title」 ${scheduled ? '게시 예약' : '게시'}');
      if (push) sendPush(title, _body.text.trim(), '전체', receivers);
      _editing = false;
      _target = null;
    });
    showMessage(context, scheduled ? '게시를 예약했습니다.' : (push ? '게시하고 푸시를 보냈습니다.' : '게시했습니다.'));
  }

  /// 목록에서 바로 게시하거나 내린다.
  Future<void> _togglePublished(Notice n) async {
    final live = n.status == NoticeStatus.published;
    final ok = await showConfirmDialog(
      context,
      title: live ? '게시 중단' : '공지 게시',
      message: live ? '「${n.title}」을(를) 내리고 임시저장으로 돌립니다.' : '「${n.title}」을(를) 지금 게시합니다.',
      confirmText: live ? '게시 중단' : '게시',
      destructive: live,
    );
    if (!ok || !mounted) return;
    setState(() {
      n
        ..status = live ? NoticeStatus.draft : NoticeStatus.published
        ..publishAt = null
        ..updatedAt = DateTime.now();
      logActivity(ActivityKind.notice, '「${n.title}」 ${live ? '게시 중단' : '게시'}');
    });
    showMessage(context, live ? '게시를 중단했습니다.' : '게시했습니다.');
  }

  Future<void> _delete(Notice n) async {
    final ok = await showConfirmDialog(
      context,
      title: '공지 삭제',
      message: '「${n.title}」을(를) 삭제합니다. 되돌릴 수 없습니다.',
      confirmText: '삭제',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      mockNotices.remove(n);
      logActivity(ActivityKind.notice, '「${n.title}」 삭제');
      if (identical(_target, n)) {
        _editing = false;
        _target = null;
      }
    });
    showMessage(context, '삭제했습니다.');
  }

  Widget _editor() {
    final n = _target;
    final live = n?.status == NoticeStatus.published;
    Widget choice(String label, bool selected, VoidCallback onTap) => ChoiceChip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      selected: selected,
      onSelected: (_) => onTap(),
    );
    Widget row(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(child: child),
        ],
      ),
    );
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          '분류',
          Wrap(
            spacing: 6,
            children: [
              for (final c in noticeCategories) choice(c, c == _category, () => setState(() => _category = c)),
            ],
          ),
        ),
        row(
          '노출 대상',
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              choice('전체 회원', _grades.isEmpty, () => setState(_grades.clear)),
              for (final g in memberGrades)
                FilterChip(
                  label: Text(g),
                  visualDensity: VisualDensity.compact,
                  selected: _grades.contains(g),
                  onSelected: (on) => setState(() {
                    on ? _grades.add(g) : _grades.remove(g);
                    if (_grades.isNotEmpty) _notifyPush = false;
                  }),
                ),
            ],
          ),
        ),
        TextField(
          controller: _title,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '제목'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _body,
          onChanged: (_) => setState(() {}),
          minLines: 6,
          maxLines: 12,
          decoration: const InputDecoration(hintText: '내용'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Toggle('상단 고정', _pinned, (v) => setState(() => _pinned = v)),
            _Toggle('앱 팝업', _popup, (v) => setState(() => _popup = v)),
            // 예약 게시 때 나갈 푸시는 아직 처리할 곳이 없어 지금 게시할 때만 고른다.
            // 샘플 회원에 등급이 없어 등급을 고르면 푸시 대상을 정할 수 없다.
            _Toggle(
              '게시할 때 푸시 보내기',
              _notifyPush,
              _publishAt != null || _grades.isNotEmpty ? null : (v) => setState(() => _notifyPush = v),
            ),
            OutlinedButton.icon(
              onPressed: _pickSchedule,
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(_publishAt == null ? '예약 게시' : '${formatDateTime(_publishAt!)} 게시'),
            ),
            if (_publishAt != null)
              TextButton(onPressed: () => setState(() => _publishAt = null), child: const Text('예약 취소')),
            OutlinedButton.icon(
              onPressed: _pickEnd,
              icon: const Icon(Icons.event_busy, size: 18),
              label: Text(_endAt == null ? '게시 종료일' : '${formatDateTime(_endAt!)} 종료'),
            ),
            if (_endAt != null) TextButton(onPressed: () => setState(() => _endAt = null), child: const Text('종료일 취소')),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(onPressed: _close, child: const Text('취소')),
            OutlinedButton(onPressed: _valid ? _saveDraft : null, child: const Text('임시저장')),
            FilledButton(
              onPressed: _valid ? _publish : null,
              child: Text(_publishAt != null ? '예약하기' : (live ? '수정 저장' : '게시하기')),
            ),
          ],
        ),
      ],
    );

    final preview = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '미리보기 · $_category${_popup ? ' · 앱 팝업' : ''}',
            style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _title.text.trim().isEmpty ? '제목' : _title.text.trim(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${n?.author ?? currentAdmin} · ${formatDateTime(_publishAt ?? n?.createdAt ?? DateTime.now())}',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(_body.text.trim().isEmpty ? '내용' : _body.text.trim()),
        ],
      ),
    );

    return Panel(
      title: n == null ? '공지 작성' : '공지 수정 · #${n.id}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [form, const SizedBox(height: 12), preview],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: form),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: preview),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final canEdit = can(AdminPermission.editNotices);
    final statuses = <NoticeStatus?>[null, ...NoticeStatus.values];
    return AdminPage(
      title: '공지사항',
      description: '공지를 작성해 바로 게시하거나 예약하고, 수정·삭제·상단 고정을 관리합니다.',
      actions: [
        if (canEdit)
          FilledButton.icon(
            onPressed: () => _open(null),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('공지 작성'),
          ),
      ],
      children: [
        if (_editing) _editor(),
        FilterBar(
          hint: '제목·내용 검색',
          filters: [for (final s in statuses) '${s?.label ?? '전체'} ${_count(s)}'],
          selectedIndex: statuses.indexOf(_status),
          onFilterSelected: (i) => setState(() => _status = statuses[i]),
          onSearchChanged: (v) => setState(() => _query = v),
        ),
        AdminTable(
          columns: const ['번호', '분류', '제목', '대상', '작성자', '작성일', '조회수', '상태', ''],
          emptyText: '조건에 맞는 공지가 없습니다.',
          rows: [
            for (final n in visible)
              [
                Text('${n.id}'),
                Text(n.category),
                InkWell(
                  onTap: canEdit ? () => _open(n) : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (n.pinned) ...[
                        const Icon(Icons.push_pin, size: 16, color: AppColors.accent),
                        const SizedBox(width: 6),
                      ],
                      Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (n.popup) ...[const SizedBox(width: 6), const StatusBadge('팝업', color: AppColors.brand)],
                    ],
                  ),
                ),
                Text(n.audience),
                Text(n.author),
                Text(formatDateTime(n.createdAt)),
                Text(formatNumber(n.views)),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge(n.status.label, color: _statusColor(n.status)),
                    if (n.status == NoticeStatus.scheduled && n.publishAt != null)
                      Text(
                        formatDateTime(n.publishAt!),
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                    if (n.endAt != null)
                      Text(
                        '~ ${formatDateTime(n.endAt!)}',
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                  ],
                ),
                if (!canEdit)
                  const SizedBox.shrink()
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '수정',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _open(n),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip: n.status == NoticeStatus.published ? '게시 중단' : '지금 게시',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _togglePublished(n),
                        icon: Icon(
                          n.status == NoticeStatus.published ? Icons.visibility_off_outlined : Icons.publish,
                          size: 18,
                        ),
                      ),
                      IconButton(
                        tooltip: n.pinned ? '고정 해제' : '상단 고정',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => n.pinned = !n.pinned),
                        icon: Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip: '삭제',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _delete(n),
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.up),
                      ),
                    ],
                  ),
              ],
          ],
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.label, this.value, this.onChanged);

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: value, onChanged: onChanged),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
