import 'package:flutter/material.dart';

import '../file_download.dart';
import '../live_api.dart';
import '../mock_admin.dart' show AdminPermission, can;
import '../mock_data.dart';
import '../mock_workers.dart' show CustomerLogCategory;
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'live_lists.dart';
import 'live_view.dart';

enum _Tab {
  workers('워커', '/workers'),
  alerts('알람', '/workers'),
  trades('거래', '/orders'),
  positions('포지션', '/positions'),
  logs('로그', '/logs'),
  accounts('계좌', '/accounts'),
  signals('신호', '/signals'),
  strategies('전략', '/templates'),
  watchlist('관심종목', '/watchlist'),
  symbols('종목', '/subscriptions');

  const _Tab(this.label, this.path);
  final String label;
  final String path; // 전체 회원 경로

  /// 계좌와 전략은 종목 조건이 없다.
  bool get hasSymbolSearch => this != accounts && this != strategies;

  LiveListDef? get list => switch (this) {
    signals => liveSignalList,
    strategies => liveStrategyList,
    watchlist => liveWatchlist,
    symbols => liveMemberSymbols,
    _ => null,
  };
}

typedef _Row = Map<String, dynamic>;

/// 한 쪽에 보여 줄 줄 수.
const _pageSize = 50;

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

String _orderKind(Map<String, dynamic> o) => switch (o['kind']) {
  'entry' => '진입',
  'exit' => ['청산', ?liveExitLabel(o['exitReason'] as String?)].join(' · '),
  _ => '-',
};

enum _OrderGroup {
  filled('체결'),
  waiting('대기'),
  rejected('거부');

  const _OrderGroup(this.label);
  final String label;
}

String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum _Status {
  all('전체', null),
  running('가동중', 'running'),
  stopped('중지됨', 'stopped');

  const _Status(this.label, this.query);
  final String label;
  final String? query;
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
  final _debounce = SearchDebounce();
  final _memberField = TextEditingController();
  final _symbolField = TextEditingController(); // 종목 조건이 없는 탭을 다녀와도 글자가 남는다
  String _member = '';
  String _symbol = '';
  _Status _status = _Status.all;
  _Tab _tab = _Tab.workers;
  int _page = 1;
  DateTimeRange? _range; // 거래·로그 기간
  _OrderGroup? _group;
  String? _accountId;
  CustomerLogCategory? _category;
  Future<Map<String, dynamic>>? _accountList; // 계좌 조건에 쓴다
  final _kinds = <String>{}; // 워커 탭의 실전·모의·알람 조건. 비면 전체
  bool _exporting = false;

  @override
  void dispose() {
    _debounce.dispose();
    _memberField.dispose();
    _symbolField.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) => setState(() {
    change();
    _page = 1;
  });

  /// 두 검색칸이 대기를 함께 쓰므로 입력이 멈추면 두 칸의 값을 같이 읽는다.
  void _searchLater() => _debounce(() {
    if (!mounted) return;
    _update(() {
      _member = _memberField.text;
      _symbol = _symbolField.text;
    });
  });

  void _openMember(_Row row) => widget.onOpenMember?.call(liveIntId(row['memberId'] as String));

  /// 지금 탭의 서버 조건.
  Map<String, String> get _filters => {
    if ((_tab == _Tab.trades || _tab == _Tab.logs) && _range != null) ...{
      'from': _day(_range!.start),
      'to': _day(_range!.end),
    },
    if (_tab == _Tab.trades && _group != null) 'group': _group!.name,
    if (_tab == _Tab.trades && _accountId != null) 'accountId': _accountId!,
    if (_tab == _Tab.logs && _category != null) 'category': _category!.name,
    if (_tab == _Tab.alerts) 'kind': 'alert',
    if (_tab == _Tab.workers && _kinds.isNotEmpty) 'kind': _kinds.join(','),
  };

  /// 지금 조건의 전체 목록을 서버가 만든 CSV 로 내려받는다. 페이지와 상관없이 모두 나간다.
  Future<void> _exportAll() async {
    setState(() => _exporting = true);
    try {
      final signals = _tab == _Tab.signals;
      final csv = await liveAllCsv(
        _tab.path,
        member: _member,
        symbol: _tab.hasSymbolSearch ? _symbol : '',
        memberKey: signals ? 'member' : 'q',
        symbolKey: signals ? 'q' : 'symbol',
        status: _tab == _Tab.workers || _tab == _Tab.alerts ? _status.query : null,
        filters: _filters,
      );
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      downloadCsv('전체_${_tab.label}_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.csv', csv);
      adminStatus.value = '전체 ${_tab.label}을(를) 내보냈습니다.';
    } on LiveApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<Map<String, dynamic>> _load() {
    final symbol = _tab.hasSymbolSearch ? _symbol : '';
    return switch (_tab) {
      _Tab.signals => liveAllList(
        _tab.path,
        member: _member,
        symbol: symbol,
        memberKey: 'member',
        symbolKey: 'q',
        page: _page,
        pageSize: _pageSize,
      ),
      _Tab.logs => liveAllLogs(member: _member, symbol: symbol, filters: _filters, page: _page, pageSize: _pageSize),
      _ => liveAllList(
        _tab.path,
        member: _member,
        symbol: symbol,
        status: _tab == _Tab.workers || _tab == _Tab.alerts ? _status.query : null,
        filters: _filters,
        page: _page,
        pageSize: _pageSize,
      ),
    };
  }

  List<_Row> _items(Map<String, dynamic> body) => (body['items'] as List).cast<_Row>();

  Widget _pager(Map<String, dynamic> body) => LivePager(
    total: body['total'] as int? ?? 0,
    page: _page,
    pageSize: _pageSize,
    onPage: (p) => setState(() => _page = p),
  );

  Widget _tableOf(
    Map<String, dynamic> body,
    List<String> columns,
    List<Widget> Function(Map<String, dynamic>) cells, {
    Widget? summary,
  }) {
    final rows = _items(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${formatNumber(body['total'] as int? ?? 0)}건',
          style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        AdminTable(
          exportName: '전체_${_tab.label}',
          columns: ['회원', ...columns],
          columnSpacing: 12,
          emptyText: '조건에 맞는 내역이 없습니다.',
          onRowTap: (i) => _openMember(rows[i]),
          rows: [
            for (final r in rows)
              [Text(_text(r['username']), style: const TextStyle(fontWeight: FontWeight.w600)), ...cells(r)],
          ],
        ),
        if (summary != null) ...[const SizedBox(height: 8), summary],
        _pager(body),
      ],
    );
  }

  /// 조건 전체의 주문 합계. 실전과 모의, 통화를 나눠 보여 준다. 삭제된 워커의 주문까지 더한 값이다.
  Widget _orderTotals(Map<String, dynamic> body) {
    final totals = (body['totals'] as List? ?? const []).cast<_Row>();
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 16,
      children: [
        if (totals.isNotEmpty)
          const Text(
            '합계(삭제된 워커 포함)',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        for (final t in totals)
          Text(
            '${t['isPaper'] == true ? '모의' : '실전'} ${_text(t['currency'])} · 주문 ${_amount(t['orders'])}건'
            ' · 체결 ${_amount(t['filled'])}건 · 손익 ${_amount(t['realizedPnl'])}',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
      ],
    );
  }

  Widget _tradesTable(BuildContext context, Map<String, dynamic> body) => _tableOf(
    body,
    const ['시각', '계좌', '구분', '종목', '방향', '회차', '진입·청산', '수량', '체결가', '통화', '상태', '잡', '손익'],
    (o) {
      final pnl = liveDouble(o['realizedPnl']);
      return [
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
        _right(Text(_text(o['cycleNo']))),
        Text(_orderKind(o)),
        _right(Text('${_amount(o['filledQty'])}${_text(o['qtyUnit'])}')),
        _right(Text(_amount(o['avgFillPrice']))),
        Text(_text(o['currency'])),
        Text(_orderStatus(o['status'])),
        Text(_text(o['jobName'])),
        _right(
          pnl == null
              ? const Text('-')
              : Text(
                  _money(pnl),
                  style: TextStyle(color: _pnlColor(pnl), fontWeight: FontWeight.w700),
                ),
        ),
      ];
    },
    summary: _orderTotals(body),
  );

  Widget _positionsTable(BuildContext context, Map<String, dynamic> body) => _tableOf(
    body,
    const ['계좌', '구분', '종목코드', '종목명', '방향', '수량', '평균가', '통화', '잡'],
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

  Widget _logsTable(BuildContext context, Map<String, dynamic> body) => _tableOf(
    body,
    const ['시각', '분류', '내용'],
    (l) => [
      Text(_at(l['at'])),
      Text(CustomerLogCategory.values.asNameMap()[l['category']]?.label ?? '-'),
      Text(liveLogDetail(l)),
    ],
  );

  Widget _accountsTable(BuildContext context, Map<String, dynamic> body) => _tableOf(
    body,
    const ['계좌', '계좌번호', '구분', '시장', '증권사', '통화', '예수금', '총자산', '사용'],
    (a) => [
      Text(_text(a['accountName'])),
      Text(_text(a['maskedAccountNumber'])),
      Text(liveKindLabel(a['kind'])),
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

  Widget _search(String hint, TextEditingController controller) => SizedBox(
    width: 220,
    child: TextField(
      controller: controller,
      onChanged: (_) => _searchLater(),
      decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 20), hintText: hint),
    ),
  );

  Widget _dropdown<T>(String hint, T? value, List<(T, String)> items, ValueChanged<T?> onChanged) => DropdownButton<T?>(
    value: value,
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
    items: [
      DropdownMenuItem<T?>(child: Text(hint)),
      for (final (v, label) in items) DropdownMenuItem<T?>(value: v, child: Text(label)),
    ],
    onChanged: (v) => _update(() {
      onChanged(v);
    }),
  );

  /// 계좌 조건. 목록을 받지 못해도 나머지 조건은 쓸 수 있다.
  Widget _accountFilter() => FutureBuilder<Map<String, dynamic>>(
    future: _accountList ??= liveAllList('/accounts', page: 1, pageSize: liveListLimit),
    builder: (context, snapshot) {
      final rows = ((snapshot.data?['items'] as List?) ?? const []).cast<_Row>();
      return _dropdown<String>(
        '전체 계좌',
        _accountId,
        [
          for (final a in rows)
            (a['accountId'] as String, '${_text(a['username'])} ${_text(a['accountName'])}(${_text(a['maskedAccountNumber'])})'),
        ],
        (v) => _accountId = v,
      );
    },
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

  Widget _table(BuildContext context, Map<String, dynamic> body) {
    final rows = [for (final w in _items(body)) liveWorkerRow(w)];
    final totals = body['totals'] as Map<String, dynamic>? ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_tab.label} ${body['total'] ?? rows.length}개 · 가동중 ${totals['running'] ?? '-'}개',
          style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        AdminTable(
          exportName: '전체_${_tab.label}',
          columns: const ['회원', '계좌', '구분', '종목코드', '종목명', '시장', '상태', '회차', '보유', '잡', '종료', '실현손익', '등록일'],
          columnSpacing: 12,
          emptyText: '조건에 맞는 워커가 없습니다.',
          onRowTap: (i) => widget.onOpen(rows[i]),
          rows: [
            for (final r in rows)
              [
                Text(r.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(r.accounts),
                Text(r.kind),
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
        // 알람은 주문을 내지 않아 손익이 없다.
        if (_tab == _Tab.workers) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('실현손익 합계(활성 워커 기준)  ', style: TextStyle(fontWeight: FontWeight.w700)),
              _pnlText(livePnl(totals['pnl'])),
            ],
          ),
        ],
        _pager(body),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = ValueKey((_tab, liveStatus.value.revision, _member, _symbol, _status, _page, _filters.toString()));
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
                onSelected: (_) => _update(() => _tab = t),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _search('회원 아이디 검색', _memberField),
            if (_tab.hasSymbolSearch) _search('종목코드·종목명 검색', _symbolField),
            if (_tab == _Tab.workers || _tab == _Tab.alerts)
              for (final s in _Status.values)
                ChoiceChip(
                  label: Text(s.label),
                  visualDensity: VisualDensity.compact,
                  selected: s == _status,
                  onSelected: (_) => _update(() => _status = s),
                ),
            if (_tab == _Tab.workers)
              for (final (k, label) in const [('real', '실전'), ('paper', '모의'), ('alert', '알람')])
                FilterChip(
                  label: Text(label),
                  visualDensity: VisualDensity.compact,
                  selected: _kinds.contains(k),
                  onSelected: (v) => _update(() => v ? _kinds.add(k) : _kinds.remove(k)),
                ),
            if (_tab == _Tab.trades || _tab == _Tab.logs)
              DateRangeFilter(range: _range, onChanged: (r) => _update(() => _range = r)),
            if (_tab == _Tab.trades) ...[
              _dropdown<_OrderGroup>('전체 상태', _group, [for (final g in _OrderGroup.values) (g, g.label)], (v) => _group = v),
              _accountFilter(),
            ],
            if (_tab == _Tab.logs)
              _dropdown<CustomerLogCategory>(
                '전체 분류',
                _category,
                [
                  for (final c in CustomerLogCategory.values)
                    if (c != CustomerLogCategory.access) (c, c.label), // 접속 기록은 아직 없다
                ],
                (v) => _category = v,
              ),
          ],
        ),
        if (can(AdminPermission.exportMembers))
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _exporting ? null : _exportAll,
              icon: _exporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download, size: 18),
              label: Text('전체 ${_tab.label} 엑셀 (모든 쪽)'),
            ),
          ),
        LiveLoader<Map<String, dynamic>>(
          key: key,
          load: _load,
          builder: switch (_tab) {
            _Tab.workers || _Tab.alerts => _table,
            _Tab.trades => _tradesTable,
            _Tab.positions => _positionsTable,
            _Tab.logs => _logsTable,
            _Tab.accounts => _accountsTable,
            _ => (context, body) => _tableOf(body, _tab.list!.columns, _tab.list!.cells),
          },
        ),
      ],
    );
  }
}
