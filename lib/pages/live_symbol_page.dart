import 'package:flutter/material.dart';

import '../live_api.dart';
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

enum _Market {
  futures('해외선물'),
  stocks('국내주식');

  const _Market(this.label);
  final String label;
}

/// 테스트 DB 종목 마스터. 조회만 한다. 없는 값은 '-' 로 둔다.
class LiveSymbolPage extends StatefulWidget {
  const LiveSymbolPage({super.key});

  @override
  State<LiveSymbolPage> createState() => _LiveSymbolPageState();
}

class _LiveSymbolPageState extends State<LiveSymbolPage> {
  final _debounce = SearchDebounce();
  _Market _market = _Market.futures;
  String _query = '';
  int _page = 1;
  Map<String, dynamic>? _opened; // 월물을 펼쳐 볼 상품

  @override
  void dispose() {
    _debounce.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final q = Uri.encodeQueryComponent(_query.trim());
    final path = _market == _Market.futures ? '/symbols' : '/symbols/stocks';
    return await liveGet('$path?q=$q&page=$_page&pageSize=$_pageSize') as Map<String, dynamic>;
  }

  void _setMarket(_Market m) => setState(() {
    _market = m;
    _page = 1;
    _opened = null;
  });

  Widget _table(BuildContext context, Map<String, dynamic> body) {
    final rows = (body['items'] as List).cast<Map<String, dynamic>>();
    final table = _market == _Market.futures
        ? AdminTable(
            columns: const ['상품코드', '이름', '거래소', '분류', '통화', '틱', '틱 가치', '승수', '월물', '근월물', '워커', '상태'],
            emptyText: '조건에 맞는 상품이 없습니다.',
            rows: [
              for (final p in rows)
                [
                  InkWell(
                    onTap: () => setState(() => _opened = p),
                    child: Text(_text(p['productCode']), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(_text(p['name'])),
                  Text(_text(p['exchange'])),
                  Text(_text(p['className'])),
                  Text(_text(p['currency'])),
                  Text(_number(p['tickSize'])),
                  Text(_number(p['tickValue'])),
                  Text(_number(p['multiplier'])),
                  Text(_number(p['monthCount'])),
                  Text(_text(p['nearMonth'])),
                  Text(_number(p['workerCount'])),
                  StatusBadge(
                    p['active'] == true ? '사용' : '미사용',
                    color: p['active'] == true ? AppColors.success : AppColors.textTertiary,
                  ),
                ],
            ],
          )
        : AdminTable(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        table,
        LivePager(
          total: body['total'] as int? ?? 0,
          page: _page,
          pageSize: _pageSize,
          onPage: (p) => setState(() => _page = p),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final opened = _opened;
    return AdminPage(
      title: '종목 마스터',
      description: '테스트 DB 의 상품과 월물을 조회합니다. 변경은 할 수 없습니다.',
      children: [
        FilterBar(
          hint: '코드·이름 검색',
          filters: [for (final m in _Market.values) m.label],
          selectedIndex: _market.index,
          onFilterSelected: (i) => _setMarket(_Market.values[i]),
          onSearchChanged: (v) => _debounce(() {
            if (mounted) {
              setState(() {
                _query = v;
                _page = 1;
              });
            }
          }),
        ),
        if (opened != null) _ProductPanel(opened, onClose: () => setState(() => _opened = null)),
        LiveLoader<Map<String, dynamic>>(key: ValueKey((_market, _query, _page)), load: _load, builder: _table),
      ],
    );
  }
}

/// 상품의 장 시간과 월물. 장 시간은 의미와 시간대가 확인되지 않아 구간 이름 그대로 보여 준다.
class _ProductPanel extends StatelessWidget {
  const _ProductPanel(this.product, {required this.onClose});

  final Map<String, dynamic> product;
  final VoidCallback onClose;

  String _session(String label, String key) =>
      '$label ${_text(product['${key}Open'])}~${_text(product['${key}Close'])}';

  @override
  Widget build(BuildContext context) {
    final p = product;
    final code = Uri.encodeComponent(p['productCode'] as String);
    final exchange = Uri.encodeQueryComponent(_text(p['exchange']));
    return Panel(
      title: '${_text(p['productCode'])} · ${_text(p['name'])} (${_text(p['exchange'])})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            [
              _session('Am', 'am'),
              _session('Base', 'base'),
              _session('Pm', 'pm'),
              _session('NextDay', 'nextDay'),
            ].join(' · '),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          LiveLoader<List<Map<String, dynamic>>>(
            key: ValueKey('$code|$exchange'),
            load: () => liveItems('/symbols/$code/months?exchange=$exchange&pageSize=100'),
            builder: (context, months) => AdminTable(
              columns: const ['종목코드', '월물', '구분', '틱', '틱 가치', '기준가', '기준일', '워커', '상태'],
              emptyText: '월물이 없습니다.',
              rows: [
                for (final m in months)
                  [
                    Text(_text(m['code']), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(_text(m['month'])),
                    Text(_text(m['label'])),
                    Text(_number(m['tickSize'])),
                    Text(_number(m['tickValue'])),
                    Text(_number(m['basePrice'])),
                    Text(_text(m['basePriceDate'])),
                    Text(_number(m['workerCount'])),
                    StatusBadge(
                      m['active'] == true ? '사용' : '미사용',
                      color: m['active'] == true ? AppColors.success : AppColors.textTertiary,
                    ),
                  ],
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onClose, child: const Text('닫기')),
          ),
        ],
      ),
    );
  }
}
