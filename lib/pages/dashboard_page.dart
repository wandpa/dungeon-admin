import 'package:flutter/material.dart';

import 'live_view.dart';
import 'member_monitor_page.dart' show MonitorRequest, memberMonitorRequest;
import 'system_page.dart' show systemLevelColor, systemLevelIcon;

import '../live_api.dart';
import '../mock_accounts.dart';
import '../mock_data.dart';
import '../mock_symbols.dart';
import '../mock_system.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

part 'dashboard_live.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final newMembers = mockMembers.where((m) => m.joinedAt.day >= 29).length;
    final todaySignals = mockSignals.where((s) => s.triggeredAt.day == 30).length;

    return AdminPage(
      title: '대시보드',
      description: '오늘의 던전 현황과 회사 전체 전략·잡·주문을 한눈에 봅니다.',
      children: [
        const _SystemMonitor(),
        _StatGrid(
          spacing: 16,
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
        const _IssuePanel(),
        const _OperationSection(),
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

/// 서버·수신 상태를 늘 보여 주고, 장애가 있으면 함께 알린다.
class _SystemMonitor extends StatelessWidget {
  const _SystemMonitor();

  @override
  Widget build(BuildContext context) {
    final active = activeIncidents;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              const Text('시스템 모니터링', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              TextButton(onPressed: () => systemPageRequest.value++, child: const Text('시스템 상태 보기')),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              for (final s in systemSummaries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(systemLevelIcon(s.level), size: 18, color: systemLevelColor(s.level)),
                    const SizedBox(width: 6),
                    Text(s.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(s.level.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
            ],
          ),
          for (final alert in dstAlerts) ...[
            const SizedBox(height: 10),
            Text('$alert · 종목 마스터에서 전환하세요', style: const TextStyle(color: AppColors.warning, fontSize: 13)),
          ],
          if (active.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '장애 ${active.length}건 처리 중 · ${active.first.title}',
              style: const TextStyle(color: AppColors.warning, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// 회사 전체에서 지금 확인이 필요한 회원. 워커 문제를 맨 위로 올린다.
/// 이상 회원 목록을 문제 종류로 거른다.
enum _IssueFilter {
  all('전체', {}),
  worker('워커', {MemberIssueKind.worker, MemberIssueKind.workerStopped}),
  orders('주문', {MemberIssueKind.waitingOrders, MemberIssueKind.rejectedOrders}),
  positions('수동 포지션', {MemberIssueKind.manualPositions}),
  notification('알림', {MemberIssueKind.notification}),
  member('회원 상태', {MemberIssueKind.memberStatus});

  const _IssueFilter(this.label, this.kinds);
  final String label;
  final Set<MemberIssueKind> kinds;
}

class _IssuePanel extends StatefulWidget {
  const _IssuePanel({this.live});

  /// 테스트 DB 가 준 회원별 문제. 비어 있으면 샘플에서 모은다.
  final List<({int id, String username, List<MemberIssue> issues})>? live;

  @override
  State<_IssuePanel> createState() => _IssuePanelState();
}

class _IssuePanelState extends State<_IssuePanel> {
  static const _limit = 8;
  _IssueFilter _filter = _IssueFilter.all;
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final all = [
      ...?live,
      if (live == null)
        for (final m in pushableMembers())
          if (issuesOf(m).isNotEmpty) (id: m.id, username: m.username, issues: issuesOf(m)),
    ];
    int rank(List<MemberIssue> issues) =>
        issues.any((i) => i.kind == MemberIssueKind.worker || i.kind == MemberIssueKind.workerStopped) ? 0 : 1;
    all.sort((a, b) {
      final byKind = rank(a.issues).compareTo(rank(b.issues));
      return byKind != 0 ? byKind : b.issues.length.compareTo(a.issues.length);
    });
    int count(_IssueFilter f) =>
        f == _IssueFilter.all ? all.length : all.where((r) => r.issues.any((i) => f.kinds.contains(i.kind))).length;
    final rows = [
      for (final r in all)
        if (_filter == _IssueFilter.all)
          r
        else if (r.issues.any((i) => _filter.kinds.contains(i.kind)))
          (
            id: r.id,
            username: r.username,
            issues: [
              for (final i in r.issues)
                if (_filter.kinds.contains(i.kind)) i,
            ],
          ),
    ];
    final shown = _expanded ? rows : rows.take(_limit);
    final total = all.fold(0, (n, r) => n + r.issues.length);
    return Panel(
      title: all.isEmpty ? '확인이 필요한 회원 없음' : '확인이 필요한 회원 ${all.length}명 · 문제 $total건',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (all.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in _IssueFilter.values)
                    if (f == _IssueFilter.all || count(f) > 0)
                      ChoiceChip(
                        label: Text('${f.label} ${count(f)}', style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                ],
              ),
            ),
          if (rows.isEmpty) const Text('지금 확인할 문제가 없습니다.', style: TextStyle(color: AppColors.textTertiary)),
          for (final r in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () => memberMonitorRequest.value = MonitorRequest(r.id),
                      child: Text(r.username, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // 문제는 상태 점 + 글자로 보이고, 누르면 그 문제를 모니터링에서 연다.
                        for (final i in r.issues)
                          InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.tag),
                            onTap: () => memberMonitorRequest.value = MonitorRequest(r.id, issue: i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              child: StatusBadge(i.label, color: AppColors.warning),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (rows.length > _limit)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? '접기' : '외 ${rows.length - _limit}명 더 보기'),
              ),
            ),
        ],
      ),
    );
  }
}

enum _Period {
  today('오늘'),
  week('7일'),
  all('전체');

  const _Period(this.label);
  final String label;

  /// 샘플 데이터의 마지막 날을 오늘로 본다. API 를 붙이면 실제 날짜로 바꾼다.
  DateTime? get since => switch (this) {
    _Period.today => DateTime(2026, 10, 30),
    _Period.week => DateTime(2026, 10, 24),
    _Period.all => null,
  };
}

/// 회사 전체 운영 현황: 전략·잡·포지션 지표와 주문 금액, 종목별·전략별 잡 수.
class _OperationSection extends StatefulWidget {
  const _OperationSection();

  @override
  State<_OperationSection> createState() => _OperationSectionState();
}

class _OperationSectionState extends State<_OperationSection> {
  _Period _period = _Period.today;

  @override
  Widget build(BuildContext context) {
    final s = companyStats();
    final totals = orderTotals(since: _period.since);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatGrid(
          spacing: 16,
          children: [
            _StatTile(
              label: '전체 전략',
              value: formatNumber(s.strategyCount),
              icon: Icons.account_tree_outlined,
              sub: '회원별 전략 합계',
            ),
            _StatTile(
              label: '현재 잡',
              value: formatNumber(s.currentJobs),
              icon: Icons.task_alt,
              sub: '종료 ${s.finishedJobs}개',
            ),
            _StatTile(
              label: '실행 중 워커',
              value: formatNumber(s.runningWorkers),
              icon: Icons.smart_toy_outlined,
              sub: '전체 ${s.workers}개 · 오류 ${s.errorWorkers}개',
            ),
            _StatTile(
              label: '보유 포지션',
              value: formatNumber(s.positions),
              icon: Icons.account_balance_wallet_outlined,
              sub: '수동 ${s.manualPositions}건 포함',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('회원 전체 주문 금액', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      SizedBox(height: 2),
                      Text(
                        '실전 계좌 체결 기준 · 체결가 × 수량 × 계약승수 · 모의 계좌 제외',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final p in _Period.values)
                        ChoiceChip(
                          label: Text(p.label, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          selected: p == _period,
                          onSelected: (_) => setState(() => _period = p),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (totals.isEmpty)
                const Text('이 기간의 주문이 없습니다.', style: TextStyle(color: AppColors.textTertiary))
              else
                _CurrencyTotals(totals),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final symbols = _BarPanel(title: '종목별 현재 잡', rows: s.jobsBySymbol);
            final strategies = _BarPanel(title: '전략별 현재 잡', rows: s.jobsByStrategy);
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [symbols, const SizedBox(height: 16), strategies],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: symbols),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: strategies),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// 통화 하나의 주문 합계. 통화가 다르면 더할 수 없어 따로 보여 준다.
class _CurrencyTotal extends StatelessWidget {
  const _CurrencyTotal(this.total);

  final OrderTotal total;

  @override
  Widget build(BuildContext context) {
    final t = total;
    const meta = TextStyle(color: AppColors.textTertiary, fontSize: 12);
    Widget legend(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [StatusDot(color, size: 6), const SizedBox(width: 6), Text(text, style: meta)],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${t.currency} 체결 금액', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: _amount(t.filledAmount)),
              if (t.currency != '통화 미확인')
                TextSpan(
                  text: '  ${t.currency}',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 15, fontWeight: FontWeight.w400),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 36, height: 1, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        _ShareBar([(t.buyAmount, AppColors.up), (t.sellAmount, AppColors.down)]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            legend(AppColors.up, '매수 ${_amount(t.buyAmount)}'),
            legend(AppColors.down, '매도 ${_amount(t.sellAmount)}'),
          ],
        ),
        const SizedBox(height: 16),
        _ShareBar([
          (t.filled.toDouble(), AppColors.textPrimary),
          (t.waiting.toDouble(), AppColors.warning),
          (t.rejected.toDouble(), AppColors.danger.withValues(alpha: 0.45)),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            Text('주문 ${formatNumber(t.orders)}건', style: meta.copyWith(color: AppColors.textSecondary)),
            legend(AppColors.textPrimary, '체결 ${formatNumber(t.filled)}'),
            legend(AppColors.warning, '미체결 ${formatNumber(t.waiting)}'),
            legend(AppColors.danger.withValues(alpha: 0.45), '거부 ${formatNumber(t.rejected)}'),
          ],
        ),
      ],
    );
  }
}

String _amount(double v) => formatNumber(v.round());

/// 통화가 여럿이면 금액이 큰 통화를 왼쪽에 크게 두고 나머지는 옆에 같은 모양으로 둔다.
class _CurrencyTotals extends StatelessWidget {
  const _CurrencyTotals(this.totals);

  final List<OrderTotal> totals;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final perRow = c.maxWidth >= 900 ? 2 : 1;
      final width = (c.maxWidth - 32 * (perRow - 1)) / perRow;
      return Wrap(
        spacing: 32,
        runSpacing: 24,
        children: [for (final t in totals) SizedBox(width: width, child: _CurrencyTotal(t))],
      );
    },
  );
}

/// 비율 막대 한 줄. 각 칸 색은 뜻이 있다(매수 빨강·매도 파랑, 체결·미체결·거부).
class _ShareBar extends StatelessWidget {
  const _ShareBar(this.parts);

  final List<(double value, Color color)> parts;

  @override
  Widget build(BuildContext context) {
    final sum = parts.fold(0.0, (s, p) => s + p.$1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: sum <= 0
            ? Container(color: AppColors.strip)
            : Row(
                children: [
                  for (final (i, p) in parts.indexed)
                    if (p.$1 > 0) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(flex: (p.$1 / sum * 1000).round().clamp(1, 1000), child: Container(color: p.$2)),
                    ],
                ],
              ),
      ),
    );
  }
}

/// 많은 순서의 가로 막대. 값은 막대 옆에 쓰고, 마우스를 올리면 자세한 내용을 보여 준다.
class _BarPanel extends StatelessWidget {
  const _BarPanel({required this.title, required this.rows});

  final String title;
  final List<BarRow> rows;

  @override
  Widget build(BuildContext context) {
    final maxValue = rows.fold(0, (m, r) => r.value > m ? r.value : m);
    return Panel(
      title: title,
      child: rows.isEmpty
          ? const Text('현재 잡이 없습니다.', style: TextStyle(color: AppColors.textTertiary))
          : Column(
              children: [
                for (final r in rows)
                  Tooltip(
                    message: r.detail,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 170,
                            child: Text(
                              r.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: r.value / maxValue,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: identical(r, rows.first) ? AppColors.brand : AppColors.control,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${r.value}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 통계 칸을 화면 너비에 맞춰 같은 너비의 칸으로 나눈다. 한 줄에 최대 5칸이고,
/// 칸 수가 적은 줄도 같은 격자에 맞춰 위아래 칸이 줄을 맞춘다.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.spacing, required this.children, this.fill = false});

  final double spacing;
  final List<Widget> children;
  final bool fill; // 칸이 적으면 줄을 칸 수로 나눠 오른쪽을 비워 두지 않는다

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final most = ((c.maxWidth + spacing) / (200 + spacing)).floor().clamp(1, 5);
      final cols = fill ? children.length.clamp(1, most) : most;
      final width = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final w in children) SizedBox(width: width, child: w)],
      );
    },
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon, this.sub});

  final String label;
  final String value;
  final IconData icon;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    // 숫자 칸은 이름, 큰 숫자, 비교 문구만 둔다. 아이콘은 꾸밈이라 그리지 않는다.
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 28, height: 1, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          // 보조 문구가 없어도 줄을 비워 두어 옆 칸과 높이를 맞춘다.
          Text(sub ?? '', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}
