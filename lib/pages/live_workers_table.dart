import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_data.dart';
import '../mock_workers.dart' show CustomerLogCategory;
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'live_lists.dart';
import 'live_view.dart';

enum _Tab {
  workers('워커'),
  trades('거래'),
  positions('포지션'),
  logs('로그'),
  accounts('계좌'),
  signals('신호'),
  strategies('전략'),
  watchlist('관심종목'),
  symbols('종목');

  const _Tab(this.label);
  final String label;

  LiveListDef? get list => switch (this) {
    signals => liveSignalList,
    strategies => liveStrategyList,
    watchlist => liveWatchlist,
    symbols => liveMemberSymbols,
    _ => null,
  };
}

typedef _Row = (Member, Map<String, dynamic>);

String _text(Object? v) => v == null || v == '' ? '-' : '$v';

String _amount(Object? v) {
  final n = liveDouble(v);
  if (n == null) return '-';
  final r = (n * 100).round() / 100;
  return formatNumber(r == r.truncateToDouble() ? r.toInt() : r);
}

String _at(Object? v) {
  final t = liveTime(v);
  return t == null ? '-' : formatDateTime(t, seconds: true);
}

String _orderStatus(Object? s) => switch (s) {
  'submitted' || 'sent' => '전송',
  'accepted' => '접수',
  'partial' => '부분체결',
  'filled' => '체결완료',
  'rejected' => '거부',
  'failed' => '실패',
  'cancelled' || 'canceled' => '취소',
  _ => _text(s),
};

enum _Status {
  all('전체'),
  running('가동중'),
  stopped('중지됨');

  const _Status(this.label);
  final String label;
}

String _money(double v) => '${v > 0 ? '+' : ''}${formatNumber(v.round())}';

Color _pnlColor(double v) => v > 0
    ? AppColors.up
    : v < 0
    ? AppColors.down
    : AppColors.textPrimary;

/// 회원을 고르지 않았을 때 보는 전체 회원의 워커 표. 회원별·종목별로 찾는다.
class LiveWorkersTable extends StatefulWidget {
  const LiveWorkersTable({super.key, required this.onOpen, this.onOpenMember});

  final ValueChanged<LiveWorkerRow> onOpen;
  final ValueChanged<int>? onOpenMember; // 거래·포지션·로그·계좌 줄을 누르면 그 회원을 연다

  @override
  State<LiveWorkersTable> createState() => _LiveWorkersTableState();
}

class _LiveWorkersTableState extends State<LiveWorkersTable> {
  String _member = '';
  String _symbol = '';
  _Status _status = _Status.all;
  _Tab _tab = _Tab.workers;

  List<LiveWorkerRow> _filter(List<LiveWorkerRow> rows) {
    final member = _member.trim().toLowerCase();
    final symbol = _symbol.trim().toLowerCase();
    return [
      for (final r in rows)
        if (r.username.toLowerCase().contains(member) &&
            (r.symbolCode.toLowerCase().contains(symbol) || r.symbolName.toLowerCase().contains(symbol)) &&
            (_status == _Status.all || r.running == (_status == _Status.running)))
          r,
    ];
  }

  bool _matches(Member m, String text) =>
      m.username.toLowerCase().contains(_member.trim().toLowerCase()) &&
      text.toLowerCase().contains(_symbol.trim().toLowerCase());

  void _openMember(_Row row) => widget.onOpenMember?.call(row.$1.id);

  Future<List<_Row>> _trades() async {
    final rows = await liveRowsOfAllMembers('/orders?pageSize=$liveListLimit');
    int at(_Row r) => liveTime(r.$2['orderedAt'])?.millisecondsSinceEpoch ?? 0;
    return rows..sort((a, b) => at(b).compareTo(at(a)));
  }

  /// 계좌에 최신 잔고를 붙인다.
  Future<List<_Row>> _accounts() async {
    final data = await Future.wait([liveRowsOfAllMembers('/accounts'), liveRowsOfAllMembers('/balances')]);
    final balances = {for (final (_, b) in data[1]) b['accountId']: b};
    return [
      for (final (m, a) in data[0]) (m, {...a, ...?balances[a['accountId']]}),
    ];
  }

  Widget _tableOf(
    List<_Row> rows,
    List<String> columns,
    String Function(Map<String, dynamic>) searchText,
    List<Widget> Function(Map<String, dynamic>) cells,
  ) {
    final shown = [
      for (final r in rows)
        if (_matches(r.$1, searchText(r.$2))) r,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${formatNumber(shown.length)}건',
          style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        AdminTable(
          columns: ['회원', ...columns],
          columnSpacing: 12,
          emptyText: '조건에 맞는 내역이 없습니다.',
          onRowTap: (i) => _openMember(shown[i]),
          rows: [
            for (final r in shown)
              [Text(r.$1.username, style: const TextStyle(fontWeight: FontWeight.w600)), ...cells(r.$2)],
          ],
        ),
      ],
    );
  }

  Widget _tradesTable(BuildContext context, List<_Row> rows) => _tableOf(
    rows,
    const ['시각', '계좌', '구분', '종목', '방향', '수량', '체결가', '통화', '상태', '잡'],
    (o) => '${o['symbolCode']} ${o['symbolName']} ${o['jobName']}',
    (o) => [
      Text(_at(o['orderedAt'])),
      Text(_text(o['accountName'])),
      Text(o['isPaper'] == true ? '모의' : '실전'),
      Text(_text(o['symbolName'])),
      Text(
        o['side'] == 'buy'
            ? '매수'
            : o['side'] == 'sell'
            ? '매도'
            : '-',
        style: TextStyle(color: o['side'] == 'buy' ? AppColors.up : AppColors.down, fontWeight: FontWeight.w700),
      ),
      _right(Text('${_amount(o['filledQty'])}${_text(o['qtyUnit'])}')),
      _right(Text(_amount(o['avgFillPrice']))),
      Text(_text(o['currency'])),
      Text(_orderStatus(o['status'])),
      Text(_text(o['jobName'])),
    ],
  );

  Widget _positionsTable(BuildContext context, List<_Row> rows) => _tableOf(
    rows,
    const ['계좌', '구분', '종목코드', '종목명', '방향', '수량', '평균가', '통화', '잡'],
    (p) => '${p['symbolCode']} ${p['symbolName']} ${p['jobName']}',
    (p) => [
      Text(_text(p['accountName'])),
      Text(p['isPaper'] == true ? '모의' : '실전'),
      Text(_text(p['symbolCode']), style: const TextStyle(fontWeight: FontWeight.w600)),
      Text(_text(p['symbolName'])),
      Text(
        p['side'] == 'short' ? '매도' : '매수',
        style: TextStyle(color: p['side'] == 'short' ? AppColors.down : AppColors.up, fontWeight: FontWeight.w700),
      ),
      _right(Text('${_amount(p['size'])}${_text(p['qtyUnit'])}')),
      _right(Text(_amount(p['entryPrice']))),
      Text(_text(p['currency'])),
      Text(p['isManual'] == true ? '수동' : _text(p['jobName'])),
    ],
  );

  Widget _logsTable(BuildContext context, List<_Row> rows) => _tableOf(
    rows,
    const ['시각', '분류', '내용'],
    liveLogDetail,
    (l) => [
      Text(_at(l['at'])),
      Text(CustomerLogCategory.values.asNameMap()[l['category']]?.label ?? '-'),
      Text(liveLogDetail(l)),
    ],
  );

  Widget _accountsTable(BuildContext context, List<_Row> rows) => _tableOf(
    rows,
    const ['계좌', '계좌번호', '구분', '시장', '증권사', '통화', '예수금', '총자산', '사용'],
    (a) => '${a['accountName']} ${a['maskedAccountNumber']} ${a['marketType']}',
    (a) => [
      Text(_text(a['accountName'])),
      Text(_text(a['maskedAccountNumber'])),
      Text(a['isPaper'] == true ? '모의' : '실전'),
      Text(_text(a['marketType'])),
      Text(_text(a['brokerCode'])),
      Text(_text(a['currency'])),
      _right(Text(_amount(a['deposit']))),
      _right(Text(_amount(a['totalAsset']))),
      StatusBadge(
        a['isActive'] == true ? '사용' : '미사용',
        color: a['isActive'] == true ? AppColors.success : AppColors.textTertiary,
      ),
    ],
  );

  Widget _search(String hint, ValueChanged<String> onChanged) => SizedBox(
    width: 220,
    child: TextField(
      onChanged: onChanged,
      decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 20), hintText: hint),
    ),
  );

  Widget _right(Widget child) => Align(alignment: Alignment.centerRight, child: child);

  Widget _pnlText(Map<String, double> pnl) => _right(
    pnl.isEmpty
        ? const Text('-')
        : Text.rich(
            TextSpan(
              children: [
                for (final (i, e) in pnl.entries.indexed) ...[
                  if (i > 0) const TextSpan(text: ' · '),
                  TextSpan(
                    text: '${_money(e.value)} ${e.key}',
                    style: TextStyle(color: _pnlColor(e.value), fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
  );

  Widget _table(BuildContext context, List<LiveWorkerRow> all) {
    final rows = _filter(all);
    final totals = <String, double>{};
    for (final r in rows) {
      r.pnl.forEach((currency, v) => totals.update(currency, (t) => t + v, ifAbsent: () => v));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '워커 ${rows.length}개 · 가동중 ${rows.where((r) => r.running).length}개',
          style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        AdminTable(
          columns: const ['회원', '계좌', '구분', '종목코드', '종목명', '시장', '상태', '회차', '보유', '잡', '종료', '실현손익', '등록일'],
          columnSpacing: 12,
          emptyText: '조건에 맞는 워커가 없습니다.',
          onRowTap: (i) => widget.onOpen(rows[i]),
          rows: [
            for (final r in rows)
              [
                Text(r.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(r.accounts),
                Text(r.paper == null ? '-' : (r.paper! ? '모의' : '실전')),
                Text(r.symbolCode, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(r.symbolName),
                Text(r.market),
                StatusBadge(r.running ? '가동중' : '중지됨', color: r.running ? AppColors.success : AppColors.textTertiary),
                _right(Text(r.round)),
                Text(r.holding),
                _right(Text('${r.jobs}')),
                _right(Text('${r.finishedJobs}')),
                _pnlText(r.pnl),
                Text(r.insertedAt == null ? '-' : formatDateTime(r.insertedAt!)),
              ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('실현손익 합계  ', style: TextStyle(fontWeight: FontWeight.w700)),
            _pnlText(totals),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = ValueKey((_tab, liveStatus.value.revision));
    return AdminPage(
      title: '전체 회원',
      description: '전체 회원의 내역을 봅니다. 줄을 누르면 그 회원을 엽니다.',
      children: [
        Wrap(
          spacing: 6,
          children: [
            for (final t in _Tab.values)
              ChoiceChip(
                label: Text(t.label),
                visualDensity: VisualDensity.compact,
                selected: t == _tab,
                onSelected: (_) => setState(() => _tab = t),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _search('회원 아이디 검색', (v) => setState(() => _member = v)),
            _search('종목코드·종목명 검색', (v) => setState(() => _symbol = v)),
            if (_tab == _Tab.workers)
              for (final s in _Status.values)
                ChoiceChip(
                  label: Text(s.label),
                  visualDensity: VisualDensity.compact,
                  selected: s == _status,
                  onSelected: (_) => setState(() => _status = s),
                ),
          ],
        ),
        switch (_tab) {
          _Tab.workers => LiveLoader<List<LiveWorkerRow>>(key: key, load: liveAllWorkers, builder: _table),
          _Tab.trades => LiveLoader<List<_Row>>(key: key, load: _trades, builder: _tradesTable),
          _Tab.positions => LiveLoader<List<_Row>>(
            key: key,
            load: () => liveRowsOfAllMembers('/positions'),
            builder: _positionsTable,
          ),
          _Tab.logs => LiveLoader<List<_Row>>(key: key, load: liveAllLogs, builder: _logsTable),
          _Tab.accounts => LiveLoader<List<_Row>>(key: key, load: _accounts, builder: _accountsTable),
          _ => LiveLoader<List<_Row>>(
            key: key,
            load: () => liveRowsOfAllMembers(_tab.list!.path),
            builder: (context, rows) => _tableOf(rows, _tab.list!.columns, _tab.list!.searchText, _tab.list!.cells),
          ),
        },
      ],
    );
  }
}
