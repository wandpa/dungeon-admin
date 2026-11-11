import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'live_view.dart';

String _t(Object? v) => liveTime(v) == null ? '-' : formatDateTime(liveTime(v)!, seconds: true);

String _n(Object? v) {
  final d = liveDouble(v);
  if (d == null) return '-';
  return formatNumber(d == d.truncateToDouble() ? d.toInt() : d);
}

String _side(Object? v) => switch (v) {
  'buy' => '매수',
  'sell' => '매도',
  _ => v == null ? '-' : '$v',
};

String _yes(Object? v) => v == true
    ? '예'
    : v == false
    ? '아니오'
    : '-';

Future<void> _show(BuildContext context, String title, String note, Widget body) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 640),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                IconButton(tooltip: '닫기', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            Text(note, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            const SizedBox(height: 8),
            Flexible(child: SingleChildScrollView(child: body)),
          ],
        ),
      ),
    ),
  ),
);

/// 주문 하나의 실제 체결 내역(분할 체결). 테스트 DB order_fills.
Future<void> showLiveFills(BuildContext context, {required String memberLiveId, required String orderLiveId, required String title}) =>
    _show(
      context,
      '$title 체결 내역',
      '증권사에서 받은 체결 하나하나입니다. 주문의 체결 수량·평균가는 이 값을 합친 것입니다.',
      LiveLoader<List<Map<String, dynamic>>>(
        load: () => liveItems('/members/$memberLiveId/orders/$orderLiveId/fills'),
        builder: (context, rows) => AdminTable(
          exportName: '${title.replaceAll(' ', '_')}_체결',
          exportMemberLiveId: memberLiveId,
          columns: const ['체결 시각', '구분', '수량', '체결가', '통화', '체결번호', '주문번호', '모의'],
          emptyText: '체결 기록이 없습니다.',
          rows: [
            for (final f in rows)
              [
                Text(_t(f['filledAt'])),
                Text(_side(f['side'])),
                Align(alignment: Alignment.centerRight, child: Text(_n(f['qty']))),
                Align(alignment: Alignment.centerRight, child: Text(_n(f['price']))),
                Text('${f['currency'] ?? '-'}'),
                Text('${f['execNo'] ?? '-'}'),
                Text('${f['orderNo'] ?? '-'}'),
                Text(_yes(f['isPaper'])),
              ],
          ],
        ),
      ),
    );

/// 잡의 예약 주문. 엔진이 내려던 주문과 상태다. 상태 값의 뜻은 엔진 확인 전이라 원문을 보여 준다.
Future<void> showLiveReservations(
  BuildContext context, {
  required String memberLiveId,
  required String jobLiveId,
  required String jobName,
}) => _show(
  context,
  '$jobName 예약 주문',
  '엔진이 주문을 내기 전에 남기는 예약입니다. 상태·종류는 DB 값 그대로이며 뜻은 엔진 담당 확인 대기입니다.',
  LiveLoader<Map<String, dynamic>>(
    load: () async => await liveGet('/members/$memberLiveId/jobs/$jobLiveId/reservations?pageSize=200') as Map<String, dynamic>,
    builder: (context, body) {
      final rows = (body['items'] as List).cast<Map<String, dynamic>>();
      final counts = body['counts'];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (counts is Map && counts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                [for (final e in counts.entries) '${e.key} ${e.value}'].join(' · '),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          AdminTable(
            exportName: '${jobName.replaceAll(' ', '_')}_예약주문',
            exportMemberLiveId: memberLiveId,
            columns: const ['만든 시각', '구분', '수량', '상태', '종류', '판정 시각', '보낸 시각', '만료', '주문번호'],
            emptyText: '예약 주문이 없습니다.',
            rows: [
              for (final r in rows)
                [
                  Text(_t(r['createdAt'])),
                  Text(_side(r['side'])),
                  Align(alignment: Alignment.centerRight, child: Text(_n(r['qty']))),
                  Text('${r['status'] ?? '-'}'),
                  Text('${r['kind'] ?? '-'}'),
                  Text(_t(r['judgeAt'])),
                  Text(_t(r['sendingAt'])),
                  Text(_t(r['expiresAt'])),
                  Text('${r['orderNo'] ?? '-'}'),
                ],
            ],
          ),
          if ((body['total'] as int? ?? rows.length) > rows.length)
            Text(
              '최근 ${rows.length}건만 보여 줍니다 (전체 ${body['total']}건).',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
        ],
      );
    },
  ),
);
