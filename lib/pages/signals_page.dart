import 'package:flutter/material.dart';

import '../mock_admin.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

class SignalsPage extends StatefulWidget {
  const SignalsPage({super.key});

  @override
  State<SignalsPage> createState() => _SignalsPageState();
}

class _SignalsPageState extends State<SignalsPage> {
  static const _markets = ['전체', '국내주식', '해외주식', '국내선물', '해외선물'];

  String _query = '';
  int _market = 0;
  bool _showHidden = false;

  List<Signal> get _visible {
    final q = _query.trim().toLowerCase();
    return [
      for (final s in mockSignals)
        if ((_market == 0 || s.marketType == _markets[_market]) &&
            (_showHidden || !s.hidden) &&
            (q.isEmpty || s.symbolName.toLowerCase().contains(q) || s.symbolCode.toLowerCase().contains(q)))
          s,
    ];
  }

  int _count(int market) => mockSignals.where((s) => market == 0 || s.marketType == _markets[market]).length;

  Future<void> _toggleHidden(Signal s) async {
    final ok = await showConfirmDialog(
      context,
      title: s.hidden ? '신호 다시 보이기' : '신호 숨기기',
      message: s.hidden
          ? '${s.symbolName} ${s.alertName} 신호를 앱에 다시 보이게 합니다.'
          : '${s.symbolName} ${s.alertName} 신호를 앱 신호 내역에서 숨깁니다.',
      confirmText: s.hidden ? '다시 보이기' : '숨기기',
      destructive: !s.hidden,
    );
    if (!ok || !mounted) return;
    setState(() {
      s.hidden = !s.hidden;
      logActivity(ActivityKind.signal, '#${s.id} ${s.symbolName} ${s.alertName} ${s.hidden ? '숨김' : '다시 보임'}');
    });
    showMessage(context, s.hidden ? '신호를 숨겼습니다.' : '신호를 다시 보이게 했습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final hidden = mockSignals.where((s) => s.hidden).length;
    final canHide = can(AdminPermission.hideSignals);
    return AdminPage(
      title: '신호 관리',
      description: '앱으로 발송된 매수·매도 신호를 조회하고 숨깁니다.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterBar(
              hint: '종목명·종목코드 검색',
              filters: [for (final (i, m) in _markets.indexed) '$m ${_count(i)}'],
              selectedIndex: _market,
              onFilterSelected: (i) => setState(() => _market = i),
              onSearchChanged: (v) => setState(() => _query = v),
            ),
            FilterChip(
              label: Text('숨긴 신호 포함 $hidden'),
              selected: _showHidden,
              onSelected: (v) => setState(() => _showHidden = v),
            ),
          ],
        ),
        AdminTable(
          columns: const ['번호', '발생 시각', '시장', '종목', '전략', '구분', '가격', ''],
          emptyText: '조건에 맞는 신호가 없습니다.',
          rows: [
            for (final s in _visible)
              [
                Text('${s.id}'),
                Text(formatDateTime(s.triggeredAt, seconds: true)),
                Text(s.marketType),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.symbolName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(s.symbolCode, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  ],
                ),
                Text(s.alertName),
                StatusBadge(s.side == 'buy' ? '매수' : '매도', color: s.side == 'buy' ? AppColors.up : AppColors.down),
                Text(formatNumber(s.price)),
                canHide
                    ? TextButton(onPressed: () => _toggleHidden(s), child: Text(s.hidden ? '다시 보이기' : '숨기기'))
                    : (s.hidden ? const StatusBadge('숨김', color: AppColors.textTertiary) : const SizedBox.shrink()),
              ],
          ],
        ),
      ],
    );
  }
}
