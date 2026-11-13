import 'package:flutter/material.dart';

import '../deep_link.dart';
import '../theme.dart';

/// 딥링크 고르기. 연결 종류 → 화면·공지·주소 순서로 고른다.
/// 앱 경로는 직접 적지 않고 [appScreens] 에서만 고른다.
class DeepLinkField extends StatefulWidget {
  const DeepLinkField({
    super.key,
    required this.value,
    required this.onChanged,
    this.notices = const [],
    this.showButtonLabel = false,
  });

  final DeepLink value;
  final ValueChanged<DeepLink> onChanged;

  /// 연결할 수 있는 공지(번호, 제목). 비어 있으면 '공지' 종류를 고를 수 없다.
  final List<(int, String)> notices;

  /// 공지 본문 아래 버튼 글자를 받는다(공지 작성 화면).
  final bool showButtonLabel;

  @override
  State<DeepLinkField> createState() => _DeepLinkFieldState();
}

class _DeepLinkFieldState extends State<DeepLinkField> {
  late final _url = TextEditingController(text: widget.value.type == DeepLinkType.url ? widget.value.target : '');
  late final _label = TextEditingController(text: widget.value.label ?? '');

  @override
  void didUpdateWidget(DeepLinkField old) {
    super.didUpdateWidget(old);
    // 밖에서 값을 바꾸면(다른 공지를 열 때) 글자 칸도 맞춘다.
    final v = widget.value;
    final url = v.type == DeepLinkType.url ? (v.target ?? '') : '';
    if (v.type == DeepLinkType.url && _url.text != url) _url.text = url;
    if ((v.label ?? '') != _label.text) _label.text = v.label ?? '';
  }

  @override
  void dispose() {
    _url.dispose();
    _label.dispose();
    super.dispose();
  }

  void _set(DeepLinkType type, String? target) =>
      widget.onChanged(type == DeepLinkType.none ? DeepLink.none : DeepLink(type, target: target, label: _label.text));

  void _pickType(DeepLinkType t) {
    if (t == widget.value.type) return;
    _set(t, switch (t) {
      DeepLinkType.none => null,
      DeepLinkType.screen => appScreens.first.path,
      DeepLinkType.notice => widget.notices.isEmpty ? null : '${widget.notices.first.$1}',
      DeepLinkType.url => _url.text.trim(),
    });
  }

  Widget _chip(String label, bool selected, VoidCallback? onTap) => ChoiceChip(
    label: Text(label, style: const TextStyle(fontSize: 13)),
    visualDensity: VisualDensity.compact,
    selected: selected,
    onSelected: onTap == null ? null : (_) => onTap(),
  );

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final error = v.error;
    final screen = appScreenOf(v.target);
    final path = v.pushData['path'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in DeepLinkType.values)
              _chip(
                t.label,
                t == v.type,
                t == DeepLinkType.notice && widget.notices.isEmpty ? null : () => _pickType(t),
              ),
          ],
        ),
        if (v.type == DeepLinkType.screen) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in appScreens)
                _chip(s.ready ? s.label : '${s.label} (앱 업데이트 후)', s.path == v.target, () => _set(v.type, s.path)),
            ],
          ),
        ],
        if (v.type == DeepLinkType.notice) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: widget.notices.any((n) => n.$1 == v.noticeId) ? v.noticeId : null,
            isExpanded: true,
            decoration: const InputDecoration(hintText: '연결할 공지'),
            items: [
              for (final (id, title) in widget.notices)
                DropdownMenuItem(
                  value: id,
                  child: Text('#$id $title', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => _set(v.type, id == null ? null : '$id'),
          ),
        ],
        if (v.type == DeepLinkType.url) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            onChanged: (s) => _set(v.type, s.trim()),
            decoration: const InputDecoration(hintText: 'https://'),
          ),
        ],
        if (widget.showButtonLabel && !v.isNone) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _label,
            maxLength: 20,
            onChanged: (s) => widget.onChanged(DeepLink(v.type, target: v.target, label: s)),
            decoration: const InputDecoration(hintText: '버튼 글자 (비우면 「자세히 보기」)', counterText: ''),
          ),
        ],
        if (!v.isNone) ...[
          const SizedBox(height: 6),
          Text(
            error ??
                switch (v.type) {
                  DeepLinkType.url => '앱 밖 브라우저로 엽니다. 예전 앱은 알림함을 엽니다.',
                  DeepLinkType.notice => '앱에서 $path 를 엽니다. 공지 화면이 없는 지금 앱은 알림함을 엽니다.',
                  _ when screen != null && !screen.ready => '앱에서 $path 를 엽니다. 이 화면이 없는 지금 앱은 알림함을 엽니다.',
                  _ => '앱에서 $path 를 엽니다.',
                },
            style: TextStyle(color: error == null ? AppColors.textTertiary : AppColors.danger, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
