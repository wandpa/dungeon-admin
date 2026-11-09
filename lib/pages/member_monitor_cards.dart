part of 'member_monitor_page.dart';

/// 앱 칩 모양. 점과 글자에 같은 색을 쓴다.
class _AppPill extends StatelessWidget {
  const _AppPill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// 카드가 워커인지 잡인지 한눈에 보이게 하는 둥근 표시.
class _KindBadge extends StatelessWidget {
  const _KindBadge.worker() : label = '워커', color = AppColors.brand, ink = Colors.white;
  const _KindBadge.job() : label = '잡', color = AppColors.accent, ink = Colors.white;

  final String label;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// 앱 실행 슬롯. 워커가 돌고 잡이 담겨 있을 때만 초록색이고, 비어 있으면 이유를 보여 준다.
class _RunSlot extends StatelessWidget {
  const _RunSlot({required this.workerRunning, required this.children});

  final bool workerRunning;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final live = workerRunning && children.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      decoration: BoxDecoration(
        color: live ? AppColors.success.withValues(alpha: 0.06) : Colors.transparent,
        border: Border.all(color: live ? AppColors.success.withValues(alpha: 0.45) : AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.isNotEmpty
            ? children
            : [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                  child: Column(
                    children: [
                      Text(
                        workerRunning ? '실행 슬롯이 비어 있습니다' : '워커가 꺼져 있습니다',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        workerRunning ? '아래 전략의 스위치를 켜면 맨 위 것부터 이 자리로 올라옵니다' : '켜면 대기열 맨 위 전략이 슬롯에 올라가 감시를 시작합니다',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
      ),
    );
  }
}

/// 앱 잡 화면 맨 위의 워커 카드. 워커 상태, 누적 손익, 지금 물고 있는 잡을 한 카드에 담는다.
class _WorkerSlotCard extends StatelessWidget {
  const _WorkerSlotCard(this.worker, {required this.slot});

  final MemberWorker worker;
  final Widget slot;

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final running = w.status == WorkerStatus.running;
    final color = switch (w.status) {
      WorkerStatus.running => AppColors.success,
      WorkerStatus.stopped => AppColors.textSecondary,
      WorkerStatus.error => AppColors.up,
    };
    final limit = w.pnlLimit;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border.all(color: running ? AppColors.success.withValues(alpha: 0.45) : AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy_outlined, size: 20, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _KindBadge.worker(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            w.symbolName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    Text(w.symbolCode, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.power_settings_new, size: 16, color: color),
                    const SizedBox(width: 4),
                    Text(
                      w.status.label,
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (limit != null) ...[_PnlLimitLine(w, limit), const SizedBox(height: 8)],
          if (limit?.stoppedAt != null) ...[_LimitEndBanner(w, limit!), const SizedBox(height: 8)],
          slot,
        ],
      ),
    );
  }
}

/// 앱 워커 카드의 누적 손익 줄. 시세가 없으면 평가 합계는 만들지 않는다.
class _PnlLimitLine extends StatelessWidget {
  const _PnlLimitLine(this.worker, this.limit);

  final MemberWorker worker;
  final WorkerPnlLimit limit;

  String _fmt(double v) => limit.isTick ? '${v > 0 ? '+' : ''}${_num(v)}틱' : _appSigned(v, worker.currency);

  @override
  Widget build(BuildContext context) {
    final l = limit;
    final bounds = [
      if (l.profitTarget != null) '목표 ${_fmt(l.profitTarget!)}',
      if (l.lossLimit != null) '한도 ${_fmt(-l.lossLimit!)}',
    ].join(' · ');
    final realized = l.isTick ? l.accumTicks : l.accumAmount;
    final held = worker.jobs.any((j) => j.position != null);
    final unreal = held && worker.currentPrice != null && !l.isTick ? worker.unrealizedPnl : null;
    final value = realized + (unreal ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bounds.isEmpty ? l.accumTitle : '${l.accumTitle} ($bounds)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmt(value),
                style: TextStyle(color: _pnlColor(value), fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (unreal != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '평가 포함 · 실현 ${_fmt(realized)} + 평가 ${_fmt(unreal)}',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

/// 앱 한도 종료 띠: "손절 종료 · 매매 8회 · 총 청산손익 -$818".
/// 사유로 익절·손절을 가르고, 사유가 없을 때만 손익 부호로 본다.
class _LimitEndBanner extends StatelessWidget {
  const _LimitEndBanner(this.worker, this.limit);

  final MemberWorker worker;
  final WorkerPnlLimit limit;

  @override
  Widget build(BuildContext context) {
    final l = limit;
    final reason = (l.stopReason ?? '').toLowerCase();
    final realized = l.isTick ? l.accumTicks : l.accumAmount;
    final profit = reason.contains('목표') || reason.contains('profit')
        ? true
        : reason.contains('한도') || reason.contains('loss')
        ? false
        : realized >= 0;
    final total = l.isTick ? '${realized > 0 ? '+' : ''}${_num(realized)}틱' : _appSigned(realized, worker.currency);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${profit ? '익절' : '손절'} 종료 · 매매 ${l.accumCount}회 · 총 청산손익 $total',
        style: const TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 앱 대기열 머리줄. 관리자는 조회만 하므로 잡 선택·잡 추가 버튼은 없다.
class _QueueHeader extends StatelessWidget {
  const _QueueHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(2, 8, 0, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '대기열',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          Text('완료 시 다음 잡 자동 시작', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}

/// 앱 워커 카드와 같은 모양. 위 띠에 계좌와 누적 손익, 아래에 종목과 지금 도는 잡을 보여 준다.
class _WorkerCard extends StatelessWidget {
  const _WorkerCard(this.worker, {required this.selected, required this.onTap});

  final MemberWorker worker;
  final bool selected;
  final VoidCallback onTap;

  List<WorkerJob> get _open => worker.jobs.where((j) => !j.isFinished).toList();

  /// 카드에 보여 줄 잡. 보유가 있는 잡을 먼저 고른다.
  WorkerJob? get _live {
    final open = _open;
    final running = open.where((j) => j.slot == JobSlot.running).toList();
    for (final j in [...running, ...open]) {
      if (j.position != null) return j;
    }
    return running.firstOrNull ?? open.firstOrNull;
  }

  String get _account {
    final live = _live;
    final names = {
      if (live != null) live.accountLabel,
      for (final j in _open.isEmpty ? worker.jobs : _open) j.accountLabel,
    }.toList();
    if (names.isEmpty) names.addAll(worker.accountLabels); // 잡이 없는 워커
    if (names.isEmpty) return '[계좌 없음]';
    return names.length == 1 ? '[계좌 ${names.first}]' : '[계좌 ${names.first} 외 ${names.length - 1}]';
  }

  String? get _accumulated {
    final limit = worker.pnlLimit;
    if (limit == null) return null;
    if (limit.isTick) return '누적 ${limit.accumTicks > 0 ? '+' : ''}${_num(limit.accumTicks)}틱';
    return '누적 ${_appSigned(limit.accumAmount, worker.currency)}';
  }

  /// 앱 카드의 둘째 줄: 회차 · 방향 수량 · 틱 금액. 관리자용으로 실현 손익과 잡 수를 덧붙인다.
  List<InlineSpan> _line() {
    final w = worker;
    final job = _live;
    final p = job?.position;
    final parts = <List<InlineSpan>>[];
    if (job != null && job.repeatCount > 1) {
      parts.add([TextSpan(text: '${job.repeatCurrent}/${job.repeatCount}회차')]);
    }
    if (p == null) {
      parts.add([const TextSpan(text: '보유 없음')]);
    } else {
      final short = p.side == 'short';
      parts.add([
        TextSpan(
          text: p.sideLabel,
          style: TextStyle(color: short ? AppColors.down : AppColors.up, fontWeight: FontWeight.w700),
        ),
        TextSpan(text: ' ${_num(p.size)}${w.qtyUnit}'),
      ]);
      final pnl = p.pnlAt(w.currentPrice);
      if (pnl != null) {
        final tick = tickSizeOf(w.symbolCode);
        final ticks = tick == null ? null : (w.currentPrice! - p.entryPrice) * (short ? -1 : 1) / tick;
        final tickText = ticks == null ? '' : '${ticks > 0 ? '+' : ''}${_num(ticks)}T ';
        parts.add([
          TextSpan(
            text: '$tickText${_appSigned(pnl, w.currency)}',
            style: TextStyle(color: _pnlColor(pnl), fontWeight: FontWeight.w700),
          ),
        ]);
      }
      final others = _open.where((j) => j.position != null).length - 1;
      if (others > 0) parts.add([TextSpan(text: '외 보유 $others건')]);
    }
    if (w.realizedPnl != 0) {
      parts.add([
        const TextSpan(text: '실현 '),
        TextSpan(
          text: _appSigned(w.realizedPnl, w.currency),
          style: TextStyle(color: _pnlColor(w.realizedPnl), fontWeight: FontWeight.w700),
        ),
      ]);
    }
    parts.add([TextSpan(text: '잡 ${_open.length}개')]);
    return [
      for (final (i, part) in parts.indexed) ...[if (i > 0) const TextSpan(text: ' · '), ...part],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final running = w.status == WorkerStatus.running;
    final kind = w.jobs.isEmpty && w.kind == null ? null : w.kindKey;
    final accumulated = _accumulated;
    final borderColor = selected
        ? AppColors.brand
        : running
        ? AppColors.success.withValues(alpha: 0.5)
        : w.status == WorkerStatus.error
        ? AppColors.up.withValues(alpha: 0.6)
        : AppColors.border;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceSoft,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.brand.withValues(alpha: 0.18),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _account,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (accumulated != null)
                      Text(
                        accumulated,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const _KindBadge.worker(),
                              Text(w.symbolCode, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                              Text(w.symbolName, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                              if (kind == 'alert') const StatusBadge('알람', color: AppColors.warning),
                              if (kind == 'paper') const StatusBadge('모의', color: AppColors.down),
                              if (w.kind == 'real') const StatusBadge('실전', color: AppColors.success),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              children: _line(),
                            ),
                          ),
                          if (w.pnlLimit?.stoppedAt != null) ...[
                            const SizedBox(height: 6),
                            _LimitEndBanner(w, w.pnlLimit!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _AppToggle(running),
                        Text(
                          w.status.label,
                          style: TextStyle(
                            color: _workerStatusColor(w.status),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 앱 잡 카드와 같은 모양. 누르면 잡 내역으로 넘어간다.
class _JobCard extends StatelessWidget {
  const _JobCard(this.job, this.worker, {required this.selected, required this.onTap});

  final WorkerJob job;
  final MemberWorker worker;
  final bool selected;
  final VoidCallback onTap;

  /// 앱 전략 템플릿 아이콘과 같다.
  IconData get _icon => _jobIcon(job);

  String get _direction => job.entrySide == 'both'
      ? '양방향'
      : job.isShort
      ? '숏'
      : '롱';

  /// 돌고 있는 잡은 앱에서 삭제 버튼이고, 그 외에는 켜기/끄기 스위치다.
  bool get _running => job.isActive && const {'monitoring', 'submitted', 'bought', 'sent'}.contains(job.status);

  Widget _metric(String label, String value, {Color? color, int flex = 1}) => Expanded(
    flex: flex,
    child: Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  String _pnlText(double? pnl, double? pct) {
    if (pnl == null) return '-';
    final rate = pct == null ? '' : ' (${pct > 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)';
    return '${_appSigned(pnl, worker.currency)}$rate';
  }

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final p = job.position;
    final held = p != null && p.size != 0;
    final pnl = p?.pnlAt(w.currentPrice);
    final cost = p == null ? 0.0 : p.entryPrice * p.size * p.multiplier;
    final pct = pnl == null || cost <= 0 ? null : pnl / cost * 100;
    final realized = job.isAlert ? 0.0 : job.realizedPnl;
    final iconColor = job.isActive ? AppColors.down : AppColors.textTertiary;
    final repeat = job.repeatCount > 1 ? '${job.repeatCurrent}/${job.repeatCount} 회차' : null;
    const muted = AppColors.textTertiary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.brand.withValues(alpha: 0.18) : AppColors.surfaceSoft,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.brand : AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_icon, size: 24, color: iconColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const _KindBadge.job(),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    job.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (job.isAlert) const _AppPill('알람', AppColors.accent),
                                // 앱과 같이 대기열·종료 잡만 상태를 쓴다. 도는 잡의 진행 단계는 잡 내역에 있다.
                                if (job.slot == JobSlot.queued)
                                  const _AppPill('대기열', AppColors.warning)
                                else if (job.isFinished)
                                  _AppPill(job.statusLabel, _jobStatusColor(job)),
                                _AppPill(_direction, muted),
                                if (repeat != null) _AppPill(repeat, muted),
                                _AppPill(_jobAccount(job), muted),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!job.isFinished) ...[
                        const SizedBox(width: 8),
                        // 앱의 조작 자리. 관리자는 조회만 하므로 눌리지 않는다.
                        if (_running)
                          SizedBox(
                            width: 58,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                disabledForegroundColor: AppColors.up.withValues(alpha: 0.7),
                                disabledBackgroundColor: AppColors.up.withValues(alpha: 0.06),
                                side: BorderSide(color: AppColors.up.withValues(alpha: 0.4)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: null,
                              child: const Text('삭제', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          )
                        else
                          Center(child: _AppToggle(job.isActive)),
                      ],
                    ],
                  ),
                ),
              ),
              if (held || realized != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (held) ...[
                        _metric('진입가', _num(p.entryPrice), flex: 3),
                        _metric(
                          p.side == 'short'
                              ? '매도 수량'
                              : p.side == 'long'
                              ? '매수 수량'
                              : '보유 수량',
                          _num(p.size),
                          color: p.side == 'short' ? AppColors.down : null,
                          flex: 2,
                        ),
                        _metric('평가손익', _pnlText(pnl, pct), color: pnl == null ? null : _pnlColor(pnl), flex: 4),
                      ],
                      // 앱 카드에는 없다. 상담할 때 잡별 손익을 바로 보려고 더했다.
                      if (realized != 0)
                        _metric('실현손익', _appSigned(realized, w.currency), color: _pnlColor(realized), flex: 3),
                    ],
                  ),
                ),
              if (job.isFinished)
                for (final r in job.rejectReasons)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Text(r, style: const TextStyle(color: AppColors.up, fontSize: 12)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 앱 job_template_sheet 의 전략 아이콘.
IconData _jobIcon(WorkerJob job) => switch (job.strategy.templateId) {
  'breakout' => Icons.north_east,
  'candle_direction_breakout' => Icons.candlestick_chart_outlined,
  'gap_trading_breakout' => Icons.unfold_more,
  'first_fill_breakout' => Icons.arrow_upward,
  'trailing_entry' => Icons.show_chart,
  'indicator_combination' => Icons.insights,
  _ => Icons.smart_toy_outlined,
};

/// 앱 종료된 전략 카드: 아이콘, 전략 이름, 종료 칩 + "1계약 · 롱 · 캔들 방향", 복원·삭제.
class _FinishedJobCard extends StatelessWidget {
  const _FinishedJobCard(this.job, this.worker, {required this.selected, required this.onTap});

  final WorkerJob job;
  final MemberWorker worker;
  final bool selected;
  final VoidCallback onTap;

  Color get _endColor => switch (job.endReason) {
    'completed' => AppColors.brand,
    'user_close' => AppColors.warning,
    'failed' || 'abnormal' => AppColors.up,
    null => _jobStatusColor(job),
    _ => AppColors.textTertiary,
  };

  @override
  Widget build(BuildContext context) {
    final meta = [
      '${_num(job.strategy.qty)}${worker.qtyUnit}',
      job.isShort ? '숏' : '롱',
      if (job.strategy.templateId.isNotEmpty) job.strategy.label,
    ].join(' · ');
    const action = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.brand.withValues(alpha: 0.18) : AppColors.surfaceSoft,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.brand : AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                      child: Icon(_jobIcon(job), size: 24, color: AppColors.textTertiary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const _KindBadge.job(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  job.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _AppPill(job.endLabel, _endColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 앱의 조작 자리. 관리자는 조회만 하므로 눌리지 않는다.
                    Text('복원', style: action.copyWith(color: AppColors.textTertiary)),
                    const SizedBox(width: 12),
                    Text('삭제', style: action.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
                for (final r in job.rejectReasons)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
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

/// 앱 위쪽의 트레이드 / 종료된 전략 전환.
class _JobTabs extends StatelessWidget {
  const _JobTabs({required this.finished, required this.onChanged});

  final bool finished;
  final ValueChanged<bool> onChanged;

  Widget _tab(String label, bool value) {
    final selected = finished == value;
    return Expanded(
      child: Material(
        color: selected ? AppColors.brand.withValues(alpha: 0.25) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? AppColors.brand : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [_tab('트레이드', false), _tab('종료된 전략', true)]),
    );
  }
}

/// 앱 종료된 전략의 일괄 버튼 자리. 관리자는 조회만 하므로 눌리지 않는다.
class _FinishedActions extends StatelessWidget {
  const _FinishedActions();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w700);
    return const Padding(
      padding: EdgeInsets.fromLTRB(2, 2, 2, 10),
      child: Row(
        children: [
          Text('전체복원', style: style),
          SizedBox(width: 16),
          Text('선택복원', style: style),
          Spacer(),
          Text('전체삭제', style: style),
          SizedBox(width: 16),
          Text('선택삭제', style: style),
        ],
      ),
    );
  }
}
