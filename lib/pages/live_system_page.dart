import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_data.dart' show formatDateTime;
import '../mock_system.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'live_view.dart';
import 'system_page.dart' show systemLevelColor, systemLevelIcon;

class _Data {
  const _Data(this.status, this.markets, this.issues);
  final Map<String, dynamic> status;
  final Map<String, dynamic> markets;
  final Map<String, dynamic> issues;
}

Future<_Data> _load() async {
  final rows = await Future.wait<dynamic>([
    liveGet('/system/status'),
    liveGet('/system/markets'),
    liveGet('/system/market-issues'),
  ]);
  return _Data(rows[0] as Map<String, dynamic>, rows[1] as Map<String, dynamic>, rows[2] as Map<String, dynamic>);
}

List<Map<String, dynamic>> _rows(Map<String, dynamic> map, String key) =>
    (map[key] as List? ?? const []).cast<Map<String, dynamic>>();

String _text(Object? v) => v == null || v == '' ? '-' : '$v';

String _time(Object? v) {
  final t = liveTime(v);
  return t == null ? '-' : formatDateTime(t);
}

/// 테스트 DB 값으로 만든 시스템 상태. 수준은 확정 전의 임시 기준이다.
class LiveSystemPage extends StatelessWidget {
  const LiveSystemPage({super.key});

  Widget _component(Map<String, dynamic> c) {
    final level = liveLevel(c['level']);
    final color = systemLevelColor(level);
    final metrics = (c['metrics'] as Map? ?? const {}).cast<String, dynamic>();
    return SizedBox(
      width: 260,
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(systemLevelIcon(level), size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_text(c['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                StatusBadge(level.label, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '마지막 기록 ${_time(c['lastSeenAt'])}',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                for (final MapEntry(:key, :value) in metrics.entries)
                  Text('$key  $value', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiveLoader<_Data>(
      load: _load,
      builder: (context, d) {
        final overall = liveLevel(d.status['level']);
        final groups = <String, List<Map<String, dynamic>>>{};
        for (final c in _rows(d.status, 'components')) {
          (groups[_text(c['group'])] ??= []).add(c);
        }
        Widget issueTable(String title, String key) {
          final rows = _rows(d.issues, key);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('$title ${rows.length}건', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              AdminTable(
                columns: const ['종목', '시장', '사유', '발견 시각'],
                emptyText: '해당 종목이 없습니다.',
                rows: [
                  for (final r in rows)
                    [
                      Text(_text(r['symbolCode'])),
                      Text(_text(r['marketType'])),
                      Text(_text(r['reason'])),
                      Text(_time(r['detectedAt'])),
                    ],
                ],
              ),
            ],
          );
        }

        return AdminPage(
          title: '시스템 상태',
          description: '테스트 DB 기록으로 추정한 상태입니다. 수준은 확정 전의 임시 기준입니다.',
          children: [
            Panel(
              child: Row(
                children: [
                  Icon(systemLevelIcon(overall), color: systemLevelColor(overall), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overall == SystemLevel.ok ? '모든 시스템 정상 (임시 기준)' : '전체 상태: ${overall.label} (임시 기준)',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '확인 시각 ${_time(d.status['checkedAt'])}',
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final MapEntry(key: group, value: list) in groups.entries)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 12, runSpacing: 12, children: [for (final c in list) _component(c)]),
                ],
              ),
            const Text('시장별 오늘 세션', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            AdminTable(
              columns: const ['시장', '현지 날짜', '시간대', '거래일', '개장', '폐장'],
              emptyText: '시장 정보가 없습니다.',
              rows: [
                for (final m in _rows(d.markets, 'markets'))
                  [
                    Text(_text(m['marketLabel'])),
                    Text(_text(m['localDate'])),
                    Text(_text(m['tz'])),
                    Text(m['isTradingDay'] == true ? '거래일' : '휴장'),
                    Text(_text(m['openTime'])),
                    Text(_text(m['closeTime'])),
                  ],
              ],
            ),
            const Text('휴장일', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            AdminTable(
              columns: const ['날짜', '이름', '시장'],
              emptyText: '등록된 휴장일이 없습니다.',
              rows: [
                for (final h in _rows(d.markets, 'holidays'))
                  [Text(_text(h['date'])), Text(_text(h['name'])), Text(_text(h['market']))],
              ],
            ),
            issueTable('마스터 누락 종목', 'missing'),
            issueTable('시세 불가 종목', 'quoteUnavailable'),
          ],
        );
      },
    );
  }
}
