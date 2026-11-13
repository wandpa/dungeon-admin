import 'package:flutter/material.dart';

import '../deep_link.dart';
import '../file_pick.dart';
import '../live_admin.dart';
import '../live_api.dart' show LiveApiException;
import '../mock_accounts.dart';
import '../mock_admin.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/deep_link_field.dart';

/// 이미지 한 장의 최대 크기와 공지 하나에 붙일 수 있는 장수.
const _maxImageBytes = 5 * 1024 * 1024;
const _maxImages = 10;

/// 이 화면에서 고른 이미지는 내용으로, 서버에서 받은 이미지는 주소로 그린다.
Widget _image(NoticeImage img, {double? width, double? height, BoxFit fit = BoxFit.contain}) {
  final bytes = img.bytes;
  if (bytes != null) return Image.memory(bytes, width: width, height: height, fit: fit);
  return Image.network(
    img.url ?? '',
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, _, _) => SizedBox(
      width: width ?? 120,
      height: height ?? 80,
      child: const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary)),
    ),
  );
}

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
  final _images = <NoticeImage>[];
  DeepLink _link = DeepLink.none; // 본문 아래 버튼이 열 곳

  // 테스트 DB 화면은 관리자 API 의 공지 목업 저장소를 쓴다.
  List<Notice> _live = [];
  bool _loading = false;
  bool _busy = false; // 저장·업로드 중
  String? _error;

  bool get _isLive => useLiveData.value;
  List<Notice> get _all => _isLive ? _live : mockNotices;

  @override
  void initState() {
    super.initState();
    if (_isLive) _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await loadLiveNotices();
      if (!mounted) return;
      setState(() => _live = list);
    } on LiveApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// API 요청을 보내고 실패하면 서버 안내를 띄운다. 성공하면 true.
  Future<bool> _call(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } on LiveApiException catch (e) {
      if (mounted) showMessage(context, e.message);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
      for (final n in _all)
        if ((_status == null || n.status == _status) &&
            (q.isEmpty || n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q)))
          n,
    ]..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  int _count(NoticeStatus? s) => s == null ? _all.length : _all.where((n) => n.status == s).length;

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
    _images
      ..clear()
      ..addAll(n?.images ?? const []);
    _link = n?.link ?? DeepLink.none;
  });

  void _close() => setState(() {
    _editing = false;
    _target = null;
  });

  bool get _valid => _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty && _link.error == null;

  /// 버튼으로 연결할 수 있는 다른 공지. 게시 중인 것만, 자기 자신은 뺀다.
  List<(int, String)> get _linkableNotices => [
    for (final n in _all)
      if (n.status == NoticeStatus.published && n.id != _target?.id) (n.id, n.title),
  ];

  String _noticeTitle(int id) {
    for (final n in _all) {
      if (n.id == id) return n.title;
    }
    return '#$id';
  }

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
          images: [..._images],
          link: _link,
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
        ..endAt = _endAt
        ..images = [..._images]
        ..link = _link;
    }
  }

  /// 이미지를 고른다. 너무 크거나 장수를 넘는 것은 빼고 알려 준다.
  Future<void> _addImages() async {
    final picked = await pickImages();
    if (picked.isEmpty || !mounted) return;
    final skipped = <String>[];
    final ok = <PickedFile>[];
    for (final f in picked) {
      if (f.bytes.length > _maxImageBytes) {
        skipped.add('${f.name}(5MB 초과)');
      } else if (_images.length + ok.length >= _maxImages) {
        skipped.add('${f.name}($_maxImages장 초과)');
      } else {
        ok.add(f);
      }
    }
    if (_isLive) {
      // 서버에 먼저 올려 id 를 받고, 저장할 때 그 id 를 보낸다.
      for (final f in ok) {
        final sent = await _call(() async {
          final img = await uploadLiveNoticeImage(f.name, f.bytes);
          if (mounted) setState(() => _images.add(img));
        });
        if (!sent) skipped.add('${f.name}(올리지 못함)');
      }
    } else {
      setState(() => _images.addAll([for (final f in ok) NoticeImage(f.name, f.bytes)]));
    }
    if (!mounted) return;
    if (skipped.isNotEmpty) showMessage(context, '빼고 올렸습니다: ${skipped.join(', ')}');
  }

  Map<String, Object?> _request(String status, {bool notifyPush = false}) => noticeRequest(
    title: _title.text.trim(),
    body: _body.text.trim(),
    category: _category,
    grades: _grades,
    pinned: _pinned,
    popup: _popup,
    publishAt: _publishAt,
    endAt: _endAt,
    status: status,
    notifyPush: notifyPush,
    images: _images,
    link: _link,
  );

  /// 서버 목업에 저장하고 목록을 다시 받는다.
  Future<void> _saveLive(String status, String done, {bool notifyPush = false}) async {
    final ok = await _call(() => saveLiveNotice(_target?.id, _request(status, notifyPush: notifyPush)));
    if (!ok || !mounted) return;
    setState(() {
      _editing = false;
      _target = null;
    });
    showMessage(context, done);
    await _reload();
  }

  void _saveDraft() {
    if (_isLive) {
      _publishAt = null;
      _saveLive('draft', '임시저장했습니다.');
      return;
    }
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
    final receivers = _isLive ? <Member>[] : pushableMembers().where((m) => pushBlockReason(m) == null).toList();
    final title = _title.text.trim();
    final ok = await showConfirmDialog(
      context,
      title: scheduled ? '예약 게시' : '공지 게시',
      message: scheduled
          ? '「$title」을(를) ${formatDateTime(_publishAt!)}에 게시합니다.'
          : '「$title」을(를) 사용자에게 게시합니다.${!_notifyPush
                ? ''
                : _isLive
                ? '\n푸시 발송 요청을 기록합니다(목업이라 실제로 보내지 않습니다).'
                : '\n${receivers.length}명에게 푸시도 보냅니다.'}',
      confirmText: scheduled ? '예약' : '게시',
    );
    if (!ok || !mounted) return;
    final push = _notifyPush && !scheduled;
    if (_isLive) {
      return _saveLive(
        'published',
        scheduled ? '게시를 예약했습니다.' : (push ? '게시하고 푸시 발송 요청을 기록했습니다.' : '게시했습니다.'),
        notifyPush: push,
      );
    }
    setState(() {
      _write(scheduled ? NoticeStatus.scheduled : NoticeStatus.published);
      logActivity(ActivityKind.notice, '「$title」 ${scheduled ? '게시 예약' : '게시'}');
      if (push) {
        final id = _target?.id ?? mockNotices.last.id;
        sendPush(title, _body.text.trim(), '전체', receivers, link: DeepLink(DeepLinkType.notice, target: '$id'));
      }
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
    if (_isLive) {
      if (!await _call(() => setLiveNoticePublished(n.id, !live)) || !mounted) return;
      showMessage(context, live ? '게시를 중단했습니다.' : '게시했습니다.');
      return _reload();
    }
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
    if (_isLive) {
      if (!await _call(() => deleteLiveNotice(n.id)) || !mounted) return;
      if (_target?.id == n.id) _close();
      showMessage(context, '삭제했습니다.');
      return _reload();
    }
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
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
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
          decoration: const InputDecoration(labelText: '제목'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _body,
          onChanged: (_) => setState(() {}),
          minLines: 6,
          maxLines: 12,
          decoration: const InputDecoration(labelText: '내용', alignLabelWithHint: true),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final img in _images)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _image(img, width: 88, height: 88, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: InkWell(
                      onTap: () => setState(() => _images.remove(img)),
                      child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (_images.length < _maxImages)
              OutlinedButton.icon(
                onPressed: _busy ? null : _addImages,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text('이미지 첨부 ${_images.length}/$_maxImages'),
              ),
            const Text('PNG·JPG·GIF·WEBP, 장당 5MB까지', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        const Text('버튼 연결', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        DeepLinkField(
          value: _link,
          notices: _linkableNotices,
          showButtonLabel: true,
          onChanged: (v) => setState(() => _link = v),
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
            OutlinedButton(onPressed: _valid && !_busy ? _saveDraft : null, child: const Text('임시저장')),
            FilledButton(
              onPressed: _valid && !_busy ? _publish : null,
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
            style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _title.text.trim().isEmpty ? '제목' : _title.text.trim(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            '${n?.author ?? currentAdmin} · ${formatDateTime(_publishAt ?? n?.createdAt ?? DateTime.now())}',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(_body.text.trim().isEmpty ? '내용' : _body.text.trim()),
          // 앱 화면 폭에 맞춰 보이고, 긴 이미지는 높이를 잘라 미리보기가 너무 길어지지 않게 한다.
          for (final img in _images) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360, maxHeight: 360),
                child: _image(img),
              ),
            ),
          ],
          // 앱 공지 화면 맨 아래 버튼. 누르면 고른 화면·공지·웹 주소를 연다.
          if (!_link.isNone) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: 360,
              child: FilledButton(
                onPressed: null,
                style: FilledButton.styleFrom(
                  disabledBackgroundColor: AppColors.brand,
                  disabledForegroundColor: Colors.white,
                ),
                child: Text(_link.label?.trim().isNotEmpty == true ? _link.label!.trim() : '자세히 보기'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _link.describe(noticeTitle: _noticeTitle),
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ],
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
        if (_isLive)
          const SampleNotice('공지 API 목업에 저장합니다. DB 연결 전이라 API 를 다시 켜면 사라지고, 회원 앱에는 보이지 않으며 푸시도 실제로 보내지 않습니다.'),
        if (_isLive && _loading) const LinearProgressIndicator(),
        if (_isLive && _error != null)
          Text('$_error API 서버가 실행 중인지 확인하세요.', style: const TextStyle(color: AppColors.danger)),
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
                      Text(n.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (n.popup) ...[const SizedBox(width: 6), const StatusBadge('팝업', color: AppColors.brand)],
                      if (!n.link.isNone) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: n.link.describe(noticeTitle: _noticeTitle),
                          excludeFromSemantics: true,
                          child: const Icon(Icons.link, size: 16, color: AppColors.textTertiary),
                        ),
                      ],
                      if (n.images.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.image_outlined, size: 16, color: AppColors.textTertiary),
                        Text(
                          ' ${n.images.length}',
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        ),
                      ],
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
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    if (n.endAt != null)
                      Text(
                        '~ ${formatDateTime(n.endAt!)}',
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
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
                        onPressed: () async {
                          if (!_isLive) return setState(() => n.pinned = !n.pinned);
                          if (await _call(() => setLiveNoticePinned(n.id, !n.pinned))) await _reload();
                        },
                        icon: Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip: '삭제',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _delete(n),
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
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
