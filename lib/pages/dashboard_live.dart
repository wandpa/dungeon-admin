part of 'dashboard_page.dart';

class _LiveData {
  const _LiveData(this.summary, this.issues, this.symbols, this.strategies, this.system);
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> issues;
  final List<Map<String, dynamic>> symbols;
  final List<Map<String, dynamic>> strategies;
  final Map<String, dynamic> system;
}

Future<_LiveData> _loadLive() async {
  await ensureLiveMembers(); // 문제를 누르면 그 회원의 모니터링으로 간다
  final rows = await Future.wait<dynamic>([
    liveGet('/dashboard'),
    liveItems('/dashboard/issues?pageSize=100'),
    liveItems('/dashboard/jobs-by-symbol'),
    liveItems('/dashboard/jobs-by-strategy'),
    liveGet('/system/status'),
  ]);
  return _LiveData(
    rows[0] as Map<String, dynamic>,
    rows[1] as List<Map<String, dynamic>>,
    rows[2] as List<Map<String, dynamic>>,
    rows[3] as List<Map<String, dynamic>>,
    rows[4] as Map<String, dynamic>,
  );
}

List<BarRow> _bars(List<Map<String, dynamic>> rows) => [
  for (final r in rows) BarRow(r['label'] as String? ?? '-', r['value'] as int? ?? 0, r['detail'] as String? ?? ''),
];

/// 테스트 DB 대시보드. API 에 없는 값은 '-' 로 둔다.
class LiveDashboardPage extends StatelessWidget {
  const LiveDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LiveLoader<_LiveData>(
      load: _loadLive,
      builder: (context, d) {
        final s = d.summary;
        int n(String key) => s[key] as int? ?? 0;
        final openRate = s['latestPushOpenRate'] as num?;
        final recent = (s['recentMembers'] as List? ?? const []).cast<Map<String, dynamic>>();
        return AdminPage(
          title: '대시보드',
          description: '오늘의 던전 현황과 회사 전체 전략·잡·주문을 한눈에 봅니다.',
          children: [
            _LiveSystemMonitor(d.system),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatTile(label: '전체 회원', value: formatNumber(n('totalMembers')), icon: Icons.people_outline),
                _StatTile(label: '신규 가입 (어제·오늘)', value: '${n('newMembers')}', icon: Icons.person_add_alt),
                _StatTile(label: '오늘 발생 신호', value: '${n('todaySignals')}', icon: Icons.show_chart),
                _StatTile(
                  label: '최근 푸시 열람률',
                  value: openRate == null ? '-' : '${openRate.round()}%',
                  icon: Icons.notifications_active_outlined,
                ),
              ],
            ),
            _IssuePanel(
              live: [
                for (final r in d.issues)
                  (
                    id: liveIntId(r['memberId'] as String),
                    username: r['username'] as String? ?? '-',
                    issues: [for (final i in (r['issues'] as List).cast<Map<String, dynamic>>()) liveIssue(i)],
                  ),
              ],
            ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatTile(
                  label: '전체 전략',
                  value: formatNumber(n('strategyCount')),
                  icon: Icons.account_tree_outlined,
                  sub: '회원별 전략 합계',
                ),
                _StatTile(
                  label: '현재 잡',
                  value: formatNumber(n('currentJobs')),
                  icon: Icons.task_alt,
                  sub: '종료 ${n('finishedJobs')}개',
                ),
                _StatTile(
                  label: '실행 중 워커',
                  value: formatNumber(n('runningWorkers')),
                  icon: Icons.smart_toy_outlined,
                  sub: '전체 ${n('workers')}개',
                ),
                _StatTile(
                  label: '보유 포지션',
                  value: formatNumber(n('positions')),
                  icon: Icons.account_balance_wallet_outlined,
                  sub: '모의 ${n('paperPositions')}건 별도 · 수동 ${n('manualPositions')}건',
                ),
              ],
            ),
            const _LiveOrderTotals(),
            LayoutBuilder(
              builder: (context, constraints) {
                final symbols = _BarPanel(title: '종목별 현재 잡', rows: _bars(d.symbols));
                final strategies = _BarPanel(title: '전략별 현재 잡', rows: _bars(d.strategies));
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
            Panel(
              title: '최근 가입 회원',
              child: Column(
                children: [
                  for (final m in recent)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.surfaceSoft,
                        child: Icon(Icons.person, color: AppColors.textTertiary),
                      ),
                      title: Text(m['username'] as String? ?? '-'),
                      subtitle: Text(
                        m['maskedEmail'] as String? ?? '-',
                        style: const TextStyle(color: AppColors.textTertiary),
                      ),
                      trailing: Text(
                        formatDateTime(liveTime(m['joinedAt'])!),
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LiveSystemMonitor extends StatelessWidget {
  const _LiveSystemMonitor(this.status);

  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context) {
    final components = (status['components'] as List? ?? const []).cast<Map<String, dynamic>>();
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
              const Text('시스템 모니터링 (임시 기준)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              TextButton(onPressed: () => systemPageRequest.value++, child: const Text('시스템 상태 보기')),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              for (final c in components)
                Builder(
                  builder: (context) {
                    final level = liveLevel(c['level']);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(systemLevelIcon(level), size: 18, color: systemLevelColor(level)),
                        const SizedBox(width: 6),
                        Text(
                          c['name'] as String? ?? '-',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(level.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveOrderTotals extends StatefulWidget {
  const _LiveOrderTotals();

  @override
  State<_LiveOrderTotals> createState() => _LiveOrderTotalsState();
}

class _LiveOrderTotalsState extends State<_LiveOrderTotals> {
  _Period _period = _Period.today;

  Future<List<OrderTotal>> _load(_Period p) async {
    final rows = await liveItems('/dashboard/order-totals?period=${p.name}');
    return [
      for (final r in rows)
        OrderTotal(r['currency'] as String? ?? '통화 미확인')
          ..orders = r['orders'] as int? ?? 0
          ..filled = r['filled'] as int? ?? 0
          ..waiting = r['waiting'] as int? ?? 0
          ..rejected = r['rejected'] as int? ?? 0
          ..buyAmount = liveDouble(r['buyAmount']) ?? 0
          ..sellAmount = liveDouble(r['sellAmount']) ?? 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
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
                  Text('회원 전체 주문 금액', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
          LiveLoader<List<OrderTotal>>(
            key: ValueKey(_period),
            load: () => _load(_period),
            builder: (context, totals) => totals.isEmpty
                ? const Text('이 기간의 주문이 없습니다.', style: TextStyle(color: AppColors.textTertiary))
                : Wrap(spacing: 32, runSpacing: 16, children: [for (final t in totals) _CurrencyTotal(t)]),
          ),
        ],
      ),
    );
  }
}
