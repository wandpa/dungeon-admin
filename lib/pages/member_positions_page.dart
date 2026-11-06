import 'package:flutter/material.dart';

import '../mock_accounts.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'member_monitor_page.dart' show MonitorRequest, memberMonitorRequest;

enum _Filter {
  all('전체'),
  real('실전'),
  paper('모의'),
  manual('수동');

  const _Filter(this.label);
  final String label;

  bool matches(MemberPosition p) => switch (this) {
    _Filter.all => true,
    _Filter.real => !p.isPaper,
    _Filter.paper => p.isPaper,
    _Filter.manual => p.position.jobName == null,
  };
}

/// 전체 회원의 보유 포지션. 누르면 그 회원의 계좌·주문으로 이동한다.
class MemberPositionsPage extends StatefulWidget {
  const MemberPositionsPage({super.key});

  @override
  State<MemberPositionsPage> createState() => _MemberPositionsPageState();
}

class _MemberPositionsPageState extends State<MemberPositionsPage> {
  static const _pageSize = 20;

  String _query = '';
  _Filter _filter = _Filter.all;
  int _page = 0;

  String _num(double v) {
    final r = (v * 100).round() / 100;
    return formatNumber(r == r.truncateToDouble() ? r.toInt() : r);
  }

  String _signed(double v, String currency) => '${v > 0 ? '+' : ''}${_num(v)} $currency';

  /// 실전 평가손익. 통화가 다르면 합치지 않고 모의는 뺀다.
  String _realTotals(List<MemberPosition> rows) {
    final sums = <String, double>{};
    for (final r in rows.where((r) => !r.isPaper)) {
      final v = r.position.unrealizedPnl;
      if (v != null) sums.update(r.position.currency, (s) => s + v, ifAbsent: () => v);
    }
    return sums.isEmpty ? '-' : sums.entries.map((e) => _signed(e.value, e.key)).join(' · ');
  }

  void _open(MemberPosition r) {
    memberMonitorRequest.value = MonitorRequest(
      r.member.id,
      issue: const MemberIssue(MemberIssueKind.manualPositions, ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = allMemberPositions();
    final q = _query.trim().toLowerCase();
    final filtered = [
      for (final r in all)
        if (_filter.matches(r) &&
            (q.isEmpty ||
                r.member.username.toLowerCase().contains(q) ||
                r.position.symbolName.toLowerCase().contains(q) ||
                r.position.symbolCode.toLowerCase().contains(q)))
          r,
    ];
    final pageCount = (filtered.length / _pageSize).ceil().clamp(1, 1 << 30);
    final page = _page.clamp(0, pageCount - 1);

    return AdminPage(
      title: '회원 포지션',
      description: '전체 회원의 보유 포지션을 봅니다. 줄을 누르면 그 회원의 계좌·주문으로 이동합니다.',
      children: [
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '보유 ${filtered.length}건 · 회원 ${filtered.map((r) => r.member.id).toSet().length}명',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: '   실전 평가손익 ${_realTotals(filtered)}',
                  style: const TextStyle(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
        FilterBar(
          hint: '회원·종목 검색',
          filters: [for (final f in _Filter.values) '${f.label} ${all.where(f.matches).length}'],
          selectedIndex: _Filter.values.indexOf(_filter),
          onFilterSelected: (i) => setState(() {
            _filter = _Filter.values[i];
            _page = 0;
          }),
          onSearchChanged: (v) => setState(() {
            _query = v;
            _page = 0;
          }),
        ),
        AdminTable(
          columns: const ['회원', '종목', '방향', '수량', '평균가', '현재가', '평가손익', '잡', '계좌'],
          emptyText: '조건에 맞는 포지션이 없습니다.',
          rows: [
            for (final r in filtered.skip(page * _pageSize).take(_pageSize))
              [
                TextButton(onPressed: () => _open(r), child: Text(r.member.username)),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.position.symbolName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(r.position.symbolCode, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  ],
                ),
                StatusBadge(
                  r.position.position.sideLabel,
                  color: r.position.position.side == 'long' ? AppColors.up : AppColors.down,
                ),
                Text('${_num(r.position.position.size)}${r.position.qtyUnit}'),
                Text(_num(r.position.position.entryPrice)),
                Text(_num(r.position.currentPrice ?? 0)),
                Text(
                  r.position.unrealizedPnl == null ? '-' : _signed(r.position.unrealizedPnl!, r.position.currency),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: (r.position.unrealizedPnl ?? 0) > 0
                        ? AppColors.up
                        : (r.position.unrealizedPnl ?? 0) < 0
                        ? AppColors.down
                        : null,
                  ),
                ),
                r.position.jobName == null
                    ? const StatusBadge('수동', color: AppColors.warning)
                    : Text(r.position.jobName!),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(r.position.accountName),
                    if (r.isPaper) ...[const SizedBox(width: 6), const StatusBadge('모의', color: AppColors.down)],
                  ],
                ),
              ],
          ],
        ),
        Pager(
          page: page,
          pageCount: pageCount,
          summary: '총 ${filtered.length}건',
          onChanged: (p) => setState(() => _page = p),
        ),
      ],
    );
  }
}
