import 'package:flutter/material.dart';

import '../live_api.dart';
import '../live_strategy.dart';
import '../mock_data.dart';
import '../mock_workers.dart' show LiveSetting, strategyTemplateLabel;
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'live_view.dart';

String _text(Object? v) => v == null || v == '' ? '-' : '$v';

String _at(Object? v) {
  final t = liveTime(v);
  return t == null ? '-' : formatDateTime(t, seconds: true);
}

String _price(Object? v) {
  final n = liveDouble(v);
  if (n == null) return '-';
  final r = (n * 100).round() / 100;
  return formatNumber(r == r.truncateToDouble() ? r.toInt() : r);
}

String _mode(Object? v) => switch (v) {
  'real' => '실전',
  'paper' => '모의',
  'alert' => '알람',
  _ => _text(v),
};

Widget _side(Object? side) => Text(
  side == 'buy'
      ? '매수'
      : side == 'sell'
      ? '매도'
      : '-',
  style: TextStyle(color: side == 'buy' ? AppColors.up : AppColors.down, fontWeight: FontWeight.w500),
);

/// 회원 하나 또는 전체 회원에서 같은 모양으로 보여 주는 목록.
class LiveListDef {
  const LiveListDef(this.title, this.path, this.columns, this.searchText, this.cells, {this.emptyText = '내역이 없습니다.'});

  final String title;
  final String path; // /members/{id} 뒤
  final List<String> columns;
  final String Function(Map<String, dynamic>) searchText;
  final List<Widget> Function(Map<String, dynamic>) cells;
  final String emptyText;
}

final liveSignalList = LiveListDef(
  '신호',
  '/signals?pageSize=$liveListLimit',
  const ['시각', '종목코드', '종목명', '시장', '방향', '가격', '알람', '내용'],
  (s) => '${s['symbolCode']} ${s['symbolName']} ${s['alertName']}',
  (s) => [
    Text(_at(s['triggeredAt'])),
    Text(_text(s['symbolCode']), style: const TextStyle(fontWeight: FontWeight.w500)),
    Text(_text(s['symbolName'])),
    Text(_text(s['marketType'])),
    _side(s['side']),
    Align(alignment: Alignment.centerRight, child: Text(_price(s['price']))),
    Text(_text(s['alertName'])),
    SizedBox(width: 320, child: Text(_text(s['message']))),
  ],
  emptyText: '신호가 없습니다.',
);

final liveStrategyList = LiveListDef(
  '전략',
  '/templates',
  const ['전략 이름', '종류', '시장', '고정', '등록일', '수정일'],
  (t) => '${t['name']} ${strategyTemplateLabel(_text(t['baseTemplateId']))}',
  (t) => [
    Text(_text(t['name']), style: const TextStyle(fontWeight: FontWeight.w500)),
    Text(strategyTemplateLabel(_text(t['baseTemplateId']))),
    Text(_text(t['marketType'])),
    Text(t['isFixed'] == true ? '고정' : '-'),
    Text(_at(t['insertedAt'])),
    Text(_at(t['updatedAt'])),
  ],
  emptyText: '저장한 전략이 없습니다.',
);

final liveWatchlist = LiveListDef(
  '관심종목',
  '/watchlist',
  const ['종목코드', '종목명', '거래소', '시장', '구분', '등록일'],
  (w) => '${w['symbolCode']} ${w['symbolName']}',
  (w) => [
    Text(_text(w['symbolCode']), style: const TextStyle(fontWeight: FontWeight.w500)),
    Text(_text(w['symbolName'])),
    Text(_text(w['exchange'])),
    Text(_text(w['marketType'])),
    Text(_mode(w['mode'])),
    Text(_at(w['insertedAt'])),
  ],
  emptyText: '관심종목이 없습니다.',
);

final liveMemberSymbols = LiveListDef(
  '종목',
  '/symbols',
  const ['계좌', '구분', '종목코드', '종목명', '거래소', '시장', '워커', '사용', '등록일'],
  (s) => '${s['symbolCode']} ${s['symbolName']} ${s['accountName']}',
  (s) => [
    Text(_text(s['accountName'])),
    Text(_mode(s['kind'])),
    Text(_text(s['symbolCode']), style: const TextStyle(fontWeight: FontWeight.w500)),
    Text(_text(s['symbolName'])),
    Text(_text(s['exchange'])),
    Text(_text(s['marketType'])),
    Text(switch (s['workerStatus']) {
      'running' => '가동중',
      'stopped' => '중지됨',
      _ => '없음',
    }),
    StatusBadge(
      s['isActive'] == true ? '사용' : '미사용',
      color: s['isActive'] == true ? AppColors.success : AppColors.textTertiary,
    ),
    Text(_at(s['insertedAt'])),
  ],
  emptyText: '등록한 종목이 없습니다.',
);

/// 전략의 앱 설정 항목. 앱 전략 상세와 같은 말을 쓴다.
class LiveStrategySettings extends StatelessWidget {
  const LiveStrategySettings(this.template, {super.key, required this.onClose});

  final Map<String, dynamic> template;
  final VoidCallback onClose;

  String _value(LiveSetting s) => s.isToggle ? (s.on == true ? '켜짐' : '꺼짐') : s.value;

  @override
  Widget build(BuildContext context) {
    final t = template;
    final market = t['marketType'] as String? ?? '';
    final params = (t['templateParams'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final items = liveSettings(
      templateId: t['baseTemplateId'] as String? ?? '',
      params: params,
      marketType: market,
      qtyUnit: market.endsWith('선물') ? '계약' : '주',
      isAlert: false,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_text(t['name']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            IconButton(tooltip: '설정 닫기', onPressed: onClose, icon: const Icon(Icons.close, size: 18)),
          ],
        ),
        Text(
          strategyTemplateLabel(_text(t['baseTemplateId'])),
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('표시할 설정이 없습니다.', style: TextStyle(color: AppColors.textTertiary))
        else
          for (final s in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(s.label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _value(s),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// 회원 한 명의 목록.
class LiveMemberList extends StatefulWidget {
  const LiveMemberList({super.key, required this.member, required this.def});

  final Member member;
  final LiveListDef def;

  @override
  State<LiveMemberList> createState() => _LiveMemberListState();
}

class _LiveMemberListState extends State<LiveMemberList> {
  String _query = '';
  Map<String, dynamic>? _opened; // 설정을 볼 전략

  bool get _strategies => identical(widget.def, liveStrategyList);

  Widget _table(BuildContext context, List<Map<String, dynamic>> rows) {
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final r in rows)
        if (widget.def.searchText(r).toLowerCase().contains(q)) r,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${formatNumber(shown.length)}건',
          style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        AdminTable(
          exportName: '${widget.member.username}_${widget.def.title}',
          exportMemberLiveId: widget.member.liveId,
          columns: widget.def.columns,
          columnSpacing: 12,
          emptyText: widget.def.emptyText,
          onRowTap: _strategies ? (i) => setState(() => _opened = shown[i]) : null,
          highlightedRow: _opened == null ? null : shown.indexOf(_opened!),
          rows: [for (final r in shown) widget.def.cells(r)],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final opened = _opened;
    return AdminPage(
      title: '${widget.member.username} ${widget.def.title}',
      description: _strategies ? '줄을 누르면 전략 설정이 나옵니다.' : '회원이 앱에서 보는 ${widget.def.title} 내역입니다.',
      side: opened == null ? null : LiveStrategySettings(opened, onClose: () => setState(() => _opened = null)),
      children: [
        SizedBox(
          width: 280,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 280,
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 20), hintText: '검색'),
              ),
            ),
          ),
        ),
        LiveLoader<List<Map<String, dynamic>>>(
          load: () => liveItems('/members/${widget.member.liveId}${widget.def.path}'),
          builder: _table,
        ),
      ],
    );
  }
}
