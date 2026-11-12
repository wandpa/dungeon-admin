import 'package:flutter/material.dart';

import '../mock_admin.dart';
import '../mock_data.dart';
import '../mock_system.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

Color systemLevelColor(SystemLevel l) => switch (l) {
  SystemLevel.ok => AppColors.success,
  SystemLevel.degraded => AppColors.warning,
  SystemLevel.down => AppColors.up,
};

IconData systemLevelIcon(SystemLevel l) => switch (l) {
  SystemLevel.ok => Icons.check_circle_outline,
  SystemLevel.degraded => Icons.warning_amber_rounded,
  SystemLevel.down => Icons.error_outline,
};

/// 고객 문의보다 먼저 이상을 찾기 위한 화면. 연결 상태와 장애 기록을 본다.
class SystemPage extends StatefulWidget {
  const SystemPage({super.key});

  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  bool _showResolved = false;
  SystemIncident? _opened; // 내용을 펼쳐 볼 장애

  Future<void> _change(SystemIncident i, IncidentStatus status) async {
    if (status == IncidentStatus.resolved) {
      final ok = await showConfirmDialog(
        context,
        title: '장애 해결 처리',
        message: '「${i.title}」을(를) 해결로 처리합니다.',
        confirmText: '해결',
      );
      if (!ok || !mounted) return;
    }
    setState(() => setIncidentStatus(i, status));
  }

  Widget _component(SystemComponent c) {
    final color = systemLevelColor(c.level);
    return SizedBox(
      width: 260,
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(systemLevelIcon(c.level), size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                StatusBadge(c.level.label, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '마지막 보고 ${formatDateTime(c.lastSeen, seconds: true)}',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                for (final MapEntry(:key, :value) in c.metrics.entries)
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 12),
                      children: [
                        TextSpan(
                          text: '$key  ',
                          style: const TextStyle(color: AppColors.textTertiary),
                        ),
                        TextSpan(text: value),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overall = overallLevel;
    final active = activeIncidents;
    final groups = <String, List<SystemComponent>>{};
    for (final c in mockComponents) {
      (groups[c.group] ??= []).add(c);
    }
    final incidents = _showResolved ? mockIncidents : active;
    final canHandle = can(AdminPermission.handleIncidents);
    // 끊긴 구성 요소가 드러나도록 가장 오래된 보고 시각을 보여 준다.
    final checkedAt = mockComponents.map((c) => c.lastSeen).reduce((a, b) => a.isBefore(b) ? a : b);
    final opened = _opened;

    return AdminPage(
      title: '시스템 상태',
      description: '증권사 연결, 시세, 주문 엔진, 푸시, 서버 상태와 장애 기록을 확인합니다.',
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
                      overall == SystemLevel.ok ? '모든 시스템 정상' : '전체 상태: ${overall.label}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '처리 중인 장애 ${active.length}건 · 가장 오래된 보고 ${formatDateTime(checkedAt, seconds: true)}',
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
              Text(group, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(spacing: 12, runSpacing: 12, children: [for (final c in list) _component(c)]),
            ],
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Text('장애 기록', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            FilterChip(
              label: const Text('해결된 장애 포함'),
              selected: _showResolved,
              onSelected: (v) => setState(() => _showResolved = v),
            ),
          ],
        ),
        if (opened != null)
          Panel(
            title: opened.title,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(opened.detail),
                const SizedBox(height: 8),
                Text(
                  [
                    '발생 ${formatDateTime(opened.at)}',
                    '영향 회원 ${formatNumber(opened.affectedMembers)}명',
                    if (opened.handledAt != null) '처리 ${formatDateTime(opened.handledAt!)} ${opened.handledBy}',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => setState(() => _opened = null), child: const Text('닫기')),
                ),
              ],
            ),
          ),
        AdminTable(
          columns: const ['발생 시각', '구성 요소', '수준', '내용', '영향 회원', '상태', '담당', '처리 시각', ''],
          emptyText: '처리 중인 장애가 없습니다.',
          rows: [
            for (final i in incidents)
              [
                Text(formatDateTime(i.at)),
                Text(i.component),
                StatusBadge(i.level.label, color: systemLevelColor(i.level)),
                InkWell(
                  onTap: () => setState(() => _opened = i),
                  child: SizedBox(
                    width: 240,
                    child: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
                Text('${formatNumber(i.affectedMembers)}명'),
                Text(i.status.label),
                Text(i.handledBy ?? '-'),
                Text(i.handledAt == null ? '-' : formatDateTime(i.handledAt!)),
                if (!canHandle || i.status == IncidentStatus.resolved)
                  const SizedBox.shrink()
                else if (i.status == IncidentStatus.open)
                  TextButton(onPressed: () => _change(i, IncidentStatus.acknowledged), child: const Text('확인'))
                else
                  TextButton(onPressed: () => _change(i, IncidentStatus.resolved), child: const Text('해결')),
              ],
          ],
        ),
      ],
    );
  }
}
