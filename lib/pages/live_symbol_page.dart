import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_admin.dart';
import '../mock_data.dart' show formatDateTime, formatNumber;
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'live_market_hours.dart';
import 'live_view.dart';

const _pageSize = 20;

String _text(Object? v) => v == null || v == '' ? '-' : '$v';
String _number(Object? v) => v is num ? formatNumber(v) : '-';

String _time(Object? v) {
  final t = liveTime(v);
  return t == null ? '-' : formatDateTime(t);
}

/// 앱 종목 검색의 칩과 같다. 전체는 국내 종목과 해외선물 상품을 함께 보여 준다.
enum _Category {
  all('전체'),
  kospi('KOSPI'),
  kosdaq('KOSDAQ'),
  futures('해외선물');

  const _Category(this.label);
  final String label;

  bool get hasStocks => this != futures;
  bool get hasProducts => this == all || this == futures;
  String? get exchange => switch (this) {
    kospi => 'KOSPI',
    kosdaq => 'KOSDAQ',
    _ => null,
  };
}

const _monthCodes = 'FGHJKMNQUVXZ';

/// 월물 코드 끝의 월·연도로 앱과 같은 202612 표기를 만든다. 읽지 못하면 코드를 그대로 둔다.
String _nearMonth(Object? code) {
  if (code is! String) return '-';
  final match = RegExp(r'([FGHJKMNQUVXZ])(\d{2})$').firstMatch(code);
  if (match == null) return code;
  final month = _monthCodes.indexOf(match[1]!) + 1;
  return '20${match[2]}${month.toString().padLeft(2, '0')}';
}

/// 앱 월물 머리줄의 "1틱 0.1 = $10".
String _tick(Map<String, dynamic> p) {
  final value = _number(p['tickValue']);
  final currency = p['currency'];
  final money = currency == 'USD' ? '\$$value' : '$value ${_text(currency)}';
  return '1틱 ${_number(p['tickSize'])} = $money';
}

class _Data {
  const _Data(this.products, this.productTotal, this.stocks, this.stockTotal, this.exchanges);
  final List<Map<String, dynamic>> products;
  final int productTotal;
  final List<Map<String, dynamic>> stocks;
  final int stockTotal;
  final List<Map<String, dynamic>> exchanges; // 거래소별 상품 수. 해외선물에서만 받는다
}

/// 테스트 DB 종목 마스터. 앱 종목 검색처럼 시장, 거래소, 상품, 월물 순서로 찾는다. 조회만 한다.
class LiveSymbolPage extends StatefulWidget {
  const LiveSymbolPage({super.key});

  @override
  State<LiveSymbolPage> createState() => _LiveSymbolPageState();
}

class _LiveSymbolPageState extends State<LiveSymbolPage> {
  final _debounce = SearchDebounce();
  final _products = <String, Future<List<Map<String, dynamic>>>>{}; // 거래소별 상품 전체. 거래소 장 시간에 쓴다
  _Category _category = _Category.all;
  String? _exchange; // 비어 있으면 전체 거래소
  String _query = '';
  int _page = 1;
  Map<String, dynamic>? _opened; // 월물을 볼 상품

  @override
  void dispose() {
    _debounce.dispose();
    super.dispose();
  }

  /// 거래소의 상품 전체. 상품마다 시간이 다른지 봐야 해서 나눠 받은 쪽을 모두 모은다.
  Future<List<Map<String, dynamic>>> _allProducts(String exchange) async {
    final name = Uri.encodeQueryComponent(exchange);
    Future<Map<String, dynamic>> page(int n) async =>
        await liveGet('/symbols?exchange=$name&page=$n&pageSize=$liveListLimit') as Map<String, dynamic>;
    List<Map<String, dynamic>> items(Map<String, dynamic> body) => (body['items'] as List).cast<Map<String, dynamic>>();

    final first = await page(1);
    final pages = ((first['total'] as int? ?? 0) / liveListLimit).ceil();
    final rest = await Future.wait([for (var n = 2; n <= pages; n++) page(n)]);
    return [...items(first), for (final body in rest) ...items(body)];
  }

  Future<List<Map<String, dynamic>>> _productsOf(String exchange) async {
    try {
      return await (_products[exchange] ??= _allProducts(exchange));
    } catch (_) {
      _products.remove(exchange); // 실패를 기억하지 않는다
      rethrow;
    }
  }

  Future<_Data> _load() async {
    final q = Uri.encodeQueryComponent(_query.trim());
    final paging = 'page=$_page&pageSize=$_pageSize';
    final exchange = _exchange == null ? '' : '&exchange=${Uri.encodeQueryComponent(_exchange!)}';
    final rows = await Future.wait<Map<String, dynamic>?>([
      if (_category.hasProducts) _body('/symbols?q=$q$exchange&$paging') else Future.value(),
      if (_category.hasStocks)
        _body('/symbols/stocks?q=$q&$paging${_category.exchange == null ? '' : '&exchange=${_category.exchange}'}')
      else
        Future.value(),
      if (_category == _Category.futures) _body('/symbols/exchanges') else Future.value(),
    ]);
    final products = rows[0];
    final stocks = rows[1];
    List<Map<String, dynamic>> items(Map<String, dynamic>? body) =>
        body == null ? const [] : (body['items'] as List).cast<Map<String, dynamic>>();
    return _Data(
      items(products),
      products?['total'] as int? ?? 0,
      items(stocks),
      stocks?['total'] as int? ?? 0,
      items(rows[2]),
    );
  }

  Future<Map<String, dynamic>?> _body(String path) async => await liveGet(path) as Map<String, dynamic>;

  void _setCategory(_Category c) => setState(() {
    _category = c;
    _exchange = null;
    _page = 1;
    _opened = null;
  });

  void _setExchange(String? e) => setState(() {
    _exchange = e;
    _page = 1;
    _opened = null;
  });

  Widget _exchanges(List<Map<String, dynamic>> rows) {
    final counts = {for (final r in rows) _text(r['exchange']): r['count'] as int? ?? 0};
    final names = counts.keys.toList()..sort();
    final total = counts.values.fold(0, (a, b) => a + b);
    Widget chip(String label, String? value) => ChoiceChip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      selected: _exchange == value,
      onSelected: (_) => _setExchange(value),
    );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [chip('전체 거래소 $total', null), for (final n in names) chip('$n ${counts[n]}', n)],
    );
  }

  Widget _productTable(List<Map<String, dynamic>> rows) {
    return AdminTable(
      exportName: '해외_상품',
      columns: const ['상품코드', '이름', '거래소', '분류', '통화', '틱', '틱 가치', '승수', '월물', '최근월물', '워커', '상태'],
      emptyText: '조건에 맞는 상품이 없습니다.',
      onRowTap: (i) => setState(() => _opened = rows[i]),
      highlightedRow: rows.indexWhere((p) => p['productCode'] == _opened?['productCode']),
      rows: [
        for (final p in rows)
          [
            Text(_text(p['productCode']), style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(_text(p['name'])),
            Text(_text(p['exchange'])),
            Text(_text(p['className'])),
            Text(_text(p['currency'])),
            Text(_number(p['tickSize'])),
            Text(_number(p['tickValue'])),
            Text(_number(p['multiplier'])),
            Text('${_number(p['monthCount'])}개'),
            Text(_nearMonth(p['nearMonth'])),
            Text(_number(p['workerCount'])),
            StatusBadge(
              p['active'] == true ? '사용' : '미사용',
              color: p['active'] == true ? AppColors.success : AppColors.textTertiary,
            ),
          ],
      ],
    );
  }

  Widget _stockTable(List<Map<String, dynamic>> rows) {
    return AdminTable(
      exportName: '종목',
      columns: const ['종목코드', '이름', '거래소', '통화', '기준가', '기준일', 'NXT', '상태', '갱신'],
      emptyText: '조건에 맞는 종목이 없습니다.',
      rows: [
        for (final s in rows)
          [
            Text(_text(s['code']), style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(_text(s['name'])),
            Text(_text(s['exchange'])),
            Text(_text(s['currency'])),
            Text(_number(s['basePrice'])),
            Text(_text(s['basePriceDate'])),
            Text(s['nxtTradable'] == true ? '가능' : '불가'),
            StatusBadge(
              s['active'] == true ? '사용' : '미사용',
              color: s['active'] == true ? AppColors.success : AppColors.textTertiary,
            ),
            Text(_time(s['updatedAt'])),
          ],
      ],
    );
  }

  Widget _view(BuildContext context, _Data data) {
    final futures = _category == _Category.futures;
    final productTotal = data.productTotal;
    final total = productTotal > data.stockTotal ? productTotal : data.stockTotal;
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    final opened = _opened;
    const summary = TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w500);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (futures) ...[_exchanges(data.exchanges), const SizedBox(height: 8)],
        Text(
          [
            if (_category.hasStocks) '${formatNumber(data.stockTotal)}개 종목',
            if (_category.hasProducts) '해외선물 ${formatNumber(productTotal)}개 상품',
          ].join(' · '),
          style: summary,
        ),
        const SizedBox(height: 8),
        // 앱 검색 결과와 같이 국내 종목을 먼저 놓는다.
        if (_category.hasStocks) _stockTable(data.stocks),
        if (_category == _Category.all) const SizedBox(height: 8),
        if (_category.hasProducts) _productTable(data.products),
        if (!wide && opened != null) ...[
          const SizedBox(height: 8),
          _MonthPanel(opened, key: ValueKey(_productKey(opened)), onClose: () => setState(() => _opened = null)),
        ],
        LivePager(total: total, page: _page, pageSize: _pageSize, onPage: (p) => setState(() => _page = p)),
      ],
    );
  }

  /// 거래소 장 시간. 상품마다 시간이 다르면 비워 두고 입력한 구간만 바꾼다.
  Widget _exchangeHours(String exchange) => LiveLoader<List<Map<String, dynamic>>>(
    key: ValueKey('hours|$exchange'),
    load: () => _productsOf(exchange),
    builder: (context, products) {
      String pattern(Map<String, dynamic> p) => [
        for (final s in const ['am', 'base', 'pm', 'nextDay']) '${p['${s}Open']}~${p['${s}Close']}',
      ].join(' ');
      final kinds = products.map(pattern).toSet().length;
      return _SessionForm(
        kinds == 1 ? products.first : const {},
        key: ValueKey(exchange),
        title: '$exchange 장 시간',
        note: kinds == 1
            ? '상품 ${products.length}개에 함께 적용합니다.'
            : '상품 ${products.length}개, 시간 $kinds종입니다. 입력한 구간만 상품 전체에 적용하고 빈 구간은 그대로 둡니다.',
      );
    },
  );

  String _productKey(Map<String, dynamic> p) => '${p['productCode']}|${p['exchange']}';

  @override
  Widget build(BuildContext context) {
    final opened = _opened;
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    return AdminPage(
      title: '종목 마스터',
      description: '앱 종목 검색과 같은 순서로 상품과 월물을 조회하고 장 시간을 입력합니다.',
      side: !wide
          ? null
          : opened != null
          ? _MonthPanel(opened, key: ValueKey(_productKey(opened)), onClose: () => setState(() => _opened = null))
          : _category.hasStocks
          ? const LiveMarketHours()
          : _exchange != null
          ? _exchangeHours(_exchange!)
          : const Text(
              '거래소 칩을 누르면 거래소 장 시간, 상품을 누르면 상품 장 시간과 월물이 나옵니다.',
              style: TextStyle(color: AppColors.textTertiary),
            ),
      children: [
        if (!wide && _category.hasStocks) const LiveMarketHours(),
        if (!wide && _category == _Category.futures && _exchange != null && opened == null) _exchangeHours(_exchange!),
        FilterBar(
          hint: '종목명·코드 검색',
          filters: [for (final c in _Category.values) c.label],
          selectedIndex: _category.index,
          onFilterSelected: (i) => _setCategory(_Category.values[i]),
          onSearchChanged: (v) => _debounce(() {
            if (mounted) {
              setState(() {
                _query = v;
                _page = 1;
                _exchange = null;
                _opened = null;
              });
            }
          }),
        ),
        LiveLoader<_Data>(
          key: ValueKey((_category, _query, _exchange, _page)),
          load: _load,
          builder: _view,
        ),
      ],
    );
  }
}

/// 상품의 장 시작·종료 입력. DB 의 네 구간을 그대로 고친다. 저장 API 가 없어 지금은 안내만 한다.
class _SessionForm extends StatefulWidget {
  const _SessionForm(this.product, {super.key, this.title = '장 시간', this.note});

  final Map<String, dynamic> product;
  final String title;
  final String? note;

  @override
  State<_SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends State<_SessionForm> {
  static const _sessions = [('오전 (Am)', 'am'), ('기본 (Base)', 'base'), ('오후 (Pm)', 'pm'), ('익일 (NextDay)', 'nextDay')];
  static final _time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  late final _fields = {
    for (final (_, key) in _sessions)
      key: (
        TextEditingController(text: widget.product['${key}Open'] as String?),
        TextEditingController(text: widget.product['${key}Close'] as String?),
      ),
  };

  final _special = <SpecialRow>[];

  bool get _editable => can(AdminPermission.manageSymbols);

  @override
  void initState() {
    super.initState();
    _fillSpecial();
  }

  /// DB 에는 상품마다 특정일이 하나뿐이고 시간 칸이 없다.
  void _fillSpecial() {
    for (final r in _special) {
      r.dispose();
    }
    _special.clear();
    final date = widget.product['specialDate'] as String?;
    if (date != null) {
      _special.add(SpecialRow(date: DateTime.tryParse(date), reason: widget.product['specialReason'] as String?));
    }
  }

  @override
  void dispose() {
    for (final (open, close) in _fields.values) {
      open.dispose();
      close.dispose();
    }
    for (final r in _special) {
      r.dispose();
    }
    super.dispose();
  }

  /// 문제가 없으면 null.
  String? get _problem {
    for (final (label, key) in _sessions) {
      final (open, close) = _fields[key]!;
      final from = open.text.trim(), to = close.text.trim();
      if (from.isEmpty && to.isEmpty) continue;
      if (from.isEmpty || to.isEmpty) return '$label 장 시작과 장 종료를 함께 입력하세요.';
      if (!_time.hasMatch(from) || !_time.hasMatch(to)) return '$label 시간은 08:45 형식으로 입력하세요.';
    }
    return specialDaysProblem(_special, sameDay: false); // 해외선물은 다음 날로 넘어간다
  }

  void _reset() => setState(() {
    for (final (_, key) in _sessions) {
      final (open, close) = _fields[key]!;
      open.text = widget.product['${key}Open'] as String? ?? '';
      close.text = widget.product['${key}Close'] as String? ?? '';
    }
    _fillSpecial();
  });

  Widget _field(TextEditingController controller) => Expanded(
    child: TextField(
      controller: controller,
      enabled: _editable,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(hintText: '-'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    const head = TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500);
    return Panel(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.note != null) ...[
            Text(widget.note!, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            const SizedBox(height: 8),
          ],
          const Row(
            children: [
              SizedBox(width: 100),
              Expanded(child: Text('장 시작', style: head)),
              SizedBox(width: 6),
              Expanded(child: Text('장 종료', style: head)),
            ],
          ),
          const SizedBox(height: 4),
          for (final (label, key) in _sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12))),
                  _field(_fields[key]!.$1),
                  const SizedBox(width: 6),
                  _field(_fields[key]!.$2),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SpecialDaysEditor(
            rows: _special,
            editable: _editable,
            defaultOpen: _fields['am']!.$1.text.trim(),
            defaultClose: _fields['am']!.$2.text.trim(),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            problem ?? '저장 API 연결 전입니다. 입력한 값은 저장되지 않습니다.',
            style: TextStyle(color: problem == null ? AppColors.warning : AppColors.up, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: _editable ? _reset : null, child: const Text('되돌리기')),
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

/// 앱 월물 목록: "Gold 2026년 12월물", "GCZ26 · CME", 최근월물 표시.
class _MonthPanel extends StatelessWidget {
  const _MonthPanel(this.product, {super.key, required this.onClose});

  final Map<String, dynamic> product;
  final VoidCallback onClose;

  String _title(Map<String, dynamic> m) {
    final month = m['month'];
    if (month is! String || month.length != 6) return _text(m['name']);
    return '${_text(product['name'])} ${month.substring(0, 4)}년 ${int.parse(month.substring(4))}월물';
  }

  Widget _row(Map<String, dynamic> m) {
    final label = m['label'] as String?;
    final near = label == '최근월물';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: near ? AppColors.success : AppColors.grid),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(m), style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${_text(m['code'])} · ${_text(m['exchange'])}',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                    if (label != null) StatusBadge(label, color: near ? AppColors.success : AppColors.accent),
                  ],
                ),
              ],
            ),
          ),
          if (m['workerCount'] is int && m['workerCount'] != 0)
            Text('워커 ${m['workerCount']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          if (m['active'] != true) ...[
            const SizedBox(width: 6),
            const StatusBadge('미사용', color: AppColors.textTertiary),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = product;
    final code = Uri.encodeComponent(p['productCode'] as String);
    final exchange = Uri.encodeQueryComponent(_text(p['exchange']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_text(p['name']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            IconButton(tooltip: '월물 닫기', onPressed: onClose, icon: const Icon(Icons.close, size: 18)),
          ],
        ),
        LiveLoader<List<Map<String, dynamic>>>(
          key: ValueKey('$code|$exchange'),
          load: () => liveItems('/symbols/$code/months?exchange=$exchange&pageSize=100'),
          builder: (context, months) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  children: [
                    TextSpan(
                      text: '${months.length}개 월물  ',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    TextSpan(text: '${_text(p['productCode'])} · ${_text(p['exchange'])} · ${_tick(p)}'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _SessionForm(p),
              const SizedBox(height: 8),
              if (months.isEmpty)
                const Text('월물이 없습니다.', style: TextStyle(color: AppColors.textTertiary))
              else
                for (final m in months) _row(m),
            ],
          ),
        ),
      ],
    );
  }
}
