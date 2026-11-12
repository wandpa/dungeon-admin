import 'package:flutter/material.dart';

import '../mock_admin.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

/// 앱의 회원 등급(MembershipTier) 이름.

/// 이름표 + 값 한 칸. [full] 이면 한 줄을 다 쓴다.
class FormCell extends StatelessWidget {
  const FormCell(this.label, this.value, {super.key, this.full = false});

  final String label;
  final Widget value;
  final bool full;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(border: Border.all(color: AppColors.grid, width: 0.5)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 92,
              color: AppColors.strip,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 칸을 두 줄로 늘어놓는다. 좁으면 한 줄씩 쌓는다.
class FormGrid extends StatelessWidget {
  const FormGrid({super.key, required this.cells});

  final List<FormCell> cells;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final half = width >= 560 ? width / 2 : width;
        return Wrap(
          children: [for (final c in cells) SizedBox(width: c.full ? width : half, child: c)],
        );
      },
    );
  }
}

/// 회원 정보 칸. [infoCells] 는 조회만 하는 값이고 그 아래가 수정 칸이다.
/// 저장 API 가 없어 지금은 입력 모양만 있고 값은 어디에도 남지 않는다.
class MemberEditPanel extends StatefulWidget {
  const MemberEditPanel(this.member, {super.key, this.infoCells = const []});

  final Member member;
  final List<FormCell> infoCells;

  @override
  State<MemberEditPanel> createState() => _MemberEditPanelState();
}

class _MemberEditPanelState extends State<MemberEditPanel> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _memo = TextEditingController();
  late final _blockReason = TextEditingController(text: widget.member.accessBlockReason);
  late String? _grade = widget.member.gradeLabel;
  DateTime? _startsOn;
  DateTime? _expiresOn;
  late bool _blocked = widget.member.accessBlocked;

  bool get _editable => can(AdminPermission.memberActions) && !widget.member.isLive;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _memo.dispose();
    _blockReason.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _name.clear();
    _phone.clear();
    _memo.clear();
    _blockReason.text = widget.member.accessBlockReason ?? '';
    _grade = widget.member.gradeLabel;
    _startsOn = null;
    _expiresOn = null;
    _blocked = widget.member.accessBlocked;
  });

  Widget _text(TextEditingController controller, {String? hint, int maxLines = 1}) => TextField(
    controller: controller,
    enabled: _editable,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(hintText: hint ?? '-'),
  );

  Widget _date(String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: AppColors.textPrimary),
            onPressed: !_editable
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      helpText: label,
                      initialDate: value ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) onChanged(picked);
                  },
            icon: const Icon(Icons.calendar_today, size: 14),
            label: Text(value == null ? '-' : day(value)),
          ),
        ),
        if (value != null)
          IconButton(
            tooltip: '$label 지우기',
            visualDensity: VisualDensity.compact,
            onPressed: !_editable ? null : () => onChanged(null),
            icon: const Icon(Icons.close, size: 16),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: '회원 정보',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormGrid(
            cells: [
              ...widget.infoCells,
              // 테스트 DB 이름은 가려져 오므로 고칠 값으로 쓰지 않는다.
              FormCell('이름', widget.member.isLive ? Text(widget.member.maskedName ?? '-') : _text(_name)),
              FormCell('휴대폰', _text(_phone)),
              FormCell(
                '회원등급',
                DropdownButtonFormField<String>(
                  key: ValueKey(_grade),
                  initialValue: _grade,
                  hint: const Text('-', style: TextStyle(fontSize: 13)),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  items: [for (final g in memberGrades) DropdownMenuItem(value: g, child: Text(g))],
                  onChanged: _editable ? (v) => setState(() => _grade = v) : null,
                ),
              ),
              FormCell('회원 상태', Text(widget.member.status.label)),
              FormCell('시작일자', _date('시작일자', _startsOn, (v) => setState(() => _startsOn = v))),
              FormCell('만료일자', _date('만료일자', _expiresOn, (v) => setState(() => _expiresOn = v))),
              FormCell(
                '접속 차단',
                Row(
                  children: [
                    Switch(value: _blocked, onChanged: _editable ? (v) => setState(() => _blocked = v) : null),
                    const SizedBox(width: 6),
                    Text(_blocked ? '차단' : '허용'),
                  ],
                ),
              ),
              FormCell('차단 사유', _text(_blockReason)),
              FormCell('메모', _text(_memo, maxLines: 3), full: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.member.isLive
                      ? '저장 API 연결 전이라 고칠 수 없습니다.'
                      : '저장 API 연결 전입니다. 입력한 값은 저장되지 않습니다.',
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ),
              OutlinedButton(onPressed: _editable ? _reset : null, child: const Text('되돌리기')),
              const SizedBox(width: 6),
              FilledButton(onPressed: _editable ? () => showNotConnected(context) : null, child: const Text('저장')),
            ],
          ),
        ],
      ),
    );
  }
}
