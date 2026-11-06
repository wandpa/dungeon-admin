import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_admin.dart';
import '../mock_data.dart' show formatDateTime, formatNumber;
import '../theme.dart';
import '../widgets/admin_page.dart';
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
  const _Data(this.products, this.productTotal, this.stocks, this.stockTotal);
  final List<Map<String, dynamic>> products;
  final int productTotal;
  final List<Map<String, dynamic>> stocks;
  final int stockTotal;
}

/// 테스트 DB 종목 마스터. 앱 종목 검색처럼 시장, 거래소, 상품, 월물 순서로 찾는다. 조회만 한다.
class LiveSymbolPage extends StatefulWidget {
  const LiveSymbolPage({super.key});

  @override
  State<LiveSymbolPage> createState() => _LiveSymbolPageState();
}

class _LiveSymbolPageState extends State<LiveSymbolPage> {
  final _debounce = SearchDebounce();
  final _products = <String, Future<List<Map<String, dynamic>>>>{}; // 검색어별 상품. 거래소는 화면에서 거른다
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

  /// API 에 거래소 조건이 없어 해외선물은 상품을 모두 받아 거른다. 한 쪽이 몇 초 걸려 나머지는 한 번에 받는다.
  Future<List<Map<String, dynamic>>> _allProducts(String query) async {
    final q = Uri.encodeQueryComponent(query);
    Future<Map<String, dynamic>> page(int n) async =>
        await liveGet('/symbols?q=$q&page=$n&pageSize=$liveListLimit') as Map<String, dynamic>;
    List<Map<String, dynamic>> items(Map<String, dynamic> body) => (body['items'] as List).cast<Map<String, dynamic>>();

    final first = await page(1);
    final pages = ((first['total'] as int? ?? 0) / liveListLimit).ceil();
    final rest = await Future.wait([for (var n = 2; n <= pages; n++) page(n)]);
    return [...items(first), for (final body in rest) ...items(body)];
  }

  Future<_Data> _load() async {
    final query = _query.trim();
    final q = Uri.encodeQueryComponent(query);
    var products = const <Map<String, dynamic>>[];
    var productTotal = 0;
    if (_category == _Category.futures) {
      final pending = _products[query] ??= _allProducts(query);
      try {
        products = await pending;
      } catch (_) {
        _products.remove(query); // 실패를 기억하지 않는다
        rethrow;
      }
      productTotal = products.length;
    }
    final paging = 'page=$_page&pageSize=$_pageSize';
    final rows = await Future.wait<Map<String, dynamic>?>([
      if (_category == _Category.all) _body('/symbols?q=$q&$paging') else Future.value(),
      if (_category.hasStocks)
        _body('/symbols/stocks?q=$q&$paging${_category.exchange == null ? '' : '&exchange=${_category.exchange}'}')
      else
        Future.value(),
    ]);
    if (rows[0] != null) {
      products = (rows[0]!['items'] as List).cast<Map<String, dynamic>>();
      productTotal = rows[0]!['total'] as int? ?? 0;
    }
    final stocks = rows[1];
    return _Data(
      products,
      productTotal,
      stocks == null ? const [] : (stocks['items'] as List).cast<Map<String, dynamic>>(),
      stocks?['total'] as int? ?? 0,
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

  Widget _exchanges(List<Map<String, dynamic>> products) {
    final counts = <String, int>{};
    for (final p in products) {
      counts.update(_text(p['exchange']), (n) => n + 1, ifAbsent: () => 1);
    }
    final names = counts.keys.toList()..sort();
    Widget chip(String label, String? value) => ChoiceChip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      selected: _exchange == value,
      onSelected: (_) => _setExchange(value),
    );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [chip('전체 거래소 ${products.length}', null), for (final n in names) chip('$n ${counts[n]}', n)],
    );
  }

  Widget _productTable(List<Map<String, dynamic>> rows) {
    return AdminTable(
      columns: const ['상품코드', '이름', '거래소', '분류', '통화', '틱', '틱 가치', '승수', '월물', '최근월물', '워커', '상태'],
      emptyText: '조건에 맞는 상품이 없습니다.',
      onRowTap: (i) => setState(() => _opened = rows[i]),
      highlightedRow: rows.indexWhere((p) => p['productCode'] == _opened?['productCode']),
      rows: [
        for (final p in rows)
          [
            Text(_text(p['productCode']), style: const TextStyle(fontWeight: FontWeight.w600)),
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
      columns: const ['종목코드', '이름', '거래소', '통화', '기준가', '기준일', 'NXT', '상태', '갱신'],
      emptyText: '조건에 맞는 종목이 없습니다.',
      rows: [
        for (final s in rows)
          [
            Text(_text(s['code']), style: const TextStyle(fontWeight: FontWeight.w600)),
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
    final products = [
      for (final p in data.products)
        if (_exchange == null || p['exchange'] == _exchange) p,
    ];
    // 해외선물은 받아 둔 전체를 화면에서 나누고, 전체는 서버가 나눈 쪽을 그대로 보여 준다.
    final shown = futures ? products.skip((_page - 1) * _pageSize).take(_pageSize).toList() : products;
    final productTotal = futures ? products.length : data.productTotal;
    final total = productTotal > data.stockTotal ? productTotal : data.stockTotal;
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    final opened = _opened;
    const summary = TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (futures) ...[_exchanges(data.products), const SizedBox(height: 8)],
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
        if (_category.hasProducts) _productTable(shown),
        if (!wide && opened != null) ...[
          const SizedBox(height: 8),
          _MonthPanel(opened, key: ValueKey(_productKey(opened)), onClose: () => setState(() => _opened = null)),
        ],
        LivePager(total: total, page: _page, pageSize: _pageSize, onPage: (p) => setState(() => _page = p)),
      ],
    );
  }

  String _productKey(Map<String, dynamic> p) => '${p['productCode']}|${p['exchange']}';

  @override
  Widget build(BuildContext context) {
    final opened = _opened;
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    return AdminPage(
      title: '종목 마스터',
      description: '앱 종목 검색과 같은 순서로 상품과 월물을 조회하고 장 시간을 입력합니다.',
      side: !wide || !_category.hasProducts
          ? null
          : opened == null
          ? const Text('상품을 누르면 월물이 나옵니다.', style: TextStyle(color: AppColors.textTertiary))
          : _MonthPanel(opened, key: ValueKey(_productKey(opened)), onClose: () => setState(() => _opened = null)),
      children: [
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
          // 해외선물은 받아 둔 상품을 화면에서 나누므로 쪽을 넘겨도 다시 받지 않는다.
          key: ValueKey((_category, _query, _category == _Category.futures ? 0 : _page)),
          load: _load,
          builder: _view,
        ),
      ],
    );
  }
}

/// 상품의 장 시작·종료 입력. DB 의 네 구간을 그대로 고친다. 저장 API 가 없어 지금은 안내만 한다.
class _SessionForm extends StatefulWidget {
  const _SessionForm(this.product);

  final Map<String, dynamic> product;

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

  bool get _editable => can(AdminPermission.manageSymbols);

  @override
  void dispose() {
    for (final (open, close) in _fields.values) {
      open.dispose();
      close.dispose();
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
    return null;
  }

  void _reset() => setState(() {
    for (final (_, key) in _sessions) {
      final (open, close) = _fields[key]!;
      open.text = widget.product['${key}Open'] as String? ?? '';
      close.text = widget.product['${key}Close'] as String? ?? '';
    }
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
    const head = TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700);
    return Panel(
      title: '장 시간',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 4),
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
                Text(_title(m), style: const TextStyle(fontWeight: FontWeight.w700)),
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
            Text('워커 ${m['workerCount']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
              child: Text(_text(p['name']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
