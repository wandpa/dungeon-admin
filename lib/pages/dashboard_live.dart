part of 'dashboard_page.dart';

class _LiveData {
  const _LiveData(this.summary, this.issues, this.symbols, this.strategies);
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> issues;
  final List<Map<String, dynamic>> symbols;
  final List<Map<String, dynamic>> strategies;
}

Future<_LiveData> _loadLive() async {
  await ensureLiveMembers(); // 문제를 누르면 그 회원의 모니터링으로 간다
  final rows = await Future.wait<dynamic>([
    liveGet('/dashboard'),
    liveItems('/dashboard/issues?pageSize=100'),
    liveItems('/dashboard/jobs-by-symbol'),
    liveItems('/dashboard/jobs-by-strategy'),
  ]);
  return _LiveData(
    rows[0] as Map<String, dynamic>,
    rows[1] as List<Map<String, dynamic>>,
    rows[2] as List<Map<String, dynamic>>,
    rows[3] as List<Map<String, dynamic>>,
  );
}

List<BarRow> _bars(List<Map<String, dynamic>> rows) => [
  for (final r in rows) BarRow(r['label'] as String? ?? '-', r['value'] as int? ?? 0, r['detail'] as String? ?? ''),
];

/// 테스트 DB 대시보드. API 에 없는 값은 '-' 로 둔다.
String _grade(Object? tier) => tier is int && tier >= 1 && tier <= memberGrades.length ? memberGrades[tier - 1] : '-';

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
        Widget issues = _IssuePanel(
          live: [
            for (final r in d.issues)
              (
                id: liveIntId(r['memberId'] as String),
                username: r['username'] as String? ?? '-',
                issues: [for (final i in (r['issues'] as List).cast<Map<String, dynamic>>()) liveIssue(i)],
              ),
          ],
        );
        Widget members = AdminTable(
          columns: const ['최근 가입 회원', '이름', '등급', '이메일', '가입일'],
          emptyText: '최근 가입 회원이 없습니다.',
          rows: [
            for (final m in recent)
              [
                Text(m['username'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(m['maskedName'] as String? ?? '-'),
                Text(_grade(m['tier'])),
                Text(m['maskedEmail'] as String? ?? '-'),
                Text(formatDateTime(liveTime(m['joinedAt'])!)),
              ],
          ],
        );
        return AdminPage(
          title: '회원 현황',
          description: '회원과 매매 현황을 봅니다. 서버 상태는 시스템 탭에서 봅니다.',
          children: [
            const _DashHead('회원', Icons.people_outline),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatTile(label: '전체 회원', value: formatNumber(n('totalMembers')), icon: Icons.people_outline),
                _StatTile(label: '신규 가입 (어제·오늘)', value: '${n('newMembers')}', icon: Icons.person_add_alt),
                _StatTile(
                  label: '최근 푸시 열람률',
                  value: openRate == null ? '-' : '${openRate.round()}%',
                  icon: Icons.notifications_active_outlined,
                ),
              ],
            ),
            _DashColumns(left: issues, right: members),
            const _DashHead('매매', Icons.show_chart),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatTile(label: '오늘 발생 신호', value: '${n('todaySignals')}', icon: Icons.show_chart),
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
            _DashColumns(
              left: _BarPanel(title: '종목별 현재 잡', rows: _bars(d.symbols)),
              right: _BarPanel(title: '전략별 현재 잡', rows: _bars(d.strategies)),
            ),
          ],
        );
      },
    );
  }
}

/// 대시보드 묶음 제목.
class _DashHead extends StatelessWidget {
  const _DashHead(this.title, this.icon);

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(color: AppColors.brand, fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// 두 칸 나란히. 좁으면 위아래로 쌓는다.
class _DashColumns extends StatelessWidget {
  const _DashColumns({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 8), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 8),
            Expanded(child: right),
          ],
        );
      },
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
