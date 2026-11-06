part of 'member_monitor_page.dart';

enum _TradeFilter {
  all('전체'),
  held('보유'),
  filled('체결'),
  waiting('미체결'),
  rejected('거부');

  const _TradeFilter(this.label);
  final String label;
}

/// 앱 내역 > 거래와 같은 화면. 보유 포지션 카드 뒤에 주문 목록이 이어진다.
class _TradesPane extends StatefulWidget {
  const _TradesPane({super.key, required this.positions, required this.orders, required this.onOpen});

  final List<AccountPosition> positions;
  final List<AccountOrder> orders;
  final void Function(int? workerId, String? jobName) onOpen;

  @override
  State<_TradesPane> createState() => _TradesPaneState();
}

class _TradesPaneState extends State<_TradesPane> {
  String _query = '';
  _TradeFilter _filter = _TradeFilter.all;

  bool _matches(String text) => text.toLowerCase().contains(_query.trim().toLowerCase());

  bool _orderInFilter(AccountOrder o) => switch (_filter) {
    _TradeFilter.all => true,
    _TradeFilter.held => false,
    _TradeFilter.filled => o.isFilled,
    _TradeFilter.waiting => o.isWaiting,
    _TradeFilter.rejected => o.isRejected,
  };

  Widget _cell(String label, Widget value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        const SizedBox(height: 4),
        value,
      ],
    ),
  );

  Widget _positionCard(AccountPosition p) {
    final pnl = p.unrealizedPnl;
    final position = p.position;
    final short = position.side == 'short';
    final tick = tickSizeOf(p.symbolCode);
    final price = p.currentPrice;
    final ticks = tick == null || price == null ? null : (price - position.entryPrice) * (short ? -1 : 1) / tick;
    const value = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: p.jobName == null ? null : () => widget.onOpen(p.workerId, p.jobName),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.symbolName} (${p.symbolCode})',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '계좌 ${p.accountName} · ${p.jobName ?? '연결된 job이 없음'}',
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (pnl != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _appSigned(pnl, p.currency),
                            style: TextStyle(color: _pnlColor(pnl), fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          if (ticks != null)
                            Text(
                              '${ticks > 0 ? '+' : ''}${_num(ticks)}T',
                              style: TextStyle(color: _pnlColor(pnl), fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _cell('현재가', Text(price == null ? '-' : _appPrice(price, p.currency), style: value)),
                    _cell('매입가', Text(_appPrice(position.entryPrice, p.currency), style: value)),
                    _cell(
                      short ? '매도수량' : '보유수량',
                      Text.rich(
                        TextSpan(
                          style: value,
                          children: [
                            TextSpan(
                              text: '${position.sideLabel} ',
                              style: TextStyle(color: short ? AppColors.down : AppColors.up),
                            ),
                            TextSpan(text: '${_num(position.size)}${p.qtyUnit}'),
                          ],
                        ),
                      ),
                    ),
                    // 앱의 수동 청산 버튼 자리. 관리자는 조회만 한다.
                    const OutlinedButton(onPressed: null, child: Text('수동')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _orderTile(AccountOrder o) {
    final buy = o.side == 'buy';
    final sideColor = o.isRejected
        ? AppColors.textTertiary
        : buy
        ? AppColors.up
        : AppColors.down;
    final state = o.isRejected
        ? '거부'
        : o.status == 'failed'
        ? '실패'
        : o.isFilled
        ? _appTime(o.at)
        : '대기';
    final stateColor = o.isRejected
        ? AppColors.up
        : o.isFilled
        ? AppColors.textTertiary
        : AppColors.textSecondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onOpen(o.workerId, o.jobName),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    o.isRejected ? '${o.sideLabel}거부' : o.sideLabel,
                    style: TextStyle(color: sideColor, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.symbolName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                        '계좌 ${o.accountName} · ${o.jobName}',
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                      ),
                      if (o.buyPrice != null && o.sellPrice != null)
                        Text(
                          '매수가 ${_appPrice(o.buyPrice!, o.currency)} · 매도가 ${_appPrice(o.sellPrice!, o.currency)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      if (o.message != null)
                        Text(o.message!, style: const TextStyle(color: AppColors.up, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      o.avgFillPrice == null
                          ? '-'
                          : '${_num(o.filledQty)}${o.qtyUnit} ${_appPrice(o.avgFillPrice!, o.currency)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    if (o.realizedPnl != null)
                      Text(
                        '손익 ${_appSigned(o.realizedPnl!, o.currency)}',
                        style: TextStyle(color: _pnlColor(o.realizedPnl!), fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    Text(state, style: TextStyle(color: stateColor, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showHeld = _filter == _TradeFilter.all || _filter == _TradeFilter.held;
    final positions = [
      if (showHeld)
        for (final p in widget.positions)
          if (_matches('${p.symbolName} ${p.symbolCode} ${p.jobName ?? ''}')) p,
    ];
    final orders = [
      for (final o in widget.orders)
        if (_orderInFilter(o) && _matches('${o.symbolName} ${o.jobName}')) o,
    ];
    return _Pane(
      title: '거래',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: '종목명·코드·전략 검색',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in _TradeFilter.values)
                  ChoiceChip(
                    label: Text(f.label, style: const TextStyle(fontSize: 13)),
                    visualDensity: VisualDensity.compact,
                    selected: f == _filter,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: positions.isEmpty && orders.isEmpty
                  ? _Empty(_filter == _TradeFilter.held ? '보유중인 포지션이 없어요' : '표시할 주문이 없어요')
                  : ListView(
                      children: [for (final p in positions) _positionCard(p), for (final o in orders) _orderTile(o)],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
