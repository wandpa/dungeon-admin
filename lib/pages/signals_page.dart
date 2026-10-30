import 'package:flutter/material.dart';

import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

class SignalsPage extends StatelessWidget {
  const SignalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: '신호 관리',
      description: '앱으로 발송된 매수·매도 신호를 조회합니다.',
      children: [
        const FilterBar(
          hint: '종목명·종목코드 검색',
          filters: ['전체', '국내주식', '해외주식', '국내선물', '해외선물'],
        ),
        AdminTable(
          columns: const ['번호', '발생 시각', '시장', '종목', '전략', '구분', '가격', ''],
          rows: [
            for (final s in mockSignals)
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
                StatusBadge(
                  s.side == 'buy' ? '매수' : '매도',
                  color: s.side == 'buy' ? AppColors.up : AppColors.down,
                ),
                Text(formatNumber(s.price)),
                TextButton(onPressed: () => showNotConnected(context), child: const Text('숨기기')),
              ],
          ],
        ),
      ],
    );
  }
}
