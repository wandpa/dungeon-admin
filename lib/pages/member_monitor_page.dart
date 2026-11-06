import 'package:flutter/material.dart';

import '../live_api.dart';
import '../mock_accounts.dart';
import '../mock_admin.dart';
import '../mock_consultations.dart';
import '../mock_data.dart';
import '../mock_symbols.dart';
import '../mock_workers.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';
import 'consultations_page.dart' show consultStatusColor;
import 'member_detail_dialog.dart';
import 'members_page.dart' show memberStatusColor;

part 'member_monitor_accounts.dart';
part 'member_monitor_app_view.dart';
part 'member_monitor_cards.dart';
part 'member_monitor_trades.dart';

/// 다른 화면에서 이 회원을 모니터링으로 열어 달라는 요청.
/// [issue] 를 주면 그 문제 위치로, [logs] 면 고객 로그로 간다.
class MonitorRequest {
  const MonitorRequest(this.memberId, {this.issue, this.logs = false});
  final int memberId;
  final MemberIssue? issue;
  final bool logs;
}

final memberMonitorRequest = ValueNotifier<MonitorRequest?>(null);

/// 샘플은 데이터의 마지막 날을 오늘로 본다. 테스트 DB 는 실제 날짜다.
DateTime get _mockToday {
  if (!useLiveData.value) return DateTime(2026, 10, 30);
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

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
  const MemberMonitorPage({super.key, this.onExit});

  final ValueChanged<int?>? onExit; // 워커 목록에서 뒤로 가면 보던 회원을 들고 회원 목록으로 나간다

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
  int? _loadingMemberId; // 테스트 DB 에서 받는 중인 회원
  String? _loadingJobId; // 테스트 DB 에서 받는 중인 잡
  bool _loadingLogs = false;
  String? _liveError;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    liveStatus.addListener(_onLiveChanged);
    final request = memberMonitorRequest.value;
    memberMonitorRequest.value = null;
    if (request == null) return;
    _memberId = request.memberId;
    if (request.issue != null) _applyIssue(request.issue!);
    if (request.logs) _tab = _MonitorTab.logs;
  }

  @override
  void dispose() {
    liveStatus.removeListener(_onLiveChanged);
    _scroll.dispose();
    super.dispose();
  }

  /// 전체 워커로 나간다. 워커·잡을 보던 화면이면 워커 목록을 보여 준다.
  void _showAllWorkers() => setState(() {
    _workerId = null;
    _job = null;
    if (_tab == _MonitorTab.jobs || _tab == _MonitorTab.jobDetail) _tab = _MonitorTab.workers;
  });

  /// 고른 워커의 잡 목록으로 나간다.
  void _showWorkerJobs() => setState(() {
    _job = null;
    if (_tab == _MonitorTab.jobDetail) _tab = _MonitorTab.jobs;
  });

  /// 잡 내역 → 잡 → 워커 → 회원 목록 순서로 한 단계씩 나간다.
  /// 잡 목록으로 갈 때는 보던 잡을 남겨 둔다. 종료된 전략 칸과 선택 표시가 그대로 이어진다.
  void _back() {
    switch (_tab) {
      case _MonitorTab.jobDetail:
        setState(() => _tab = _MonitorTab.jobs);
      case _MonitorTab.jobs:
        _showAllWorkers();
      case _MonitorTab.workers:
        widget.onExit?.call(_member?.id);
      default:
        setState(() => _tab = _MonitorTab.workers);
    }
  }

  /// 잡을 고르면 잡 내역으로 넘어간다.
  void _selectJob(WorkerJob job) => setState(() {
    _job = job;
    _tab = _MonitorTab.jobDetail;
  });

  CustomerLogCategory? _logCategory; // null 이면 전체

  /// 승인 전 회원은 로그인할 수 없어 볼 내용이 없다.
  List<Member> get _members => [
    for (final m in currentMembers)
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
      if (workersOf(m.id).isNotEmpty || m.liveWorkerCount > 0) return m;
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
        _tab = _MonitorTab.jobs;
        _workerId = issue.workerId;
      case MemberIssueKind.waitingOrders:
        _tab = _MonitorTab.accounts;
        _orderFilter = _OrderFilter.waiting;
      case MemberIssueKind.rejectedOrders:
        _tab = _MonitorTab.accounts;
        _orderFilter = _OrderFilter.rejected;
      case MemberIssueKind.manualPositions:
        _tab = _MonitorTab.positions;
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
      _tab = _MonitorTab.jobs;
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

  /// 회원 목록을 다시 받으면 보던 화면은 그대로 두고 지금 회원의 값을 새로 받는다.
  void _onLiveChanged() {
    if (mounted) setState(() => _liveError = null);
  }

  /// 값을 새로 받은 뒤 열어 둔 잡을 새 값으로 바꾼다. 잡 내역은 다음 그리기에서 다시 받는다.
  void _refreshOpenJob(Member m) {
    final id = _job?.liveId;
    if (id == null || !mounted) return;
    final jobs = workersOf(m.id).expand((w) => w.jobs);
    setState(() => _job = jobs.where((j) => j.liveId == id).firstOrNull);
  }

  /// 테스트 DB 회원은 처음 볼 때 받아 온다. 실패하면 다시 시도하지 않고 오류를 보여 준다.
  Future<void> _loadMember(Member m) async {
    setState(() {
      _loadingMemberId = m.id;
      _liveError = null;
    });
    try {
      await loadLiveMember(m);
      _refreshOpenJob(m);
    } on LiveApiException catch (e) {
      if (mounted) setState(() => _liveError = e.message);
    }
    if (mounted) setState(() => _loadingMemberId = null);
  }

  /// 재조회: 지금 회원의 값을 새로 받는다. 열어 둔 잡은 새 값으로 바꿔 내역도 다시 받는다.
  /// 실패하면 받아 둔 값을 그대로 두고 오류를 보여 준다.
  Future<void> _reload(Member m) async {
    setState(() {
      _loadingMemberId = m.id;
      _liveError = null;
    });
    try {
      await reloadLiveMember(m);
      _refreshOpenJob(m);
    } on LiveApiException catch (e) {
      if (mounted) setState(() => _liveError = e.message);
    }
    if (mounted) setState(() => _loadingMemberId = null);
  }

  /// 잡 설정과 회차는 잡을 고를 때 받는다.
  Future<void> _loadJob(Member m, WorkerJob job) async {
    setState(() {
      _loadingJobId = job.liveId;
      _liveError = null;
    });
    try {
      final filled = await loadLiveJobDetail(m, job);
      if (mounted && _job == job) setState(() => _job = filled);
    } on LiveApiException catch (e) {
      if (mounted) setState(() => _liveError = e.message);
    }
    if (mounted) setState(() => _loadingJobId = null);
  }

  Future<void> _loadLogs(Member m, int workerId) async {
    setState(() {
      _loadingLogs = true;
      _liveError = null;
    });
    try {
      await loadLiveWorkerLogs(m, workerId);
    } on LiveApiException catch (e) {
      if (mounted) setState(() => _liveError = e.message);
    }
    if (mounted) setState(() => _loadingLogs = false);
  }

  /// 화면을 그린 뒤 아직 받지 않은 테스트 DB 값을 받는다.
  void _loadMissing(Member? member, MemberWorker? worker) {
    if (member == null || !member.isLive || _liveError != null) return;
    final job = _job;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!isLiveLoaded(member)) {
        if (_loadingMemberId == null) _loadMember(member);
      } else if (job != null && !job.detailLoaded && _loadingJobId == null) {
        _loadJob(member, job);
      } else if (worker != null && !isLiveWorkerLogsLoaded(worker.id) && !_loadingLogs) {
        _loadLogs(member, worker.id);
      }
    });
  }

  /// 회원을 바꾸면 워커부터 다시 본다.
  void _selectMember(Member m) => setState(() {
    _memberId = m.id;
    _liveError = null;
    _tab = _MonitorTab.workers;
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
    _loadMissing(member, worker);
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
      // 워커를 고르면 그 워커의 잡으로 넘어간다.
      onSelect: (w) => setState(() {
        _workerId = w.id;
        _job = null;
        _tab = _MonitorTab.jobs;
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
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = SizedBox(width: 12, height: 12);
          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              if (_loadingMemberId != null || _loadingJobId != null || _loadingLogs) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (_liveError != null) ...[
                const SizedBox(height: 8),
                Text(' API 서버가 실행 중인지 확인하세요.', style: const TextStyle(color: AppColors.up)),
              ],
            ],
          );

          final narrow = constraints.maxWidth < 1000;
          final bar = _MemberBar(
            member: member,
            tab: _tab,
            onReload: member == null || !member.isLive ? null : () => _reload(member),
            reloading: _loadingMemberId != null || _loadingJobId != null || _loadingLogs,
            onDetail: () async {
              if (member == null) return;
              await showMemberDetail(context, member);
              if (mounted) setState(() {});
            },
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
          // 거래·포지션은 고른 워커·잡으로 좁힌다.
          final scopedPositions = [
            for (final x in positions)
              if ((worker == null || x.workerId == worker.id) && (_job == null || x.jobName == _job!.name)) x,
          ];
          final scopedOrders = [
            for (final x in orders)
              if ((worker == null || x.workerId == worker.id) && (_job == null || x.jobName == _job!.name)) x,
          ];
          final scopeBar = _ScopeBar(
            worker: worker,
            job: _job,
            onAll: _showAllWorkers,
            onWorker: _showWorkerJobs,
            onBack: _tab == _MonitorTab.workers && widget.onExit == null ? null : _back,
          );
          final positionsPane = _PositionsPane(
            positions: scopedPositions,
            onOpen: (p) => _openWorker(p.workerId, p.jobName),
          );
          final ordersPane = _OrdersPane(
            orders: orders,
            filter: _orderFilter,
            onFilterChanged: (f) => setState(() => _orderFilter = f),
            onOpen: (o) => _openWorker(o.workerId, o.jobName),
          );
          final tradesPane = _TradesPane(
            key: ValueKey('${member?.id}/$_accountName/${worker?.id}/${_job?.name}'),
            positions: scopedPositions,
            orders: scopedOrders,
            onOpen: _openWorker,
          );
          // 테스트 DB 회원은 받기 전에 '문제 없음'으로 보이지 않게 한다.
          final issueBar = member == null || (member.isLive && !isLiveLoaded(member))
              ? null
              : _IssueBar(issues: issuesOf(member), onOpen: _openIssue);
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
                scopeBar,
                gap,
                ?issueBar,
                gap,
                if (accountBar != null) ...[accountBar, gap],
                ...switch (_tab) {
                  _MonitorTab.workers => [SizedBox(height: 520, child: workerPane)],
                  _MonitorTab.jobs => [
                    SizedBox(height: 420, child: jobsPane),
                    gap,
                    SizedBox(height: 420, child: settingsPane),
                  ],
                  _MonitorTab.jobDetail => [SizedBox(height: 720, child: detailPane)],
                  _MonitorTab.trades => [SizedBox(height: 720, child: tradesPane)],
                  _MonitorTab.positions => [SizedBox(height: 520, child: positionsPane)],
                  _MonitorTab.logs => [SizedBox(height: 620, child: logPane)],
                  _MonitorTab.accounts => [
                    SizedBox(height: 320, child: accountsPane),
                    gap,
                    SizedBox(height: 280, child: summaryPane),
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
            _MonitorTab.workers => workerPane,
            _MonitorTab.jobs => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: jobsPane),
                gap,
                Expanded(flex: 2, child: settingsPane),
              ],
            ),
            _MonitorTab.jobDetail => detailPane,
            _MonitorTab.trades => tradesPane,
            _MonitorTab.positions => positionsPane,
            _MonitorTab.logs => logPane,
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
                      Expanded(child: ordersPane),
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

          final height = constraints.maxHeight;
          return SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                              Wrap(
                                spacing: 16,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [scopeBar, ?accountBar, ?issueBar],
                              ),
                              const SizedBox(height: 8),
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
        Text('워커 → 잡 → 잡 내역 → 거래 → 포지션 → 로그 순서로 봅니다.', style: TextStyle(color: AppColors.textTertiary)),
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
                      final count = m.isLive ? m.liveWorkerCount : workers.length;
                      final running = m.isLive
                          ? m.liveRunningCount
                          : workers.where((w) => w.status == WorkerStatus.running).length;
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
                              TextSpan(text: count == 0 ? '워커 없음' : '워커 $count개 · 실행 $running'),
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

  @override
  Widget build(BuildContext context) {
    final running = workers.where((w) => w.status == WorkerStatus.running).length;
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              children: [
                for (final w in sorted) _WorkerCard(w, selected: w.id == selected?.id, onTap: () => onSelect(w)),
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
    return _Pane(
      title: w == null ? '워커 설정' : '${w.symbolName} 워커 설정',
      child: w == null
          ? const _Empty('워커를 선택하세요.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                _Facts({
                  '시장': w.marketType,
                  '현재가': w.currentPrice == null ? '-' : _num(w.currentPrice!),
                  '등록일': formatDateTime(w.insertedAt),
                }),
                if (w.errorMessage != null) ...[const SizedBox(height: 8), _Notice(w.errorMessage!)],
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
    List<WorkerJob> slot(JobSlot s) => current.where((j) => j.slot == s).toList();
    Widget card(WorkerJob j) =>
        _JobCard(j, w, selected: identical(j, widget.selected), onTap: () => widget.onSelect(j));

    return _Pane(
      title: '${w.symbolName} 잡',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _JobTabs(
              finished: _showFinished,
              onChanged: (value) {
                if (_showFinished == value) return;
                setState(() => _showFinished = value);
                widget.onTabChanged();
              },
            ),
          ),
          Expanded(
            child: _showFinished && visible.isEmpty
                ? const _Empty('종료된 전략이 없습니다.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: _showFinished
                        ? [
                            const _FinishedActions(),
                            for (final j in visible)
                              _FinishedJobCard(
                                j,
                                w,
                                selected: identical(j, widget.selected),
                                onTap: () => widget.onSelect(j),
                              ),
                          ]
                        : [
                            // 앱과 같은 순서: 워커 카드(실행 슬롯 포함) → 중지됨 → 대기열.
                            _WorkerSlotCard(
                              w,
                              slot: _RunSlot(
                                workerRunning: w.status == WorkerStatus.running,
                                children: [for (final j in slot(JobSlot.running)) card(j)],
                              ),
                            ),
                            if (slot(JobSlot.stopped).isNotEmpty) ...[
                              const _SlotHeader('중지됨', note: '꺼져 있어 매매하지 않습니다'),
                              for (final j in slot(JobSlot.stopped)) card(j),
                            ],
                            const _QueueHeader(),
                            if (slot(JobSlot.queued).isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(left: 2),
                                child: Text(
                                  '대기 중인 잡이 없습니다.',
                                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                                ),
                              ),
                            for (final j in slot(JobSlot.queued)) card(j),
                          ],
                  ),
          ),
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

class _SlotHeader extends StatelessWidget {
  const _SlotHeader(this.title, {this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6, left: 2),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent),
          ),
          if (note != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
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
    final fills = _JobFills(j, w);
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
                  // 체결 내역, 이력, 설정 보기 순서다. 좁아지면 앞의 둘부터 묶는다.
                  if (constraints.maxWidth < 680) {
                    return ListView(
                      children: [fills, const SizedBox(height: 12), history, const Divider(height: 24), settings],
                    );
                  }
                  final wide = constraints.maxWidth >= 1000;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (wide) ...[
                        Expanded(child: SingleChildScrollView(child: fills)),
                        const SizedBox(width: 16),
                        Expanded(child: SingleChildScrollView(child: history)),
                      ] else
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [fills, const Divider(height: 24), history],
                            ),
                          ),
                        ),
                      const SizedBox(width: 16),
                      SizedBox(width: 380, child: SingleChildScrollView(child: settings)),
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
