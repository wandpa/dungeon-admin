import 'package:flutter/material.dart';

import '../mock_admin.dart';
import '../mock_data.dart';
import '../mock_symbols.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _monthPattern = RegExp(r'^\d{4}(0[1-9]|1[0-2])$');
final _codePattern = RegExp(r'^[A-Za-z0-9]+$');
final _timeZonePattern = RegExp(r'^[A-Za-z_]+/[A-Za-z_]+$');
final _breakPattern = RegExp(r'^\d{2}:\d{2}-\d{2}:\d{2}(, \d{2}:\d{2}-\d{2}:\d{2})*$');
final _holidayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}(, \d{4}-\d{2}-\d{2})*$');

String _day(DateTime d) => formatDateTime(d).split(' ').first;

String _plain(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

/// 일괄 적용할 수 있는 항목.
class _BulkField {
  _BulkField(this.label, this.hint, this.read, this.write, {this.isTime = true, this.optional = false});

  final String label;
  final String hint;
  final String Function(MasterSymbol) read;
  final void Function(MasterSymbol, String) write;
  final bool isTime; // 09:00 형식 검사
  final bool optional; // 비워서 지울 수 있다
  final controller = TextEditingController();
  bool on = false;
}

/// 앱과 같이 상품 아래 월물이 있다. 상품은 틱 값과 거래 시간을, 월물은 종목코드와 만기를 가진다.
class SymbolMasterPage extends StatefulWidget {
  const SymbolMasterPage({super.key});

  @override
  State<SymbolMasterPage> createState() => _SymbolMasterPageState();
}

class _SymbolMasterPageState extends State<SymbolMasterPage> {
  static const _filters = ['전체', ...marketTypes];

  String _query = '';
  int _filter = 0;

  MasterSymbol? _selected; // 월물 테이블을 보는 상품
  bool _editing = false;
  MasterSymbol? _target; // 수정 중인 상품. 새 상품이면 null
  String _marketType = marketTypes.first;
  String _currency = currencies.first;
  bool _active = true;

  final _code = TextEditingController();
  final _name = TextEditingController();
  final _exchange = TextEditingController();
  final _tickSize = TextEditingController();
  final _tickValue = TextEditingController();
  final _sessionOpen = TextEditingController();
  final _sessionClose = TextEditingController();
  final _orderOpen = TextEditingController();
  final _orderClose = TextEditingController();
  final _timeZone = TextEditingController();
  final _breakTime = TextEditingController();
  final _autoClose = TextEditingController();
  final _holidays = TextEditingController();

  final _checked = <MasterSymbol>{}; // 일괄 적용 대상
  String _dstRule = dstRules.first;
  final _bulk = [
    _BulkField('장 시작', '08:45', (s) => s.sessionOpen, (s, v) => s.sessionOpen = v),
    _BulkField('장 종료', '15:45', (s) => s.sessionClose, (s, v) => s.sessionClose = v),
    _BulkField('주문 가능 시작', '08:30', (s) => s.orderOpen, (s, v) => s.orderOpen = v),
    _BulkField('주문 가능 종료', '15:45', (s) => s.orderClose, (s, v) => s.orderClose = v),
    _BulkField(
      '장 마감 자동 청산',
      '15:25',
      (s) => s.autoCloseAt ?? '',
      (s, v) => s.autoCloseAt = v.isEmpty ? null : v,
      optional: true,
    ),
    _BulkField('휴식 구간', '12:00-13:00', (s) => s.breakTime, (s, v) => s.breakTime = v, isTime: false, optional: true),
    _BulkField('휴장일', '2026-12-25', (s) => s.holidays, (s, v) => s.holidays = v, isTime: false, optional: true),
  ];

  ContractMonth? _monthTarget; // 수정 중인 월물. 새 월물이면 null
  final _monthCode = TextEditingController();
  final _monthValue = TextEditingController();
  final _monthExpiry = TextEditingController();
  final _monthOpen = TextEditingController();
  final _monthClose = TextEditingController();

  List<TextEditingController> get _all => [
    _code,
    _name,
    _exchange,
    _tickSize,
    _tickValue,
    _sessionOpen,
    _sessionClose,
    _orderOpen,
    _orderClose,
    _timeZone,
    _breakTime,
    _autoClose,
    _holidays,
    _monthCode,
    _monthValue,
    _monthExpiry,
    _monthOpen,
    _monthClose,
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    for (final f in _bulk) {
      f.controller.dispose();
    }
    super.dispose();
  }

  List<MasterSymbol> get _visible {
    final q = _query.trim().toLowerCase();
    return [
      for (final s in mockSymbols)
        if ((_filter == 0 || s.marketType == _filters[_filter]) &&
            (q.isEmpty ||
                s.productCode.toLowerCase().contains(q) ||
                s.name.toLowerCase().contains(q) ||
                s.months.any((m) => m.code.toLowerCase().contains(q))))
          s,
    ];
  }

  int _count(int i) => mockSymbols.where((s) => i == 0 || s.marketType == _filters[i]).length;

  void _clearMonthForm() {
    _monthTarget = null;
    _monthCode.clear();
    _monthValue.clear();
    _monthExpiry.clear();
    _monthOpen.clear();
    _monthClose.clear();
  }

  void _select(MasterSymbol s) => setState(() {
    _selected = s;
    _clearMonthForm();
  });

  void _open(MasterSymbol? s) => setState(() {
    _editing = true;
    _target = s;
    if (s != null) _selected = s;
    _marketType = s?.marketType ?? marketTypes.first;
    _currency = s?.currency ?? currencies.first;
    _dstRule = s?.dstRule ?? dstRules.first;
    _active = s?.active ?? true;
    _code.text = s?.productCode ?? '';
    _name.text = s?.name ?? '';
    _exchange.text = s?.exchange ?? '';
    _tickSize.text = s == null ? '' : _plain(s.tickSize);
    _tickValue.text = s == null ? '' : _plain(s.tickValue);
    _sessionOpen.text = s?.sessionOpen ?? '';
    _sessionClose.text = s?.sessionClose ?? '';
    _orderOpen.text = s?.orderOpen ?? '';
    _orderClose.text = s?.orderClose ?? '';
    _timeZone.text = s?.timeZone ?? '';
    _breakTime.text = s?.breakTime ?? '';
    _autoClose.text = s?.autoCloseAt ?? '';
    _holidays.text = s?.holidays ?? '';
  });

  void _close() => setState(() {
    _editing = false;
    _target = null;
  });

  /// 입력의 문제. 없으면 null.
  String? get _error {
    final code = _code.text.trim();
    if (code.isEmpty || _name.text.trim().isEmpty || _exchange.text.trim().isEmpty) {
      return '상품코드, 상품명, 거래소를 입력하세요.';
    }
    if (!_codePattern.hasMatch(code)) return '상품코드는 영문과 숫자만 씁니다.';
    if (_target == null && mockSymbols.any((s) => s.productCode == code)) return '이미 있는 상품코드입니다.';
    final size = double.tryParse(_tickSize.text.trim());
    final value = double.tryParse(_tickValue.text.trim());
    if (size == null || size <= 0 || value == null || value <= 0) return '틱 크기와 틱 가치는 0보다 큰 숫자여야 합니다.';
    final times = [_sessionOpen, _sessionClose, _orderOpen, _orderClose];
    if (times.any((c) => !_timePattern.hasMatch(c.text.trim()))) return '시간은 09:00 형식으로 입력하세요.';
    final auto = _autoClose.text.trim();
    if (auto.isNotEmpty && !_timePattern.hasMatch(auto)) return '자동 청산 시각은 09:00 형식으로 입력하세요.';
    if (!_timeZonePattern.hasMatch(_timeZone.text.trim())) return '타임존은 Asia/Seoul 형식으로 입력하세요.';
    final breaks = _breakTime.text.trim();
    if (breaks.isNotEmpty && !_breakPattern.hasMatch(breaks)) return '휴식 구간은 12:00-13:00 형식으로 입력하세요.';
    final holidays = _holidays.text.trim();
    if (holidays.isNotEmpty && !_holidayPattern.hasMatch(holidays)) return '휴장일은 2026-12-25, 2026-12-31 형식으로 입력하세요.';
    return null;
  }

  /// 저장할 때 달라지는 항목. 확인창과 활동 기록에 그대로 쓴다.
  List<String> _changes(MasterSymbol s) {
    final changes = <String>[];
    void check(String label, String before, String after) {
      if (before != after) changes.add('$label ${before.isEmpty ? '없음' : before} → ${after.isEmpty ? '없음' : after}');
    }

    check('상품명', s.name, _name.text.trim());
    check('거래소', s.exchange, _exchange.text.trim());
    check('통화', s.currency, _currency);
    check('틱 크기', _plain(s.tickSize), _plain(double.parse(_tickSize.text.trim())));
    check('틱 가치', _plain(s.tickValue), _plain(double.parse(_tickValue.text.trim())));
    check('장 시작', s.sessionOpen, _sessionOpen.text.trim());
    check('장 종료', s.sessionClose, _sessionClose.text.trim());
    check('주문 시작', s.orderOpen, _orderOpen.text.trim());
    check('주문 종료', s.orderClose, _orderClose.text.trim());
    check('타임존', s.timeZone, _timeZone.text.trim());
    check('서머타임', s.dstRule, _dstRule);
    check('휴식 구간', s.breakTime, _breakTime.text.trim());
    check('자동 청산', s.autoCloseAt ?? '', _autoClose.text.trim());
    check('휴장일', s.holidays, _holidays.text.trim());
    check('사용', s.active ? '사용' : '중지', _active ? '사용' : '중지');
    return changes;
  }

  void _apply(MasterSymbol s) {
    final auto = _autoClose.text.trim();
    s
      ..name = _name.text.trim()
      ..exchange = _exchange.text.trim()
      ..currency = _currency
      ..tickSize = double.parse(_tickSize.text.trim())
      ..tickValue = double.parse(_tickValue.text.trim())
      ..sessionOpen = _sessionOpen.text.trim()
      ..sessionClose = _sessionClose.text.trim()
      ..orderOpen = _orderOpen.text.trim()
      ..orderClose = _orderClose.text.trim()
      ..timeZone = _timeZone.text.trim()
      ..dstRule = _dstRule
      ..breakTime = _breakTime.text.trim()
      ..autoCloseAt = auto.isEmpty ? null : auto
      ..holidays = _holidays.text.trim()
      ..active = _active;
  }

  Future<void> _save() async {
    final target = _target;
    if (target == null) {
      final created = MasterSymbol(
        productCode: _code.text.trim(),
        name: '',
        marketType: _marketType,
        exchange: '',
        currency: _currency,
        tickSize: 1,
        tickValue: 1,
        sessionOpen: '',
        sessionClose: '',
        orderOpen: '',
        orderClose: '',
        timeZone: '',
      );
      setState(() {
        _apply(created);
        mockSymbols.add(created);
        logSymbolChange('${created.productCode} ${created.name} 상품 추가');
        _selected = created;
        _editing = false;
      });
      showMessage(context, '상품을 추가했습니다. 월물을 등록하세요.');
      return;
    }

    final changes = _changes(target);
    if (changes.isEmpty) {
      _close();
      return;
    }
    final workers = workersOnProduct(target);
    final ok = await showConfirmDialog(
      context,
      title: '${target.productCode} 변경',
      message: [...changes, if (workers > 0) '\n이 상품을 쓰는 워커 $workers개의 주문과 청산에 바로 적용됩니다.'].join('\n'),
      confirmText: '저장',
      destructive: workers > 0,
    );
    if (!ok || !mounted) return;
    setState(() {
      _apply(target);
      logSymbolChange('${target.productCode} ${changes.join(', ')}');
      _editing = false;
      _target = null;
    });
    showMessage(context, '저장했습니다.');
  }

  String? _monthError(MasterSymbol s) {
    final code = _monthCode.text.trim();
    if (code.isEmpty && _monthValue.text.trim().isEmpty && _monthExpiry.text.trim().isEmpty) return '';
    if (!_codePattern.hasMatch(code)) return '종목코드는 영문과 숫자만 씁니다.';
    final isNew = _monthTarget == null;
    if (isNew && mockSymbols.any((p) => p.months.any((m) => m.code == code))) return '이미 있는 종목코드입니다.';
    if (!_monthPattern.hasMatch(_monthValue.text.trim())) return '월물은 202612 형식으로 입력하세요.';
    final expiry = _monthExpiry.text.trim();
    if (!_datePattern.hasMatch(expiry) || DateTime.tryParse(expiry) == null) return '만기일은 2026-12-10 형식으로 입력하세요.';
    for (final c in [_monthOpen, _monthClose]) {
      final v = c.text.trim();
      if (v.isNotEmpty && !_timePattern.hasMatch(v)) return '시간은 09:00 형식으로 입력하세요.';
    }
    return null;
  }

  void _editMonth(ContractMonth m) => setState(() {
    _monthTarget = m;
    _monthCode.text = m.code;
    _monthValue.text = m.month;
    _monthExpiry.text = _day(m.expiry);
    _monthOpen.text = m.sessionOpen ?? '';
    _monthClose.text = m.sessionClose ?? '';
  });

  void _saveMonth(MasterSymbol s) {
    final code = _monthCode.text.trim();
    final month = _monthValue.text.trim();
    final expiry = DateTime.parse(_monthExpiry.text.trim());
    final open = _monthOpen.text.trim(), close = _monthClose.text.trim();
    final target = _monthTarget;
    setState(() {
      if (target == null) {
        s.months
          ..add(
            ContractMonth(
              code,
              month,
              expiry,
              sessionOpen: open.isEmpty ? null : open,
              sessionClose: close.isEmpty ? null : close,
            ),
          )
          ..sort((a, b) => a.expiry.compareTo(b.expiry));
        logSymbolChange('${s.productCode} 월물 추가 $code ($month, 만기 ${_day(expiry)})');
      } else {
        final changes = [
          if (target.month != month) '월물 ${target.month} → $month',
          if (target.expiry != expiry) '만기일 ${_day(target.expiry)} → ${_day(expiry)}',
          if ((target.sessionOpen ?? '') != open) '장 시작 ${s.openOf(target)} → ${open.isEmpty ? s.sessionOpen : open}',
          if ((target.sessionClose ?? '') != close)
            '장 종료 ${s.closeOf(target)} → ${close.isEmpty ? s.sessionClose : close}',
        ];
        target
          ..month = month
          ..expiry = expiry
          ..sessionOpen = open.isEmpty ? null : open
          ..sessionClose = close.isEmpty ? null : close;
        s.months.sort((a, b) => a.expiry.compareTo(b.expiry));
        if (changes.isNotEmpty) logSymbolChange('${target.code} ${changes.join(', ')}');
      }
      _clearMonthForm();
    });
    showMessage(context, '월물을 저장했습니다.');
  }

  Future<void> _toggleMonth(MasterSymbol s, ContractMonth m) async {
    final workers = workersOnMonth(m.code);
    if (m.active && workers > 0) {
      final ok = await showConfirmDialog(
        context,
        title: '${m.code} 사용 중지',
        message: '이 월물을 쓰는 워커가 $workers개 있습니다. 사용을 중지합니다.',
        confirmText: '사용 중지',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      m.active = !m.active;
      logSymbolChange('${m.code} 월물 ${m.active ? '사용' : '사용 중지'}');
    });
  }

  /// 서머타임 시작·종료. 시작하면 한국시간으로 1시간 앞당겨지고, 종료하면 1시간 늦춰진다.
  Future<void> _toggleDst(String rule) async {
    final starting = !dstActive[rule]!;
    final hours = starting ? -1 : 1;
    final targets = mockSymbols.where((s) => s.dstRule == rule).toList();
    final workers = targets.fold(0, (n, s) => n + workersOnProduct(s));
    final action = '$rule 서머타임 ${starting ? '시작' : '종료'}';
    final ok = await showConfirmDialog(
      context,
      title: action,
      message: [
        '상품 ${targets.length}개의 시간을 1시간 ${starting ? '앞당깁니다' : '늦춥니다'}.',
        '',
        for (final s in targets)
          '${s.productCode}  ${s.sessionOpen}~${s.sessionClose} → '
              '${shiftTimes(s.sessionOpen, hours)}~${shiftTimes(s.sessionClose, hours)}',
        if (workers > 0) '\n워커 $workers개의 주문과 청산에 바로 적용됩니다.',
      ].join('\n'),
      confirmText: '적용',
      destructive: workers > 0,
    );
    if (!ok || !mounted) return;
    setState(() => applyDstChange(rule));
    showMessage(context, '$action: 상품 ${targets.length}개에 적용했습니다.');
  }

  /// 서머타임 상태와 버튼. 이것만 누르면 시간 방향과 항목은 자동으로 정해진다.
  Widget _dstPanel() {
    final canEdit = can(AdminPermission.manageSymbols);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Wrap(
        spacing: 32,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final rule in dstActive.keys)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$rule 서머타임 ${dstActive[rule]! ? '적용 중' : '미적용'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '상품 ${mockSymbols.where((s) => s.dstRule == rule).length}개'
                  '${dstNextChange[rule] == null ? '' : ' · 전환 예정 ${_day(dstNextChange[rule]!)}'}',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
                if (canEdit) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => _toggleDst(rule),
                    child: Text('$rule 서머타임 ${dstActive[rule]! ? '종료하기' : '시작하기'}'),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  /// 일괄 적용 입력의 문제. 없으면 null, 아직 고른 항목이 없으면 빈 문자열.
  String? get _bulkError {
    final on = _bulk.where((f) => f.on).toList();
    if (on.isEmpty) return '';
    for (final f in on) {
      final v = f.controller.text.trim();
      if (v.isEmpty) {
        if (!f.optional) return '${f.label} 값을 입력하세요.';
      } else if (f.isTime && !_timePattern.hasMatch(v)) {
        return '${f.label}은(는) 09:00 형식으로 입력하세요.';
      } else if (f.label == '휴식 구간' && !_breakPattern.hasMatch(v)) {
        return '휴식 구간은 12:00-13:00 형식으로 입력하세요.';
      } else if (f.label == '휴장일' && !_holidayPattern.hasMatch(v)) {
        return '휴장일은 2026-12-25, 2026-12-31 형식으로 입력하세요.';
      }
    }
    return null;
  }

  Future<void> _applyBulk() async {
    final targets = _checked.toList();
    final on = _bulk.where((f) => f.on).toList();
    String after(_BulkField f) => f.controller.text.trim();
    String show(String v) => v.isEmpty ? '없음' : v;

    // 값이 이미 같은 상품은 뺀다.
    final changes = <MasterSymbol, List<String>>{};
    for (final s in targets) {
      final list = [
        for (final f in on)
          if (f.read(s) != after(f)) '${f.label} ${show(f.read(s))} → ${show(after(f))}',
      ];
      if (list.isNotEmpty) changes[s] = list;
    }
    if (changes.isEmpty) {
      showMessage(context, '바뀌는 값이 없습니다.');
      return;
    }
    final workers = changes.keys.fold(0, (n, s) => n + workersOnProduct(s));
    final ok = await showConfirmDialog(
      context,
      title: '일괄 적용 · 상품 ${changes.length}개',
      message: [
        for (final MapEntry(key: s, value: list) in changes.entries) '${s.productCode}: ${list.join(', ')}',
        if (workers > 0) '\n이 상품을 쓰는 워커 $workers개의 주문과 청산에 바로 적용됩니다.',
      ].join('\n'),
      confirmText: '적용',
      destructive: workers > 0,
    );
    if (!ok || !mounted) return;
    setState(() {
      for (final MapEntry(key: s, value: list) in changes.entries) {
        for (final f in on) {
          f.write(s, after(f));
        }
        logSymbolChange('${s.productCode} 일괄 적용: ${list.join(', ')}');
      }
      _checked.clear();
      for (final f in _bulk) {
        f.on = false;
        f.controller.clear();
      }
    });
    showMessage(context, '상품 ${changes.length}개에 적용했습니다.');
  }

  Widget _bulkPanel() {
    final error = _bulkError;
    return Panel(
      title: '일괄 적용 · 선택한 상품 ${_checked.length}개',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _checked.map((s) => s.productCode).join(', '),
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text('바꿀 항목을 체크하세요.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in _bulk)
                FilterChip(
                  label: Text(f.label, style: const TextStyle(fontSize: 13)),
                  visualDensity: VisualDensity.compact,
                  selected: f.on,
                  onSelected: (v) => setState(() => f.on = v),
                ),
            ],
          ),
          if (_bulk.any((f) => f.on)) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                for (final f in _bulk.where((f) => f.on))
                  _field(f.controller, f.label, hint: f.hint, width: f.isTime ? 140 : 220),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (error != null && error.isNotEmpty)
                Expanded(
                  child: Text(error, style: const TextStyle(color: AppColors.warning, fontSize: 13)),
                )
              else
                const Spacer(),
              TextButton(onPressed: () => setState(_checked.clear), child: const Text('선택 해제')),
              const SizedBox(width: 8),
              FilledButton(onPressed: error == null ? _applyBulk : null, child: const Text('일괄 적용')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {String? hint, double width = 180, bool enabled = true}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            enabled: enabled,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14),
            // 예시 문구가 입력값처럼 보이지 않게 흐리게 쓴다.
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.45), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _picker(String label, String value, List<String> values, ValueChanged<String>? onChanged) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: [for (final v in values) DropdownMenuItem(value: v, child: Text(v))],
            onChanged: onChanged == null ? null : (v) => setState(() => onChanged(v ?? value)),
          ),
        ],
      ),
    );
  }

  Widget _editor() {
    final t = _target;
    final error = _error;
    final size = double.tryParse(_tickSize.text.trim());
    final value = double.tryParse(_tickValue.text.trim());
    final multiplier = size != null && value != null && size > 0 ? _plain(value / size) : '-';
    Widget group(String title, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: children),
        const SizedBox(height: 14),
      ],
    );

    return Panel(
      title: t == null ? '상품 추가' : '상품 수정 · ${t.productCode}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          group('기본 정보', [
            _field(_code, '상품코드', hint: 'MCL', width: 120, enabled: t == null),
            _field(_name, '상품명', width: 240),
            _picker('시장', _marketType, marketTypes, t == null ? (v) => _marketType = v : null),
            _field(_exchange, '거래소', hint: 'CME', width: 120),
            _picker('통화', _currency, currencies, (v) => _currency = v),
          ]),
          group('계약', [
            _field(_tickSize, '틱 크기', hint: '0.01', width: 120),
            _field(_tickValue, '틱 가치', hint: '1', width: 120),
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('계약승수', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  const SizedBox(height: 10),
                  Text(multiplier, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ]),
          group('거래 시간 (한국시간 기준)', [
            _field(_sessionOpen, '장 시작', hint: '08:45', width: 120),
            _field(_sessionClose, '장 종료', hint: '15:45', width: 120),
            _field(_orderOpen, '주문 가능 시작', hint: '08:30', width: 120),
            _field(_orderClose, '주문 가능 종료', hint: '15:45', width: 120),
            _field(_autoClose, '장 마감 자동 청산', hint: '비우면 앱 기본 규칙', width: 170),
            _field(_timeZone, '타임존', hint: 'Asia/Seoul', width: 170),
            _picker('서머타임', _dstRule, dstRules, (v) => _dstRule = v),
            _field(_breakTime, '휴식 구간', hint: '12:00-13:00', width: 200),
            _field(_holidays, '휴장일', hint: '2026-12-25, 2026-12-31', width: 280),
          ]),
          Row(
            children: [
              Switch(value: _active, onChanged: (v) => setState(() => _active = v)),
              const Text('사용', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 16),
              if (error != null)
                Expanded(
                  child: Text(error, style: const TextStyle(color: AppColors.warning, fontSize: 13)),
                )
              else
                const Spacer(),
              TextButton(onPressed: _close, child: const Text('취소')),
              const SizedBox(width: 8),
              FilledButton(onPressed: error == null ? _save : null, child: const Text('저장')),
            ],
          ),
        ],
      ),
    );
  }

  /// 부동소수 오차를 지운다.
  num _round(double v) {
    final r = (v * 10000).round() / 10000;
    return r == r.truncateToDouble() ? r.toInt() : r;
  }

  /// 월물만 따로 정한 시간은 색으로 구분한다.
  Widget _monthTime(String time, bool own) => Text(
    time,
    style: TextStyle(color: own ? AppColors.accent : null, fontWeight: own ? FontWeight.w700 : null),
  );

  /// 선택한 상품의 월물 테이블. 월물 하나가 워커가 쓰는 종목이다.
  Widget _monthsPanel(MasterSymbol s, bool canEdit) {
    final error = _monthError(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${s.name} (${s.productCode}) 월물 ${s.months.length}개',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        AdminTable(
          columns: const ['월물', '구분', '장 시작', '장 종료', '거래 기간', '현재가', '전일 대비', '거래량', '미결제약정', '워커', '사용', ''],
          emptyText: '등록된 월물이 없습니다.',
          rows: [
            for (final m in s.months)
              [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.month, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(m.code, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  ],
                ),
                s.monthLabel(m).isEmpty
                    ? Text(m.expired ? '만기' : '중지', style: const TextStyle(color: AppColors.textTertiary))
                    : StatusBadge(
                        s.monthLabel(m),
                        color: identical(m, s.nearMonth) ? AppColors.accent : AppColors.textSecondary,
                      ),
                _monthTime(s.openOf(m), m.sessionOpen != null),
                _monthTime(s.closeOf(m), m.sessionClose != null),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m.firstTrade == null ? '-' : _day(m.firstTrade!)} ~ ${_day(m.expiry)}'),
                    Text(
                      m.expired ? '만기 지남' : 'D-${m.expiry.difference(mockSymbolToday).inDays}',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
                Text(m.lastPrice == 0 ? '-' : formatNumber(_round(m.lastPrice))),
                Text(
                  m.lastPrice == 0 ? '-' : '${m.change > 0 ? '+' : ''}${formatNumber(_round(m.change))}',
                  style: TextStyle(
                    color: m.change > 0
                        ? AppColors.up
                        : m.change < 0
                        ? AppColors.down
                        : null,
                  ),
                ),
                Text(formatNumber(m.volume)),
                Text(formatNumber(m.openInterest)),
                Text('${workersOnMonth(m.code)}'),
                Switch(value: m.active, onChanged: canEdit ? (_) => _toggleMonth(s, m) : null),
                canEdit
                    ? IconButton(
                        tooltip: '월물 수정',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _editMonth(m),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      )
                    : const SizedBox.shrink(),
              ],
          ],
        ),
        if (canEdit) ...[
          const SizedBox(height: 12),
          Panel(
            title: _monthTarget == null ? '월물 추가' : '월물 수정 · ${_monthTarget!.code}',
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _field(_monthCode, '종목코드', hint: 'MCLH27', width: 150, enabled: _monthTarget == null),
                _field(_monthValue, '월물', hint: '202703', width: 120),
                _field(_monthExpiry, '만기일', hint: '2027-02-18', width: 150),
                _field(_monthOpen, '장 시작 (비우면 상품 시간)', hint: s.sessionOpen, width: 170),
                _field(_monthClose, '장 종료 (비우면 상품 시간)', hint: s.sessionClose, width: 170),
                FilledButton(
                  onPressed: error == null ? () => _saveMonth(s) : null,
                  child: Text(_monthTarget == null ? '월물 추가' : '월물 저장'),
                ),
                if (_monthTarget != null)
                  TextButton(onPressed: () => setState(_clearMonthForm), child: const Text('취소')),
                if (error != null && error.isNotEmpty)
                  Text(error, style: const TextStyle(color: AppColors.warning, fontSize: 13)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = can(AdminPermission.manageSymbols);
    final selected = _selected;
    final visible = _visible;
    return AdminPage(
      title: '종목 마스터',
      description: '국내선물·해외선물 상품의 틱 값과 거래 시간, 상품별 월물을 관리합니다. 시간은 한국시간 기준입니다.',
      actions: [
        if (canEdit)
          FilledButton.icon(
            onPressed: () => _open(null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('상품 추가'),
          ),
      ],
      children: [
        _dstPanel(),
        if (_editing) _editor(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterBar(
              hint: '상품·종목코드·이름 검색',
              filters: [for (final (i, f) in _filters.indexed) '$f ${_count(i)}'],
              selectedIndex: _filter,
              onFilterSelected: (i) => setState(() => _filter = i),
              onSearchChanged: (v) => setState(() => _query = v),
            ),
          ],
        ),
        AdminTable(
          selected: canEdit
              ? {
                  for (final (i, s) in visible.indexed)
                    if (_checked.contains(s)) i,
                }
              : null,
          onSelectChanged: (i, v) => setState(() => v ? _checked.add(visible[i]) : _checked.remove(visible[i])),
          onSelectAll: (v) => setState(() => v ? _checked.addAll(visible) : _checked.removeAll(visible)),
          columns: const ['상품', '틱 크기', '틱 가치', '최근월물', '월물', '장 시간', '주문 가능', '워커', '상태', ''],
          emptyText: '조건에 맞는 상품이 없습니다.',
          rows: [
            for (final s in visible)
              [
                InkWell(
                  onTap: () => _select(s),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: identical(s, selected) ? AppColors.accent : null,
                        ),
                      ),
                      Text(
                        '${s.productCode} · ${s.marketType} · ${s.exchange}${s.dstRule == '없음' ? '' : ' · ${s.dstRule} 서머타임'}',
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(_plain(s.tickSize)),
                Text('${formatNumber(s.tickValue % 1 == 0 ? s.tickValue.toInt() : s.tickValue)} ${s.currency}'),
                Text(
                  s.nearMonth == null
                      ? '-'
                      : '${s.nearMonth!.month} · D-${s.nearMonth!.expiry.difference(mockSymbolToday).inDays}',
                ),
                Text('${s.months.length}'),
                Tooltip(
                  message: [
                    '한국시간 기준 · ${s.timeZone}',
                    if (s.breakTime.isNotEmpty) '휴식 ${s.breakTime}',
                    if (s.holidays.isNotEmpty) '휴장 ${s.holidays}',
                  ].join('\n'),
                  child: Text('${s.sessionOpen}~${s.sessionClose}'),
                ),
                Text('${s.orderOpen}~${s.orderClose}'),
                Text('${workersOnProduct(s)}'),
                StatusBadge(s.active ? '사용' : '중지', color: s.active ? AppColors.success : AppColors.textTertiary),
                canEdit
                    ? IconButton(
                        tooltip: '수정',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _open(s),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      )
                    : const SizedBox.shrink(),
              ],
          ],
        ),
        // 체크할 때 표가 밀리지 않도록 표 아래에 둔다.
        if (canEdit && _checked.isNotEmpty) _bulkPanel(),
        if (selected != null) _monthsPanel(selected, canEdit),
      ],
    );
  }
}
