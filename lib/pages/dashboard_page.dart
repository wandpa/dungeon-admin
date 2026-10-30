import 'package:flutter/material.dart';

import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final newMembers = mockMembers.where((m) => m.joinedAt.day >= 29).length;
    final todaySignals = mockSignals.where((s) => s.triggeredAt.day == 30).length;

    return AdminPage(
      title: '대시보드',
      description: '오늘의 던전 현황을 한눈에 봅니다.',
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatTile(label: '전체 회원', value: formatNumber(mockMembers.length), icon: Icons.people_outline),
            _StatTile(label: '신규 가입 (어제·오늘)', value: '$newMembers', icon: Icons.person_add_alt),
            _StatTile(label: '오늘 발생 신호', value: '$todaySignals', icon: Icons.show_chart),
            _StatTile(
              label: '최근 푸시 열람률',
              value: '${(mockPushes.first.openCount / mockPushes.first.sentCount * 100).round()}%',
              icon: Icons.notifications_active_outlined,
            ),
          ],
        ),
        Panel(
          title: '최근 신호',
          child: Column(
            children: [
              for (final s in mockSignals.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: StatusBadge(
                    s.side == 'buy' ? '매수' : '매도',
                    color: s.side == 'buy' ? AppColors.up : AppColors.down,
                  ),
                  title: Text('${s.symbolName} · ${s.alertName}'),
                  subtitle: Text(
                    '${s.marketType} · ${formatNumber(s.price)}',
                    style: const TextStyle(color: AppColors.textTertiary),
                  ),
                  trailing: Text(
                    formatDateTime(s.triggeredAt),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        Panel(
          title: '최근 가입 회원',
          child: Column(
            children: [
              for (final m in mockMembers.take(4))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceSoft,
                    child: Icon(Icons.person, color: AppColors.textTertiary),
                  ),
                  title: Text(m.username),
                  subtitle: Text(maskEmail(m.email), style: const TextStyle(color: AppColors.textTertiary)),
                  trailing: Text(
                    formatDateTime(m.joinedAt),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Panel(
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
