part of 'member_monitor_page.dart';

/// 고객 상담 흐름 순서: 워커 → 잡 → 잡 내역 → 거래 → 포지션 → 로그. 계좌와 알림은 뒤에 둔다.
enum _MonitorTab {
  workers('워커'),
  jobs('잡'),
  jobDetail('잡 내역'),
  trades('거래'),
  positions('포지션'),
  logs('로그'),
  accounts('계좌'),
  notifications('알림'),
  signals('신호', liveOnly: true),
  strategies('전략', liveOnly: true),
  watchlist('관심종목', liveOnly: true),
  symbols('종목', liveOnly: true);

  const _MonitorTab(this.label, {this.liveOnly = false});
  final String label;
  final bool liveOnly; // 샘플 데이터에는 없는 화면
}

/// 지금 보여 줄 탭.
Iterable<_MonitorTab> get _shownTabs => _MonitorTab.values.where((t) => useLiveData.value || !t.liveOnly);

/// 지금 보고 있는 범위. 누르면 그 단계로 돌아간다.
class _ScopeBar extends StatelessWidget {
  const _ScopeBar({required this.worker, required this.job, required this.onAll, required this.onWorker, this.onBack});

  final MemberWorker? worker;
  final WorkerJob? job;
  final VoidCallback onAll;
  final VoidCallback onWorker;
  final VoidCallback? onBack; // 한 단계 위로 나간다

  @override
  Widget build(BuildContext context) {
    final w = worker, j = job;
    Widget step(String label, VoidCallback? onTap) => TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
    const arrow = Icon(Icons.chevron_right, size: 16, color: AppColors.textTertiary);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onBack != null) ...[
          OutlinedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back, size: 16), label: const Text('뒤로')),
          const SizedBox(width: 8),
        ],
        step('전체 워커', w == null ? null : onAll),
        if (w != null) ...[arrow, step(w.symbolName, j == null ? null : onWorker)],
        if (j != null) ...[arrow, step(j.name, null)],
      ],
    );
  }
}

/// 선택한 회원의 모드와 화면 탭. 패널들 위에 늘 보인다.
class _MemberBar extends StatelessWidget {
  const _MemberBar({
    required this.member,
    required this.tab,
    required this.onTabChanged,
    required this.onDetail,
    this.onReload,
    this.reloading = false,
    this.tabsOnly = false,
  });

  final Member? member;
  final bool tabsOnly; // 회원 이름과 재조회는 위 줄에 있다
  final _MonitorTab tab;
  final ValueChanged<_MonitorTab> onTabChanged;
  final VoidCallback onDetail;
  final VoidCallback? onReload; // 테스트 DB 회원만 있다
  final bool reloading;

  @override
  Widget build(BuildContext context) {
    final m = member;
    final loadedAt = m == null ? null : liveLoadedAt(m);
    Widget chip(_MonitorTab t, String label) => ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      visualDensity: VisualDensity.compact,
      selected: tab == t,
      onSelected: (_) => onTabChanged(t),
    );
    final mode = m == null || m.isLive ? null : tradeModeOf(m.id);
    if (tabsOnly) {
      return Wrap(spacing: 6, runSpacing: 6, children: [for (final t in _shownTabs) chip(t, t.label)]);
    }
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        if (m != null)
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(m.username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              // 사용 모드는 앱이 서버로 보내야 알 수 있어 테스트 DB 회원은 비어 있다.
              if (mode != null) ...[
                const Text('사용 모드', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                StatusBadge(
                  mode.label,
                  color: switch (mode) {
                    TradeMode.real => AppColors.up,
                    TradeMode.paper => AppColors.down,
                    TradeMode.alert => AppColors.accent,
                  },
                ),
              ],
              Text(m.device, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              TextButton(onPressed: onDetail, child: const Text('회원 정보·처리')),
            ],
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final t in _shownTabs) chip(t, t.label),
            if (onReload != null) ...[
              if (loadedAt != null)
                Text(
                  '조회 ${formatDateTime(loadedAt, seconds: true).substring(11)}',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              OutlinedButton.icon(
                onPressed: reloading ? null : onReload,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('재조회', style: TextStyle(fontSize: 13)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 회원을 고르자마자 볼 문제 요약. 누르면 해당 위치로 이동한다.
class _IssueBar extends StatelessWidget {
  const _IssueBar({required this.issues, required this.onOpen});

  final List<MemberIssue> issues;
  final ValueChanged<MemberIssue> onOpen;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
          SizedBox(width: 6),
          Text('확인할 문제가 없습니다.', style: TextStyle(color: AppColors.success, fontSize: 13)),
        ],
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
        for (final i in issues)
          ActionChip(
            label: Text(i.label, style: const TextStyle(fontSize: 12, color: AppColors.warning)),
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: AppColors.warning),
            onPressed: i.kind == MemberIssueKind.memberStatus ? null : () => onOpen(i),
          ),
      ],
    );
  }
}

/// 상담하면서 쓰는 상담 이력. 지금 보고 있는 워커·잡이 있으면 함께 기록한다.
class _ConsultPane extends StatefulWidget {
  const _ConsultPane({super.key, required this.member, required this.worker, required this.job, required this.onOpen});

  final Member member;
  final MemberWorker? worker;
  final WorkerJob? job;
  final ValueChanged<Consultation> onOpen;

  @override
  State<_ConsultPane> createState() => _ConsultPaneState();
}

class _ConsultPaneState extends State<_ConsultPane> {
  final _content = TextEditingController();
  ConsultChannel _channel = ConsultChannel.phone;
  ConsultType _type = ConsultType.order;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  void _add() {
    final text = _content.text.trim();
    if (text.isEmpty) return;
    if (widget.member.isLive) return showNotConnected(context);
    setState(
      () => addConsultation(
        widget.member,
        _channel,
        _type,
        text,
        workerId: widget.worker?.id,
        workerName: widget.worker?.symbolName,
        jobName: widget.job?.name,
      ),
    );
    _content.clear();
  }

  Widget _picker<T>(T value, List<T> values, String Function(T) label, ValueChanged<T> onChanged) {
    return DropdownButton<T>(
      value: value,
      isDense: true,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
      items: [
        for (final v in values)
          DropdownMenuItem(
            value: v,
            child: Text(label(v), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) setState(() => onChanged(v));
      },
    );
  }

  Widget _item(Consultation c) {
    final link = c.linkLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PopupMenuButton<ConsultStatus>(
                tooltip: '상담 상태 변경',
                onSelected: (s) => setState(() => setConsultStatus(c, s)),
                itemBuilder: (_) => [
                  for (final s in ConsultStatus.values) PopupMenuItem(value: s, child: Text(s.label)),
                ],
                child: StatusBadge(c.status.label, color: consultStatusColor(c.status)),
              ),
              Text(
                '${c.channel.label} · ${c.type.label}',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(c.content, style: const TextStyle(fontSize: 12)),
          if (link != null)
            InkWell(
              onTap: () => widget.onOpen(c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(link, style: const TextStyle(color: AppColors.accent, fontSize: 11)),
              ),
            ),
          Text(
            '${formatDateTime(c.at)} · ${c.adminName}'
            '${c.handledBy == null ? '' : ' · 처리 ${c.handledBy}'}',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final consultations = consultationsOf(m.id);
    final context_ = widget.worker == null ? null : [widget.worker!.symbolName, ?widget.job?.name].join(' · ');
    return _Pane(
      title: '상담 이력 ${consultations.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상담은 테스트 DB 에 저장할 곳이 없어 저장 때 안내만 한다.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _picker(_channel, ConsultChannel.values, (c) => c.label, (c) => _channel = c)),
                    const SizedBox(width: 8),
                    Expanded(child: _picker(_type, ConsultType.values, (t) => t.label, (t) => _type = t)),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _content,
                  onSubmitted: (_) => _add(),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '상담 내용 입력',
                    isDense: true,
                    suffixIcon: IconButton(
                      tooltip: '상담 기록 추가',
                      icon: const Icon(Icons.send, size: 18),
                      onPressed: _add,
                    ),
                  ),
                ),
                if (context_ != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '연결: $context_',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              children: [
                if (consultations.isEmpty)
                  const Text('상담 이력이 없습니다.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                for (final c in consultations) _item(c),
                if (m.history.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const _SectionTitle('회원 처리 이력'),
                  for (final l in m.history)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.text, style: const TextStyle(fontSize: 12)),
                          Text(
                            '${formatDateTime(l.at)} · ${l.actor}',
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 워커·잡과 알림 탭에서 계좌를 고르는 줄. 고르면 그 계좌의 잡·손익·로그·알림만 나온다.
class _AccountFilterBar extends StatelessWidget {
  const _AccountFilterBar({required this.accounts, required this.selected, required this.onSelect});

  final List<MemberAccount> accounts;
  final String? selected; // null 이면 전체 계좌
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: selected,
      isDense: true,
      underline: const SizedBox.shrink(),
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      items: [
        const DropdownMenuItem<String?>(child: Text('전체 계좌')),
        for (final a in accounts)
          DropdownMenuItem<String?>(value: a.name, child: Text('${a.name} ${a.maskedCano}${a.isPaper ? ' 모의' : ''}')),
      ],
      onChanged: onSelect,
    );
  }
}

String _moneyByCurrency(Map<String, double> sums) =>
    sums.isEmpty ? '-' : sums.entries.map((e) => _signedMoney(e.value, e.key)).join(' · ');

class _AccountsPane extends StatelessWidget {
  const _AccountsPane({required this.accounts, required this.selected, required this.onSelect});

  final List<MemberAccount> accounts;
  final String? selected; // null 이면 전체 계좌
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget tile(String title, String subtitle, String? name, {Widget? trailing}) => ListTile(
      dense: true,
      selected: selected == name,
      selectedTileColor: AppColors.brand.withValues(alpha: 0.18),
      selectedColor: AppColors.textPrimary,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
      trailing: trailing,
      onTap: () => onSelect(name),
    );
    return _Pane(
      title: '계좌 ${accounts.length}개',
      child: accounts.isEmpty
          ? const _Empty('등록된 계좌가 없습니다')
          : ListView(
              children: [
                tile('전체 계좌', '거래 내역 · 통화별 총자산', null),
                const Divider(height: 1),
                for (final a in accounts)
                  tile(
                    a.name,
                    '${a.marketType} · ${a.maskedCano} · ${a.brokerCode}',
                    a.name,
                    trailing: StatusBadge(
                      a.isAlert
                          ? '알람'
                          : a.isPaper
                          ? '모의'
                          : '실전',
                      color: a.isAlert
                          ? AppColors.warning
                          : a.isPaper
                          ? AppColors.down
                          : AppColors.success,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 잔고와 주문·보유 합산. 실전과 모의는 절대 합치지 않고, 통화가 달라도 줄을 나눈다.
class _AccountSummaryPane extends StatelessWidget {
  const _AccountSummaryPane({
    required this.memberId,
    required this.accountName,
    required this.accounts,
    required this.positions,
    required this.orders,
  });

  final int? memberId;
  final String? accountName;
  final List<MemberAccount> accounts;
  final List<AccountPosition> positions;
  final List<AccountOrder> orders;

  List<Widget> _block(String title, List<MemberAccount> list) {
    final names = {for (final a in list) a.name};
    final byCurrency = <String, List<MemberAccount>>{};
    for (final a in list) {
      (byCurrency[a.currency] ??= []).add(a);
    }
    double sum(List<MemberAccount> l, double Function(MemberAccount) f) => l.fold(0, (s, a) => s + f(a));
    final realized = <String, double>{};
    final id = memberId;
    if (id != null) {
      for (final n in names) {
        realizedPnlOf(id, accountName: n).forEach((c, v) => realized.update(c, (s) => s + v, ifAbsent: () => v));
      }
    }
    final unrealized = <String, double>{};
    for (final p in positions) {
      final v = p.unrealizedPnl;
      if (v != null && names.contains(p.accountName)) {
        unrealized.update(p.currency, (s) => s + v, ifAbsent: () => v);
      }
    }
    return [
      _SectionTitle(title),
      for (final MapEntry(key: currency, value: l) in byCurrency.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: _Facts({
            '통화': currency,
            '예수금': _num(sum(l, (a) => a.deposit)),
            '주문가능금액': _num(sum(l, (a) => a.orderableCash)),
            '총평가금액': _num(sum(l, (a) => a.totalEval)),
            '총자산': _num(sum(l, (a) => a.totalAsset)),
          }),
        ),
      _Facts({'실현손익': _moneyByCurrency(realized), '평가손익': _moneyByCurrency(unrealized)}),
      const SizedBox(height: 8),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final held = accounts.where((a) => a.hasBalance).toList();
    final real = held.where((a) => !a.isPaper && !a.isAlert).toList();
    final paper = held.where((a) => a.isPaper).toList();
    final snapshot = held.map((a) => a.snapshotAt).fold<DateTime?>(null, (l, t) => l == null || t.isAfter(l) ? t : l);

    return _Pane(
      title: accountName ?? '통화별 총자산',
      trailing: snapshot == null
          ? null
          : Text(
              '잔고 조회 ${formatDateTime(snapshot)}',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (held.isEmpty) const Text('잔고가 없습니다.', style: TextStyle(color: AppColors.textTertiary)),
          if (real.isNotEmpty) ..._block('실전', real),
          if (paper.isNotEmpty) ..._block('모의', paper),
          _Facts({
            '주문': '${orders.length}건',
            '체결': '${orders.where((o) => o.isFilled).length}건',
            '미체결': '${orders.where((o) => o.isWaiting).length}건',
            '거부': '${orders.where((o) => o.isRejected).length}건',
            '보유종목': '${positions.length}종목',
          }),
        ],
      ),
    );
  }
}

class _PositionsPane extends StatelessWidget {
  const _PositionsPane({required this.positions, required this.onOpen});

  final List<AccountPosition> positions;
  final ValueChanged<AccountPosition> onOpen; // 잡이 있는 포지션을 누르면 그 잡으로 간다

  @override
  Widget build(BuildContext context) {
    return _Pane(
      title: '보유 포지션 ${positions.length}',
      child: positions.isEmpty
          ? const _Empty('보유 종목이 없습니다.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: positions.length,
              separatorBuilder: (_, _) => const Divider(height: 12),
              itemBuilder: (context, i) {
                final p = positions[i];
                final pnl = p.unrealizedPnl;
                return InkWell(
                  onTap: p.jobName == null ? null : () => onOpen(p),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${p.symbolName} (${p.symbolCode})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (p.jobName == null) const StatusBadge('수동', color: AppColors.warning),
                          if (pnl != null) _PnlValue(pnl, p.currency),
                        ],
                      ),
                      const SizedBox(height: 3),
                      _Facts({
                        '보유':
                            '${p.position.sideLabel} ${_num(p.position.size)}${p.qtyUnit} @${_num(p.position.entryPrice)}',
                        '현재가': p.currentPrice == null ? '-' : _num(p.currentPrice!),
                        '잡': p.jobName ?? '연결된 job이 없음',
                        '계좌': p.accountName,
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

enum _OrderFilter {
  all('전체'),
  filled('체결'),
  waiting('미체결'),
  rejected('거부');

  const _OrderFilter(this.label);
  final String label;

  bool matches(AccountOrder o) => switch (this) {
    _OrderFilter.all => true,
    _OrderFilter.filled => o.isFilled,
    _OrderFilter.waiting => o.isWaiting,
    _OrderFilter.rejected => o.isRejected,
  };
}

class _OrdersPane extends StatelessWidget {
  const _OrdersPane({
    required this.orders,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpen,
    this.more,
    this.onMore,
  });

  final ValueChanged<AccountOrder> onOpen; // 주문을 누르면 그 잡으로 간다
  final List<AccountOrder> orders;
  final _OrderFilter filter;
  final ValueChanged<_OrderFilter> onFilterChanged;
  final (int, int)? more; // 더 받을 수 있으면 (받은 건수, 전체 건수)
  final Future<void> Function()? onMore;

  Color _statusColor(AccountOrder o) => o.isRejected || o.status == 'failed'
      ? AppColors.up
      : o.isFilled
      ? AppColors.success
      : o.isWaiting
      ? AppColors.warning
      : AppColors.textTertiary;

  @override
  Widget build(BuildContext context) {
    final visible = orders.where(filter.matches).toList();
    return _Pane(
      title: '주문 내역',
      trailing: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final f in _OrderFilter.values)
            ChoiceChip(
              label: Text('${f.label} ${orders.where(f.matches).length}', style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              selected: f == filter,
              onSelected: (_) => onFilterChanged(f),
            ),
        ],
      ),
      child: visible.isEmpty && more == null
          ? const _Empty('주문 내역이 없습니다.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: visible.length + (more == null ? 0 : 1),
              separatorBuilder: (_, _) => const Divider(height: 12),
              itemBuilder: (context, i) {
                if (i == visible.length) return _MoreButton('주문', more!, onMore!);
                final o = visible[i];
                return InkWell(
                  onTap: () => onOpen(o),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge(o.statusLabel, color: _statusColor(o)),
                          Text(
                            '${o.symbolName} ${o.sideLabel}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            formatDateTime(o.at, seconds: true),
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                          ),
                          if (o.realizedPnl != null)
                            Text(
                              '손익 ${_appSigned(o.realizedPnl!, o.currency)}',
                              style: TextStyle(
                                color: _pnlColor(o.realizedPnl!),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      _Facts({
                        '주문': '${_num(o.qty)}${o.qtyUnit}',
                        '체결': '${_num(o.filledQty)}${o.qtyUnit}',
                        if (o.avgFillPrice != null) '체결가': _appPrice(o.avgFillPrice!, o.currency),
                        if (o.isFilled) '체결금액': _appPrice(o.filledAmount, o.currency),
                        if (o.buyPrice != null) '매수가': _appPrice(o.buyPrice!, o.currency),
                        if (o.sellPrice != null) '매도가': _appPrice(o.sellPrice!, o.currency),
                        '잡': o.jobName,
                        '계좌': o.accountName,
                      }),
                      if (o.message != null) ...[
                        const SizedBox(height: 3),
                        Text(o.message!, style: const TextStyle(color: AppColors.up, fontSize: 12)),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// 앱 알림 설정 화면과 같은 항목. 문제가 있으면 앱과 같은 안내를 붙인다.
class _NotificationSettingsPane extends StatelessWidget {
  const _NotificationSettingsPane({required this.state});

  final NotificationState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return _Pane(
      title: '알림 설정',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (s.deviceSettingsKnown) ...[_OnOffRow('푸시 알림 허용', s.pushAllowed), const SizedBox(height: 10)],
          const _SectionTitle('푸시 진단'),
          if (s.deviceSettingsKnown) ...[
            _DiagRow('푸시 지원', s.supported, '홈 화면에 추가한 앱에서만 됩니다'),
            _DiagRow('알림 권한', s.permitted, '기기 설정에서 허용하세요'),
          ],
          _DiagRow('기기 토큰', s.hasToken, '토큰을 받지 못했습니다'),
          _DiagRow('서버 등록', s.onServer, '푸시가 나갈 곳이 없습니다'),
          if (s.deviceSettingsKnown) ...[
            const SizedBox(height: 10),
            const _SectionTitle('알림 방식'),
            _OnOffRow('소리', s.sound),
            _OnOffRow('진동', s.vibration),
            _OnOffRow('앱 화면 배너', s.banner),
          ],
          const SizedBox(height: 10),
          // 앱 알림 설정의 테스트 푸시와 같다. 상담 중 푸시가 가는지 확인할 때 쓴다.
          OutlinedButton.icon(
            onPressed: s.hasToken && can(AdminPermission.sendPush) ? () => showNotConnected(context) : null,
            icon: const Icon(Icons.send, size: 16),
            label: const Text('테스트 푸시 보내기'),
          ),
        ],
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow(this.label, this.ok, this.hint);

  final String label;
  final bool ok;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 13))),
          StatusBadge(ok ? '정상' : '확인 필요', color: ok ? AppColors.success : AppColors.up),
          if (!ok) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(hint, style: const TextStyle(color: AppColors.up, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationHistoryPane extends StatelessWidget {
  const _NotificationHistoryPane({required this.messages});

  final List<NotificationMessage> messages;

  @override
  Widget build(BuildContext context) {
    final unread = messages.where((m) => !m.isRead).length;
    return _Pane(
      title: '알림 이력 ${messages.length}',
      trailing: messages.isEmpty
          ? null
          : Text('읽지 않음 $unread', style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
      child: messages.isEmpty
          ? const _Empty('받은 알림이 없습니다.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: messages.length,
              separatorBuilder: (_, _) => const Divider(height: 12),
              itemBuilder: (context, i) {
                final m = messages[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!m.isRead) const StatusBadge('안 읽음', color: AppColors.accent),
                        Text(m.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          formatDateTime(m.sentAt, seconds: true),
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.accountName.isEmpty ? m.body : '${m.body} · ${m.accountName}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
