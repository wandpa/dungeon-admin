import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_admin.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'live_view.dart';

final _time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// 시간 칸 검사. [sameDay] 면 종료가 시작보다 늦어야 한다. 해외선물은 다음 날로 넘어갈 수 있다.
String? timeProblem(String label, String open, String close, {required bool sameDay}) {
  if (!_time.hasMatch(open) || !_time.hasMatch(close)) return '$label 시간은 09:00 형식으로 입력하세요.';
  if (sameDay && close.compareTo(open) <= 0) return '$label 장 종료는 장 시작보다 늦어야 합니다.';
  return null;
}

/// 특정일 줄 검사. 문제가 없으면 null.
String? specialDaysProblem(List<SpecialRow> rows, {required bool sameDay}) {
  final seen = <String>{};
  for (final r in rows) {
    final date = r.date;
    if (date == null) return '특정일 날짜를 고르세요.';
    final day = _day(date);
    if (!seen.add(day)) return '$day 이 두 번 입력되었습니다.';
    if (r.reason.text.trim().isEmpty) return '$day 사유를 입력하세요.';
    final time = timeProblem(day, r.open.text.trim(), r.close.text.trim(), sameDay: sameDay);
    if (time != null) return time;
  }
  return null;
}

String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 특정일 한 줄.
class SpecialRow {
  SpecialRow({this.date, String? reason, String? open, String? close})
    : reason = TextEditingController(text: reason),
      open = TextEditingController(text: open),
      close = TextEditingController(text: close);

  DateTime? date;
  final TextEditingController reason;
  final TextEditingController open;
  final TextEditingController close;

  void dispose() {
    reason.dispose();
    open.dispose();
    close.dispose();
  }
}

/// 특정일 변경 칸: 날짜, 사유, 장 시작, 장 종료. 국내와 해외선물이 함께 쓴다.
class SpecialDaysEditor extends StatelessWidget {
  const SpecialDaysEditor({
    super.key,
    required this.rows,
    required this.editable,
    required this.onChanged,
    this.defaultOpen = '',
    this.defaultClose = '',
  });

  final List<SpecialRow> rows;
  final bool editable;
  final VoidCallback onChanged;
  final String defaultOpen; // 새 줄에 채워 둘 시간
  final String defaultClose;

  Future<void> _pickDate(BuildContext context, SpecialRow row) async {
    final picked = await showDatePicker(
      context: context,
      helpText: '특정일',
      initialDate: row.date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      row.date = picked;
      onChanged();
    }
  }

  Widget _field(TextEditingController controller, String hint) => TextField(
    controller: controller,
    enabled: editable,
    onChanged: (_) => onChanged(),
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(hintText: hint),
  );

  Widget _row(BuildContext context, SpecialRow r) {
    final date = r.date;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                foregroundColor: AppColors.textPrimary,
              ),
              onPressed: editable ? () => _pickDate(context, r) : null,
              child: Text(date == null ? '날짜 선택' : _day(date), style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: _field(r.reason, '사유')),
          const SizedBox(width: 4),
          SizedBox(width: 68, child: _field(r.open, '09:00')),
          const SizedBox(width: 4),
          SizedBox(width: 68, child: _field(r.close, '15:35')),
          IconButton(
            tooltip: '특정일 삭제',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: !editable
                ? null
                : () {
                    rows.remove(r);
                    r.dispose();
                    onChanged();
                  },
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('특정일 변경', style: head)),
            TextButton.icon(
              onPressed: !editable
                  ? null
                  : () {
                      rows.add(SpecialRow(open: defaultOpen, close: defaultClose));
                      onChanged();
                    },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('특정일 추가'),
            ),
          ],
        ),
        if (rows.isEmpty)
          const Text('등록된 특정일이 없습니다.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12))
        else
          for (final r in rows) _row(context, r),
      ],
    );
  }
}

/// 국내주식 장 시간. 기본 시간과 수능일처럼 시간이 바뀌는 특정일을 입력한다.
/// 저장 API 가 없어 지금은 안내만 한다.
class LiveMarketHours extends StatelessWidget {
  const LiveMarketHours({super.key});

  @override
  Widget build(BuildContext context) {
    return LiveLoader<Map<String, dynamic>>(
      load: () async => await liveGet('/system/markets') as Map<String, dynamic>,
      builder: (context, body) => _HoursForm(body),
    );
  }
}

class _HoursForm extends StatefulWidget {
  const _HoursForm(this.body);

  final Map<String, dynamic> body;

  @override
  State<_HoursForm> createState() => _HoursFormState();
}

class _HoursFormState extends State<_HoursForm> {
  final _open = TextEditingController();
  final _close = TextEditingController();
  final _rows = <SpecialRow>[];

  bool get _editable => can(AdminPermission.manageSymbols);

  List<Map<String, dynamic>> _list(String key) => (widget.body[key] as List? ?? const []).cast<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    _fill();
  }

  /// 날짜 없는 줄이 기본 시간이다. 없으면 오늘 국내주식 세션으로 채운다.
  void _fill() {
    final days = _list('specialDays');
    final base = days.where((d) => d['date'] == null).firstOrNull;
    final today = _list('markets').where((m) => m['marketType'] == 'DomesticStock').firstOrNull;
    _open.text = (base?['amOpen'] ?? today?['openTime']) as String? ?? '';
    _close.text = (base?['amClose'] ?? today?['closeTime']) as String? ?? '';
    for (final r in _rows) {
      r.dispose();
    }
    _rows
      ..clear()
      ..addAll([
        for (final d in days)
          if (d['date'] != null)
            SpecialRow(
              date: DateTime.tryParse(d['date'] as String),
              reason: d['reason'] as String? ?? d['name'] as String?,
              open: d['amOpen'] as String?,
              close: d['amClose'] as String?,
            ),
      ]);
  }

  @override
  void dispose() {
    _open.dispose();
    _close.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  /// 문제가 없으면 null.
  String? get _problem =>
      timeProblem('기본', _open.text.trim(), _close.text.trim(), sameDay: true) ??
      specialDaysProblem(_rows, sameDay: true);

  Widget _field(TextEditingController controller, {String hint = '-'}) => TextField(
    controller: controller,
    enabled: _editable,
    onChanged: (_) => setState(() {}),
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(hintText: hint),
  );

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    const head = TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700);
    final holidays = _list('holidays');
    return Panel(
      title: '국내주식 장 시간',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('KOSPI · KOSDAQ 공통, 한국 시간', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 64, child: Text('기본', style: head)),
              Expanded(child: _field(_open, hint: '장 시작')),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('~')),
              Expanded(child: _field(_close, hint: '장 종료')),
            ],
          ),
          const SizedBox(height: 12),
          SpecialDaysEditor(
            rows: _rows,
            editable: _editable,
            defaultOpen: _open.text.trim(),
            defaultClose: _close.text.trim(),
            onChanged: () => setState(() {}),
          ),
          if (holidays.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('휴장일', style: head),
            const SizedBox(height: 2),
            Text(
              [for (final h in holidays) '${h['date']} ${h['name']}'].join(' · '),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            problem ?? '저장 API 연결 전입니다. 입력한 값은 저장되지 않습니다.',
            style: TextStyle(color: problem == null ? AppColors.warning : AppColors.up, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: _editable ? () => setState(_fill) : null, child: const Text('되돌리기')),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: _editable && problem == null ? () => showNotConnected(context) : null,
                child: const Text('저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
