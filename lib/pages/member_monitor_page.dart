import 'dart:math';

import 'package:flutter/material.dart';

import '../mock_accounts.dart';
import '../mock_admin.dart';
import '../mock_consultations.dart';
import '../mock_data.dart';
import '../mock_workers.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'consultations_page.dart' show consultStatusColor;
import 'members_page.dart' show memberStatusColor;

part 'member_monitor_accounts.dart';

const _minWideHeight = 1180.0;

/// 다른 화면에서 이 회원을 모니터링으로 열어 달라는 요청. [issue] 를 주면 그 문제 위치로 간다.
class MonitorRequest {
  const MonitorRequest(this.memberId, {this.issue});
  final int memberId;
  final MemberIssue? issue;
}

final memberMonitorRequest = ValueNotifier<MonitorRequest?>(null);

/// 샘플 데이터의 마지막 날을 오늘로 본다. API 를 붙이면 실제 날짜로 바꾼다.
final _mockToday = DateTime(2026, 10, 30);

enum _LogPeriod {
  all('전체 기간'),
  today('오늘'),
  yesterday('어제'),
  week('최근 7일'),
  custom('날짜 선택');

  const _LogPeriod(this.label);
  final String label;
}

/// 상담용 화면. 회원을 고르면 그 사용자가 앱에서 보는 워커·잡·이력과 고객 로그를 함께 본다.
class MemberMonitorPage extends StatefulWidget {
  const MemberMonitorPage({super.key});

  @override
  State<MemberMonitorPage> createState() => _MemberMonitorPageState();
}

class _MemberMonitorPageState extends State<MemberMonitorPage> {
  String _query = '';
  int? _memberId;
  int? _workerId; // null 이면 전체 워커: 고객 로그도 전체가 나온다
  WorkerJob? _job; // 아래 잡 상세 패널에 보여 줄 잡
  _MonitorTab _tab = _MonitorTab.workers;
  String? _accountName; // null 이면 전체 계좌. 모든 탭에 함께 적용한다.
  _OrderFilter _orderFilter = _OrderFilter.all;
  String _logQuery = '';
  _LogPeriod _logPeriod = _LogPeriod.all;
  DateTimeRange? _logRange; // 날짜 선택 기간
  int? _viewedMemberId; // 열람 기록을 남긴 회원
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final request = memberMonitorRequest.value;
    memberMonitorRequest.value = null;
    if (request == null) return;
    _memberId = request.memberId;
    if (request.issue != null) _applyIssue(request.issue!);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 화면이 낮아 상세 패널이 아래로 밀려 있으면 보이도록 내려 준다.
  void _selectJob(WorkerJob job) {
    setState(() => _job = job);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || _scroll.position.maxScrollExtent <= 0) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  CustomerLogCategory? _logCategory; // null 이면 전체

  /// 승인 전 회원은 로그인할 수 없어 볼 내용이 없다.
  List<Member> get _members => [
    for (final m in mockMembers)
      if (m.status != MemberStatus.pending) m,
  ];

  List<Member> get _filteredMembers {
    final q = _query.trim().toLowerCase();
    return [
      for (final m in _members)
        if (q.isEmpty || m.username.toLowerCase().contains(q) || m.email.toLowerCase().contains(q)) m,
    ];
  }

  /// 고른 회원이 없으면 워커가 있는 첫 회원을 보여 준다.
  Member? get _member {
    final members = _members;
    for (final m in members) {
      if (m.id == _memberId) return m;
    }
    for (final m in members) {
      if (workersOf(m.id).isNotEmpty) return m;
    }
    return members.firstOrNull;
  }

  MemberWorker? _workerIn(List<MemberWorker> workers) {
    for (final w in workers) {
      if (w.id == _workerId) return w;
    }
    return null;
  }

  void _selectAccount(String? name) => setState(() {
    _accountName = name;
    _job = null;
    _orderFilter = _OrderFilter.all;
  });

  /// 문제를 누르면 그 내용을 보는 곳으로 간다. 문제는 전체 계좌 기준이라 계좌 선택을 푼다.
  void _openIssue(MemberIssue issue) => setState(() => _applyIssue(issue));

  void _applyIssue(MemberIssue issue) {
    _accountName = null;
    _job = null;
    _orderFilter = _OrderFilter.all;
    switch (issue.kind) {
      case MemberIssueKind.worker:
        _tab = _MonitorTab.workers;
        _workerId = issue.workerId;
      case MemberIssueKind.waitingOrders:
        _tab = _MonitorTab.accounts;
        _orderFilter = _OrderFilter.waiting;
      case MemberIssueKind.rejectedOrders:
        _tab = _MonitorTab.accounts;
        _orderFilter = _OrderFilter.rejected;
      case MemberIssueKind.manualPositions:
        _tab = _MonitorTab.accounts;
      case MemberIssueKind.notification:
        _tab = _MonitorTab.notifications;
      case MemberIssueKind.memberStatus:
        break;
    }
  }

  /// 로그·주문·포지션에서 그 워커나 잡으로 이동한다.
  void _openWorker(int? workerId, String? jobName) {
    final member = _member;
    if (workerId == null || member == null) return;
    final worker = workersOf(member.id).where((w) => w.id == workerId).firstOrNull;
    if (worker == null) return;
    final job = worker.jobs.where((j) => j.name == jobName).firstOrNull;
    setState(() {
      _tab = _MonitorTab.workers;
      _accountName = null;
      _workerId = workerId;
      _job = null;
    });
    if (job != null) _selectJob(job);
  }

  Future<void> _selectLogPeriod(_LogPeriod period) async {
    if (period != _LogPeriod.custom) {
      setState(() {
        _logPeriod = period;
        _logRange = null;
      });
      return;
    }
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2027, 12, 31),
      initialDateRange: _logRange,
    );
    if (range == null || !mounted) return;
    setState(() {
      _logPeriod = period;
      _logRange = range;
    });
  }

  bool _logInPeriod(DateTime at) {
    final start = switch (_logPeriod) {
      _LogPeriod.all => null,
      _LogPeriod.today => _mockToday,
      _LogPeriod.yesterday => _mockToday.subtract(const Duration(days: 1)),
      _LogPeriod.week => _mockToday.subtract(const Duration(days: 6)),
      _LogPeriod.custom => _logRange?.start,
    };
    final end = switch (_logPeriod) {
      _LogPeriod.yesterday => _mockToday,
      _LogPeriod.custom => _logRange?.end.add(const Duration(days: 1)),
      _ => null,
    };
    return (start == null || !at.isBefore(start)) && (end == null || at.isBefore(end));
  }

  String get _logPeriodLabel {
    final r = _logRange;
    if (_logPeriod != _LogPeriod.custom || r == null) return _logPeriod.label;
    String day(DateTime d) => formatDateTime(d).split(' ').first;
    return '${day(r.start)} ~ ${day(r.end)}';
  }

  void _selectMember(Member m) => setState(() {
    _memberId = m.id;
    _workerId = null;
    _job = null;
    _logCategory = null;
    _accountName = null;
    _orderFilter = _OrderFilter.all;
    _logQuery = '';
    _logPeriod = _LogPeriod.all;
    _logRange = null;
  });

  @override
  Widget build(BuildContext context) {
    final member = _member;
    if (member != null && member.id != _viewedMemberId) {
      _viewedMemberId = member.id;
      logActivity(ActivityKind.view, '${member.username} 회원 모니터링 열람');
    }
    final allWorkers = member == null ? const <MemberWorker>[] : workersOf(member.id);
    final accountName = _accountName;
    final workers = accountName == null
        ? allWorkers
        : [
            for (final w in allWorkers)
              if (w.usesAccount(accountName)) w.onlyAccount(accountName),
          ];
    final worker = _workerIn(workers);
    final memberLogs = member == null
        ? const <CustomerLog>[]
        : customerLogsOf(member.id, workerId: worker?.id, jobName: _job?.name);
    // 계좌를 고르면 그 계좌의 워커·잡 로그만 남긴다. 로그인처럼 계좌와 무관한 로그는 전체 계좌에서만 본다.
    bool onAccount(CustomerLog l) =>
        workers.any((w) => w.id == l.workerId && (l.jobName == null || w.jobs.any((j) => j.name == l.jobName)));
    final query = _logQuery.trim().toLowerCase();
    final logs = [
      for (final l in memberLogs)
        if ((accountName == null || onAccount(l)) &&
            _logInPeriod(l.at) &&
            (query.isEmpty || l.text.toLowerCase().contains(query)))
          l,
    ];

    final memberPane = _MemberPane(
      members: _filteredMembers,
      selected: member,
      onSearchChanged: (v) => setState(() => _query = v),
      onSelect: _selectMember,
    );
    final workerPane = _WorkersPane(
      member: member,
      workers: workers,
      selected: worker,
      onSelect: (w) => setState(() {
        _workerId = w.id;
        _job = null;
      }),
      onSelectAll: () => setState(() {
        _workerId = null;
        _job = null;
      }),
    );
    // 워커 설정과 누적 손익은 계좌가 아니라 워커 전체 기준이라 필터 전 값을 보여 준다.
    final settingsPane = _WorkerSettingsPane(worker: _workerIn(allWorkers));
    final jobsPane = _JobsPane(
      key: ValueKey(worker?.id),
      worker: worker,
      selected: _job,
      onSelect: _selectJob,
      onTabChanged: () => setState(() => _job = null),
    );
    final detailPane = _JobDetailPane(job: _job, worker: worker);
    final logPane = _CustomerLogPane(
      title: '고객 로그 · ${_job?.name ?? worker?.symbolName ?? '전체'}',
      logs: logs,
      searchKey: ValueKey(member?.id),
      periodLabel: _logPeriodLabel,
      onSearchChanged: (v) => setState(() => _logQuery = v),
      onPeriodSelected: _selectLogPeriod,
      onOpen: (l) => _openWorker(l.workerId, l.jobName),
      category: _logCategory,
      onCategoryChanged: (c) => setState(() => _logCategory = c),
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = SizedBox(width: 12, height: 12);
          const header = _Header();

          final narrow = constraints.maxWidth < 1000;
          final bar = _MemberBar(
            member: member,
            tab: _tab,
            onTabChanged: (t) {
              if (t == _MonitorTab.accounts && t != _tab && member != null) {
                logActivity(ActivityKind.view, '${member.username} 계좌·주문 열람');
              }
              setState(() => _tab = t);
            },
          );

          // 계좌·알림 탭의 패널
          final accounts = member == null ? const <MemberAccount>[] : accountsOf(member.id);
          final selectedAccounts = [
            for (final a in accounts)
              if (_accountName == null || a.name == _accountName) a,
          ];
          final positions = member == null
              ? const <AccountPosition>[]
              : positionsOf(member.id, accountName: _accountName);
          final orders = member == null ? const <AccountOrder>[] : ordersOf(member.id, accountName: _accountName);
          final accountsPane = _AccountsPane(accounts: accounts, selected: _accountName, onSelect: _selectAccount);
          final summaryPane = _AccountSummaryPane(
            memberId: member?.id,
            accountName: _accountName,
            accounts: selectedAccounts,
            positions: positions,
            orders: orders,
          );
          final positionsPane = _PositionsPane(positions: positions, onOpen: (p) => _openWorker(p.workerId, p.jobName));
          final ordersPane = _OrdersPane(
            orders: orders,
            filter: _orderFilter,
            onFilterChanged: (f) => setState(() => _orderFilter = f),
            onOpen: (o) => _openWorker(o.workerId, o.jobName),
          );
          final issueBar = member == null ? null : _IssueBar(issues: issuesOf(member), onOpen: _openIssue);
          final memoPane = member == null
              ? const _Pane(title: '상담 이력', child: _Empty('회원을 선택하세요.'))
              : _ConsultPane(
                  key: ValueKey(member.id),
                  member: member,
                  worker: worker,
                  job: _job,
                  onOpen: (c) => _openWorker(c.workerId, c.jobName),
                );
          final notifySettingsPane = member == null
              ? const _Pane(title: '알림 설정', child: _Empty('회원을 선택하세요.'))
              : _NotificationSettingsPane(state: notificationStateOf(member));
          final notifyHistoryPane = _NotificationHistoryPane(
            messages: member == null ? const [] : notificationsOf(member.id, accountName: _accountName),
          );

          // 계좌·주문 탭은 왼쪽 계좌 목록으로 고르므로 이 줄을 띄우지 않는다.
          final accountBar = _tab != _MonitorTab.accounts && accounts.length > 1
              ? _AccountFilterBar(accounts: accounts, selected: _accountName, onSelect: _selectAccount)
              : null;

          // 좁으면 패널마다 높이를 정해 세로로 쌓는다.
          if (narrow) {
            return ListView(
              controller: _scroll,
              children: [
                header,
                gap,
                SizedBox(height: 300, child: memberPane),
                gap,
                SizedBox(height: 360, child: memoPane),
                gap,
                bar,
                gap,
                ?issueBar,
                gap,
                if (accountBar != null) ...[accountBar, gap],
                ...switch (_tab) {
                  _MonitorTab.workers => [
                    SizedBox(height: 340, child: workerPane),
                    gap,
                    SizedBox(height: 320, child: settingsPane),
                    gap,
                    SizedBox(height: 360, child: jobsPane),
                    gap,
                    SizedBox(height: 420, child: logPane),
                    gap,
                    SizedBox(height: 640, child: detailPane),
                  ],
                  _MonitorTab.accounts => [
                    SizedBox(height: 320, child: accountsPane),
                    gap,
                    SizedBox(height: 280, child: summaryPane),
                    gap,
                    SizedBox(height: 320, child: positionsPane),
                    gap,
                    SizedBox(height: 420, child: ordersPane),
                  ],
                  _MonitorTab.notifications => [
                    SizedBox(height: 420, child: notifySettingsPane),
                    gap,
                    SizedBox(height: 420, child: notifyHistoryPane),
                  ],
                },
              ],
            );
          }

          final body = switch (_tab) {
            _MonitorTab.workers => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: workerPane),
                      gap,
                      Expanded(flex: 2, child: settingsPane),
                    ],
                  ),
                ),
                gap,
                Expanded(
                  flex: 3,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: jobsPane),
                      gap,
                      Expanded(flex: 2, child: logPane),
                    ],
                  ),
                ),
                gap,
                Expanded(flex: 4, child: detailPane),
              ],
            ),
            _MonitorTab.accounts => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 270, child: accountsPane),
                gap,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 240, child: summaryPane),
                      gap,
                      Expanded(flex: 2, child: positionsPane),
                      gap,
                      Expanded(flex: 3, child: ordersPane),
                    ],
                  ),
                ),
              ],
            ),
            _MonitorTab.notifications => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 320, child: notifySettingsPane),
                gap,
                Expanded(child: notifyHistoryPane),
              ],
            ),
          };

          // 워커 탭은 패널이 세 줄이라 최소 높이를 두고 페이지를 스크롤한다.
          final height = _tab == _MonitorTab.workers
              ? max(constraints.maxHeight, _minWideHeight)
              : constraints.maxHeight;
          return SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 220,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 1, child: memberPane),
                              gap,
                              Expanded(flex: 1, child: memoPane),
                            ],
                          ),
                        ),
                        gap,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              bar,
                              const SizedBox(height: 8),
                              if (issueBar != null) ...[issueBar, const SizedBox(height: 8)],
                              if (accountBar != null) ...[accountBar, const SizedBox(height: 8)],
                              Expanded(child: body),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('회원 모니터링', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        SizedBox(height: 4),
        Text(
          '회원을 선택하면 사용자가 앱에서 보는 워커·잡, 계좌·주문, 알림을 탭으로 보고, 계좌를 고르면 그 계좌 기준으로 바뀝니다.',
          style: TextStyle(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

/// 제목과 안쪽 스크롤 영역이 있는 패널. 높이가 정해진 자리에 넣는다.
class _Pane extends StatelessWidget {
  const _Pane({required this.title, required this.child, this.trailing, this.onTitleTap, this.titleActive = false});

  final String title;
  final Widget? trailing;
  final Widget child;

  /// 주면 제목이 탭처럼 눌린다. [titleActive] 면 선택된 탭으로 칠한다.
  final VoidCallback? onTitleTap;
  final bool titleActive;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700));
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                if (onTitleTap == null)
                  titleText
                else
                  Material(
                    color: titleActive ? AppColors.brand.withValues(alpha: 0.28) : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onTitleTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: titleText,
                      ),
                    ),
                  ),
                ?trailing,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

class _MemberPane extends StatelessWidget {
  const _MemberPane({
    required this.members,
    required this.selected,
    required this.onSearchChanged,
    required this.onSelect,
  });

  final List<Member> members;
  final Member? selected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Member> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Pane(
      title: '회원',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 20), hintText: '아이디·이메일 검색'),
            ),
          ),
          Expanded(
            child: members.isEmpty
                ? const _Empty('조건에 맞는 회원이 없습니다.')
                : ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, i) {
                      final m = members[i];
                      final workers = workersOf(m.id);
                      final running = workers.where((w) => w.status == WorkerStatus.running).length;
                      final issues = issuesOf(m).length;
                      return ListTile(
                        dense: true,
                        selected: m.id == selected?.id,
                        selectedTileColor: AppColors.brand.withValues(alpha: 0.18),
                        selectedColor: AppColors.textPrimary,
                        title: Text(
                          m.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text.rich(
                          TextSpan(
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                            children: [
                              TextSpan(text: workers.isEmpty ? '워커 없음' : '워커 ${workers.length}개 · 실행 $running'),
                              if (issues > 0)
                                TextSpan(
                                  text: ' · 문제 $issues',
                                  style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700),
                                ),
                            ],
                          ),
                        ),
                        trailing: m.status == MemberStatus.active
                            ? null
                            : StatusBadge(m.status.label, color: memberStatusColor(m.status)),
                        onTap: () => onSelect(m),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

Color _workerStatusColor(WorkerStatus s) => switch (s) {
  WorkerStatus.running => AppColors.success,
  WorkerStatus.stopped => AppColors.textTertiary,
  WorkerStatus.error => AppColors.up,
};

/// 소수 둘째 자리까지 쓰고, 정수면 소수점을 뺀다. 예: 2.0 → 2, 1250.5 → 1,250.5
String _num(double v) {
  final r = (v * 100).round() / 100;
  return formatNumber(r == r.truncateToDouble() ? r.toInt() : r);
}

String _signedMoney(double v, String currency) => '${v > 0 ? '+' : ''}${_num(v)} $currency';

/// 이익은 빨강, 손실은 파랑.
class _PnlValue extends StatelessWidget {
  const _PnlValue(this.value, this.currency);

  final double value;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final color = value > 0
        ? AppColors.up
        : value < 0
        ? AppColors.down
        : AppColors.textSecondary;
    return Text(
      _signedMoney(value, currency),
      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
    );
  }
}

class _Pnl extends StatelessWidget {
  const _Pnl(this.label, this.value, this.currency);

  final String label;
  final double value;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label  ', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        _PnlValue(value, currency),
      ],
    );
  }
}

/// 워커 목록. 한 줄씩 표처럼 보여 주고, 누르면 아래 패널이 그 워커로 바뀐다.
class _WorkersPane extends StatelessWidget {
  const _WorkersPane({
    required this.member,
    required this.workers,
    required this.selected,
    required this.onSelect,
    required this.onSelectAll,
  });

  final Member? member;
  final List<MemberWorker> workers;
  final MemberWorker? selected;
  final ValueChanged<MemberWorker> onSelect;
  final VoidCallback onSelectAll;

  /// 실전과 모의는 합치지 않는다. 값은 실현+평가 손익이고, 통화가 다르면 통화별로 보여 준다.
  String _totals({required bool paper}) {
    final sums = <String, double>{};
    for (final w in workers) {
      for (final j in w.jobs.where((j) => j.isPaper == paper)) {
        final pnl = j.realizedPnl + (j.position?.pnlAt(w.currentPrice) ?? 0);
        sums.update(w.currency, (v) => v + pnl, ifAbsent: () => pnl);
      }
    }
    return sums.entries.map((e) => _signedMoney(e.value, e.key)).join(' · ');
  }

  Widget _row({
    required Widget name,
    required Widget status,
    required Widget realized,
    required Widget unrealized,
    required Widget jobs,
  }) {
    return Row(
      children: [
        Expanded(child: name),
        SizedBox(width: 64, child: status),
        SizedBox(
          width: 104,
          child: Align(alignment: Alignment.centerRight, child: realized),
        ),
        SizedBox(
          width: 104,
          child: Align(alignment: Alignment.centerRight, child: unrealized),
        ),
        SizedBox(
          width: 36,
          child: Align(alignment: Alignment.centerRight, child: jobs),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = workers.where((w) => w.status == WorkerStatus.running).length;
    const head = TextStyle(color: AppColors.textTertiary, fontSize: 12);
    final real = _totals(paper: false);
    final paper = _totals(paper: true);
    // 오류 워커를 맨 위로 올린다.
    final sorted = [
      ...workers.where((w) => w.status == WorkerStatus.error),
      ...workers.where((w) => w.status != WorkerStatus.error),
    ];
    return _Pane(
      title: member == null ? '워커' : '${member!.username} 워커',
      onTitleTap: onSelectAll,
      titleActive: selected == null,
      trailing: workers.isEmpty
          ? null
          : Text(
              '실행 $running / ${workers.length} · 실현+평가 실전 ${real.isEmpty ? '-' : real}${paper.isEmpty ? '' : ' · 모의 $paper'}',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
      child: workers.isEmpty
          ? const _Empty('등록한 워커가 없습니다.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _row(
                    name: const Text('종목', style: head),
                    status: const Text('상태', style: head),
                    realized: const Text('실현 손익', style: head),
                    unrealized: const Text('평가 손익', style: head),
                    jobs: const Text('잡', style: head),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, i) {
                      final w = sorted[i];
                      final allPaper = w.jobs.isNotEmpty && w.jobs.every((j) => j.isPaper);
                      return Material(
                        color: w.id == selected?.id ? AppColors.brand.withValues(alpha: 0.18) : Colors.transparent,
                        child: InkWell(
                          onTap: () => onSelect(w),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: _row(
                              name: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${w.symbolName} (${w.symbolCode})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (allPaper) ...[
                                    const SizedBox(width: 6),
                                    const StatusBadge('모의', color: AppColors.down),
                                  ],
                                ],
                              ),
                              status: Align(
                                alignment: Alignment.centerLeft,
                                child: StatusBadge(w.status.label, color: _workerStatusColor(w.status)),
                              ),
                              realized: _PnlValue(w.realizedPnl, w.currency),
                              unrealized: _PnlValue(w.unrealizedPnl, w.currency),
                              jobs: Text(
                                '${w.jobs.where((j) => !j.isFinished).length}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// 선택한 워커 자체의 정보와 설정. 잡은 여기 넣지 않는다.
class _WorkerSettingsPane extends StatelessWidget {
  const _WorkerSettingsPane({required this.worker});

  final MemberWorker? worker;

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final limit = w?.pnlLimit;
    return _Pane(
      title: w == null ? '워커 설정' : '${w.symbolName} 워커 설정',
      child: w == null
          ? const _Empty('워커를 선택하세요.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                _Facts({'시장': w.marketType, '현재가': _num(w.currentPrice), '등록일': formatDateTime(w.insertedAt)}),
                if (w.errorMessage != null) ...[const SizedBox(height: 8), _Notice(w.errorMessage!)],
                if (limit?.stoppedAt != null) ...[
                  const SizedBox(height: 8),
                  _Notice('${formatDateTime(limit!.stoppedAt!)} ${limit.stopReason ?? '한도 도달'}로 종료'),
                ],
                const SizedBox(height: 10),
                _WorkerSettings(w),
              ],
            ),
    );
  }
}

/// 선택한 워커의 잡 전용 패널. 앱처럼 현재 잡과 종료된 전략을 탭으로 나눈다.
class _JobsPane extends StatefulWidget {
  const _JobsPane({
    super.key,
    required this.worker,
    required this.selected,
    required this.onSelect,
    required this.onTabChanged,
  });

  final MemberWorker? worker;
  final WorkerJob? selected;
  final ValueChanged<WorkerJob> onSelect;
  final VoidCallback onTabChanged;

  @override
  State<_JobsPane> createState() => _JobsPaneState();
}

class _JobsPaneState extends State<_JobsPane> {
  late bool _showFinished = widget.selected?.isFinished ?? false;

  /// 로그나 주문에서 잡을 열면 그 잡이 있는 탭으로 맞춘다.
  @override
  void didUpdateWidget(_JobsPane old) {
    super.didUpdateWidget(old);
    final job = widget.selected;
    if (job != null && !identical(job, old.selected)) _showFinished = job.isFinished;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.worker;
    if (w == null) return const _Pane(title: '잡', child: _Empty('워커를 선택하세요.'));
    final current = w.jobs.where((j) => !j.isFinished).toList();
    final finished = w.jobs.where((j) => j.isFinished).toList();
    final visible = _showFinished ? finished : current;

    Widget tab(String label, bool forFinished) => ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      selected: _showFinished == forFinished,
      onSelected: (_) {
        if (_showFinished == forFinished) return;
        setState(() => _showFinished = forFinished);
        widget.onTabChanged();
      },
    );

    return _Pane(
      title: '${w.symbolName} 잡',
      trailing: Wrap(
        spacing: 6,
        children: [tab('현재 잡 ${current.length}', false), tab('종료된 전략 ${finished.length}', true)],
      ),
      child: visible.isEmpty
          ? _Empty(_showFinished ? '종료된 전략이 없습니다.' : '실행 중인 잡이 없습니다.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                for (final j in visible)
                  _JobCard(j, w, selected: identical(j, widget.selected), onTap: () => widget.onSelect(j)),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent),
      ),
    );
  }
}

/// 앱 워커 설정 시트와 같은 항목·문구. 사용 안 하는 값도 빼지 않고 그대로 보여 준다.
class _WorkerSettings extends StatelessWidget {
  const _WorkerSettings(this.worker);

  final MemberWorker worker;

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final limit = w.pnlLimit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OnOffRow('장 마감 시 자동 청산', w.autoCloseOnMarketEnd),
        const Text(
          '국내주식 15:25 · 해외선물 장 종료 2분 전에 시장가로 청산합니다.',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _OnOffRow('누적 손익으로 워커 종료', limit != null),
        if (limit != null) ...[
          const SizedBox(height: 2),
          _SettingRow('초기화 주기', limit.periodLabel),
          _SettingRow('기준 단위', limit.isTick ? '틱' : '금액'),
          _SettingRow(
            '청산 수익 종료',
            limit.profitTarget == null ? null : '+${_limitText(limit.profitTarget!, limit, w)} 이상',
          ),
          _SettingRow('청산 손실 종료', limit.lossLimit == null ? null : '−${_limitText(limit.lossLimit!, limit, w)} 이하'),
          _SettingRow(
            limit.accumTitle,
            limit.isTick ? _signedTicks(limit.accumTicks) : _signedMoney(limit.accumAmount, w.currency),
          ),
          if (!limit.isTick) _SettingRow('평가 포함', _signedMoney(limit.accumAmount + w.unrealizedPnl, w.currency)),
          _SettingRow('청산 횟수', '${limit.accumCount}회'),
        ],
      ],
    );
  }

  static String _limitText(double v, WorkerPnlLimit limit, MemberWorker w) =>
      limit.isTick ? '${_num(v)}틱' : '${_num(v)} ${w.currency}';

  static String _signedTicks(double v) => '${v > 0 ? '+' : ''}${_num(v)}틱';
}

class _OnOffRow extends StatelessWidget {
  const _OnOffRow(this.label, this.on);

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Flexible(
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          StatusBadge(on ? 'ON' : 'OFF', color: on ? AppColors.success : AppColors.textTertiary),
        ],
      ),
    );
  }
}

/// 값이 null 이면 앱과 같이 흐린 글자로 '사용 안 함'.
class _SettingRow extends StatelessWidget {
  const _SettingRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value ?? '사용 안 함',
              style: TextStyle(fontSize: 12, color: value == null ? AppColors.textTertiary : null),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.up.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: AppColors.up, fontSize: 13)),
    );
  }
}

/// "이름 값" 짝을 한 줄에 이어 붙이고, 넘치면 다음 줄로 내린다.
class _Facts extends StatelessWidget {
  const _Facts(this.facts);

  final Map<String, String> facts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 3,
      children: [
        for (final MapEntry(:key, :value) in facts.entries)
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
    );
  }
}

Color _jobStatusColor(WorkerJob job) => switch (job.status) {
  'abnormal_terminated' || 'error' || 'failed' => AppColors.up,
  'monitoring' ||
  'bought' ||
  'submitted' ||
  'sent' ||
  'running' => job.isActive ? AppColors.success : AppColors.textTertiary,
  _ => AppColors.textTertiary,
};

String _jobAccount(WorkerJob job) => '${job.accountName} (${job.isPaper ? '모의' : '실전'})';

/// 잡 목록의 카드. 누르면 아래 잡 상세 패널에 설정과 이력이 나온다.
class _JobCard extends StatelessWidget {
  const _JobCard(this.job, this.worker, {required this.selected, required this.onTap});

  final WorkerJob job;
  final MemberWorker worker;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final p = job.position;
    final unrealized = p?.pnlAt(w.currentPrice);
    final rejects = job.rejectReasons;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.brand.withValues(alpha: 0.18) : AppColors.surfaceSoft,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? AppColors.brand : AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(job.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    if (job.isAlert) const StatusBadge('알람', color: AppColors.accent),
                    StatusBadge(job.statusLabel, color: _jobStatusColor(job)),
                  ],
                ),
                const SizedBox(height: 4),
                _Facts({
                  '전략': job.strategy.label,
                  '계좌': _jobAccount(job),
                  if (!job.isAlert) '반복': '${job.repeatCurrent}/${job.repeatCount}',
                  if (p != null) '보유': '${p.sideLabel} ${_num(p.size)}${w.qtyUnit} @${_num(p.entryPrice)}',
                }),
                if (!job.isAlert) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      _Pnl('실현', job.realizedPnl, w.currency),
                      if (unrealized != null) _Pnl('평가', unrealized, w.currency),
                    ],
                  ),
                ],
                // 앱과 같이 실패로 끝난 잡에만 거부 사유를 붙인다.
                if (job.isFinished)
                  for (final r in rejects)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(r, style: const TextStyle(color: AppColors.up, fontSize: 12)),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 선택한 잡의 상세. 앱은 설정·체결 내역·이력이 여러 화면으로 나뉘지만 상담용으로 한 패널에 모은다.
class _JobDetailPane extends StatelessWidget {
  const _JobDetailPane({required this.job, required this.worker});

  final WorkerJob? job;
  final MemberWorker? worker;

  @override
  Widget build(BuildContext context) {
    final j = job;
    final w = worker;
    if (j == null || w == null) return const _Pane(title: '잡 상세', child: _Empty('잡을 선택하세요.'));
    final p = j.position;
    final unrealized = p?.pnlAt(w.currentPrice);
    final summary = Wrap(
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusBadge(j.statusLabel, color: _jobStatusColor(j)),
        if (j.isAlert) const StatusBadge('알람', color: AppColors.accent),
        _Facts({
          '종목': '${w.symbolName} (${w.symbolCode})',
          if (!j.isAlert) '반복': '${j.repeatCurrent}/${j.repeatCount}',
          if (p != null) '보유': '${p.sideLabel} ${_num(p.size)}${w.qtyUnit} @${_num(p.entryPrice)}',
        }),
        if (!j.isAlert) _Pnl('실현 손익', j.realizedPnl, w.currency),
        if (unrealized != null) _Pnl('평가 손익', unrealized, w.currency),
      ],
    );
    final settings = _JobSettings(j, w);
    final history = _JobHistory(j, w);

    return _Pane(
      title: '${j.name} 상세',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            summary,
            const Divider(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 680) {
                    return ListView(children: [settings, const SizedBox(height: 12), history]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 300, child: SingleChildScrollView(child: settings)),
                      const SizedBox(width: 16),
                      Expanded(child: SingleChildScrollView(child: history)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 건수 요약 + 체결 내역 + 회차별 이력.
class _JobHistory extends StatelessWidget {
  const _JobHistory(this.job, this.worker);

  final WorkerJob job;
  final MemberWorker worker;

  @override
  Widget build(BuildContext context) {
    if (job.cycles.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('이력'),
          Text('아직 이력이 없어요', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ],
      );
    }
    final events = job.cycles.expand((c) => c.events).toList();
    int count(String type) => events.where((e) => e.type == type).length;
    final fills = events.where((e) => e.type == 'fill').toList()..sort((a, b) => b.at.compareTo(a.at));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('체결 내역'),
        Text(
          '주문 ${count('order_submitted')}건 · 체결 ${count('fill')}건 · 거부 ${count('order_rejected')}건',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        if (fills.isEmpty)
          const Text('아직 체결 내역이 없어요', style: TextStyle(color: AppColors.textTertiary, fontSize: 12))
        else
          for (final f in fills)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  SizedBox(
                    width: 136,
                    child: Text(
                      formatDateTime(f.at, seconds: true),
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      f.sideLabel,
                      style: TextStyle(fontSize: 12, color: f.side == 'buy' ? AppColors.up : AppColors.down),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${_num(f.qty ?? 0)}${worker.qtyUnit} @${_num(f.price ?? 0)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 12),
        _SectionTitle('이력 ${job.cycles.length}회차'),
        for (final c in job.cycles) _CycleCard(c, worker),
      ],
    );
  }
}

/// 앱 잡 "설정 보기"(읽기 전용)와 같은 구성. 사용하지 않는 값도 '사용 안 함'으로 둔다.
class _JobSettings extends StatelessWidget {
  const _JobSettings(this.job, this.worker);

  final WorkerJob job;
  final MemberWorker worker;

  @override
  Widget build(BuildContext context) {
    final s = job.strategy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${s.label} (상세보기)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const _SectionTitle('진입설정'),
        _SettingRow('전략 이름', job.name),
        _SettingRow('계좌', _jobAccount(job)),
        if (job.isAlert)
          const _SettingRow('주문', '알람 모드에서는 주문을 내지 않습니다')
        else ...[
          _SettingRow('거래 방향', job.entrySideLabel),
          _SettingRow('주문 유형', s.orderType),
          _SettingRow('주문 수량', '${_num(s.qty)}${worker.qtyUnit}'),
          _SettingRow('반복 횟수', '${job.repeatCount}회'),
        ],
        for (final MapEntry(:key, :value) in s.entrySettings.entries) _SettingRow(key, value),
        if (!job.isAlert) ...[
          const SizedBox(height: 10),
          const _SectionTitle('청산설정'),
          _SettingRow('손절', s.stopLossPct == null ? null : '${_num(s.stopLossPct!)}%'),
          _SettingRow('익절', s.takeProfitPct == null ? null : '${_num(s.takeProfitPct!)}%'),
          _SettingRow('트레일링 스탑', s.trailingStop),
        ],
      ],
    );
  }
}

/// 앱 이력 화면의 전략 설정 표기. 값이 없는 손절·익절은 빼지 않고 '사용 안 함'으로 둔다.
Map<String, String> _strategyFacts(JobStrategy s, MemberWorker w) => {
  '주문 수량': '${_num(s.qty)}${w.qtyUnit}',
  '손절': s.stopLossPct == null ? '사용 안 함' : '${_num(s.stopLossPct!)}%',
  '청산(익절)': s.takeProfitPct == null ? '사용 안 함' : '${_num(s.takeProfitPct!)}%',
};

/// 앱 이력 화면의 회차 카드 + 타임라인.
class _CycleCard extends StatelessWidget {
  const _CycleCard(this.cycle, this.worker);

  final JobCycle cycle;
  final MemberWorker worker;

  String _fill(double? qty, double? price) =>
      qty == null || price == null ? '-' : '${_num(qty)}${worker.qtyUnit} @${_num(price)}';

  @override
  Widget build(BuildContext context) {
    final c = cycle;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${c.cycleNo}회차', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              StatusBadge(c.statusLabel, color: c.status == 'open' ? AppColors.success : AppColors.textTertiary),
              if (c.realizedPnl != null) _Pnl('실현손익', c.realizedPnl!, worker.currency),
            ],
          ),
          const SizedBox(height: 4),
          _Facts({
            '매수': _fill(c.filledBuyQty, c.avgBuyPrice),
            '매도': _fill(c.filledSellQty, c.avgSellPrice),
            if (c.openedAt != null) '시작': formatDateTime(c.openedAt!, seconds: true),
            if (c.closedAt != null) '종료': formatDateTime(c.closedAt!, seconds: true),
          }),
          const SizedBox(height: 3),
          if (c.strategy == null)
            const Text('설정 정보 없음', style: TextStyle(color: AppColors.textTertiary, fontSize: 12))
          else
            _Facts({'전략': c.strategy!.label, ..._strategyFacts(c.strategy!, worker)}),
          const Divider(height: 14),
          for (final e in c.events)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 136,
                    child: Text(
                      formatDateTime(e.at, seconds: true),
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _eventLabel(e),
                      style: TextStyle(fontSize: 12, color: e.type == 'order_rejected' ? AppColors.up : null),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 앱 타임라인과 같은 문구.
  String _eventLabel(JobEvent e) {
    final side = e.sideLabel;
    final qty = e.qty == null ? '' : ' ${_num(e.qty!)}${worker.qtyUnit}';
    final at = e.price == null ? '' : ' @${_num(e.price!)}';
    final msg = e.message == null ? '' : ' · ${e.message}';
    return switch (e.type) {
      'alert_fired' => '$side 신호 발생$qty$msg',
      'order_submitted' => '$side주문$qty$at$msg',
      'order_accepted' => '접수됨',
      'fill' => '체결$qty$at',
      'order_rejected' => '${side.isEmpty ? '주문' : side} 거부$msg',
      'order_cancelled' => '주문 취소',
      'cycle_closed' => '사이클 종료',
      'sold_elsewhere' => '타 매체 매도됨',
      _ => e.type,
    };
  }
}

class _CustomerLogPane extends StatelessWidget {
  const _CustomerLogPane({
    required this.title,
    required this.logs,
    required this.searchKey,
    required this.periodLabel,
    required this.onSearchChanged,
    required this.onPeriodSelected,
    required this.onOpen,
    required this.category,
    required this.onCategoryChanged,
  });

  final String title;
  final Key searchKey; // 회원을 바꾸면 검색어를 비운다
  final String periodLabel;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_LogPeriod> onPeriodSelected;
  final ValueChanged<CustomerLog> onOpen;
  final List<CustomerLog> logs;
  final CustomerLogCategory? category;
  final ValueChanged<CustomerLogCategory?> onCategoryChanged;

  Color _color(CustomerLogCategory c) => switch (c) {
    CustomerLogCategory.access => AppColors.textTertiary,
    CustomerLogCategory.worker => AppColors.accent,
    CustomerLogCategory.order => AppColors.down,
    CustomerLogCategory.error => AppColors.up,
  };

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final l in logs)
        if (category == null || l.category == category) l,
    ];
    return _Pane(
      title: title,
      trailing: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in <CustomerLogCategory?>[null, ...CustomerLogCategory.values])
            ChoiceChip(
              label: Text(c?.label ?? '전체', style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              selected: c == category,
              onSelected: (_) => onCategoryChanged(c),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: searchKey,
                    onChanged: onSearchChanged,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 18),
                      hintText: '로그 검색',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<_LogPeriod>(
                  tooltip: '기간 선택',
                  onSelected: onPeriodSelected,
                  itemBuilder: (_) => [
                    for (final p in _LogPeriod.values) PopupMenuItem(value: p, child: Text(p.label)),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(periodLabel, style: const TextStyle(color: AppColors.accent, fontSize: 12)),
                      const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.accent),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const _Empty('로그가 없습니다.')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final l = visible[i];
                      return InkWell(
                        onTap: l.workerId == null ? null : () => onOpen(l),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  StatusBadge(l.category.label, color: _color(l.category)),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatDateTime(l.at, seconds: true),
                                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                                  ),
                                  if (l.workerId != null) ...[
                                    const Spacer(),
                                    const Icon(Icons.chevron_right, size: 16, color: AppColors.textTertiary),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(l.text, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
