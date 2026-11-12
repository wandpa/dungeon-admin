part of 'member_monitor_page.dart';

// 앱 화면과 똑같이 보여 주는 조회 전용 위젯.
//   이력        job_timeline_page.dart, job_timeline_shared.dart
//   설정 보기   템플릿 페이지(readOnly), template_common_mixin.dart
//   워커 설정   worker_page.dart WorkerSettingsSheet, pnl_limit_section.dart
// 관리자가 앱과 헷갈리지 않게 순서·문구·표기를 앱 코드에 맞춘다. 스위치와 버튼은 눌리지 않는다.

const _indigo = Color(0xFF6366F1);

String _currencySymbol(String currency) => switch (currency) {
  'USD' => r'$',
  'HKD' => r'HK$',
  'EUR' => '€',
  _ => '₩',
};

/// 앱 formatPrice 표기. 예: $100.75, ₩98,400
String _appPrice(double v, String currency) => '${v < 0 ? '-' : ''}${_currencySymbol(currency)}${_num(v.abs())}';

/// 앱 이력의 금액. 원화가 아니면 소수 둘째 자리까지 쓴다.
String _money(double v, String currency) {
  final sign = v < 0 ? '-' : '';
  final text = currency == 'KRW' ? formatNumber(v.abs().round()) : formatNumber(num.parse(v.abs().toStringAsFixed(2)));
  final fixed = currency != 'KRW' && !text.contains('.')
      ? '$text.00'
      : (currency != 'KRW' && RegExp(r'\.\d$').hasMatch(text) ? '${text}0' : text);
  return '$sign${_currencySymbol(currency)}$fixed';
}

String _appSigned(double v, String currency) => '${v > 0 ? '+' : ''}${_appPrice(v, currency)}';

String _two(int v) => v.toString().padLeft(2, '0');

/// 앱 타임라인 시각: MM/dd HH:mm:ss
String _appTime(DateTime t) => '${_two(t.month)}/${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

Color _pnlColor(double v) => v > 0
    ? AppColors.up
    : v < 0
    ? AppColors.down
    : AppColors.textTertiary;

/// 앱 AppToggle 모양. 조회 전용이라 눌리지 않는다.
class _AppToggle extends StatelessWidget {
  const _AppToggle(this.value);

  final bool value;

  /// 읽기 전용이라 누를 수 없다. 비활성 스위치는 켜짐·꺼짐이 같은 회색이라 색을 직접 칠한다.
  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    child: Container(
      width: 36,
      height: 20,
      padding: const EdgeInsets.all(3),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: value ? AppColors.textPrimary : AppColors.control,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    ),
  );
}

/// 앱 워커 설정 머리줄의 작은 ON/OFF 표시.
class _SummaryOnOff extends StatelessWidget {
  const _SummaryOnOff(this.label, this.on);

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        const SizedBox(width: 6),
        Container(
          width: 46,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.brand : AppColors.border,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(on ? 'ON' : 'OFF', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ── 워커 설정 ──────────────────────────────────────────

class _WorkerSettings extends StatelessWidget {
  const _WorkerSettings(this.worker);

  final MemberWorker worker;

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final limit = w.pnlLimit;
    final alertOnly = w.jobs.isNotEmpty && w.jobs.every((j) => j.isAlert);
    const small = TextStyle(color: AppColors.textTertiary, fontSize: 12);
    const strong = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: alertOnly
              ? const Text('알람 모드', style: small)
              : Wrap(
                  spacing: 12,
                  children: [_SummaryOnOff('장마감 청산', w.autoCloseOnMarketEnd), _SummaryOnOff('누적 손익', limit != null)],
                ),
        ),
        const SizedBox(height: 10),
        if (alertOnly)
          const Text('알람 모드에서는 주문을 내지 않아\n장 마감 자동 청산과 누적 손익 관리를 쓰지 않습니다.', style: small)
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('장 마감 시 자동 청산', style: strong),
                    SizedBox(height: 4),
                    Text('국내주식 15:25 · 해외선물 장 종료 2분 전에 시장가로 청산합니다.\n그 시각 이후로는 진입·청산 판정을 하지 않습니다.', style: small),
                  ],
                ),
              ),
              _AppToggle(w.autoCloseOnMarketEnd),
            ],
          ),
          if (w.resumeOnMarketOpen != null) ...[
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('장 시작 시 다시 실행', style: strong),
                      SizedBox(height: 4),
                      Text('장 마감으로 멈춘 워커를 다음 장이 열리면 다시 실행합니다.', style: small),
                    ],
                  ),
                ),
                _AppToggle(w.resumeOnMarketOpen!),
              ],
            ),
          ],
          if (w.stopAfterCycle != null) ...[
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('이번 회차 후 정지', style: strong),
                      const SizedBox(height: 4),
                      Text(
                        w.stopAfterCycle! && w.stopAfterCycleAt != null
                            ? '${formatDateTime(w.stopAfterCycleAt!)}에 켰습니다. 진행 중 회차가 끝나면 워커를 멈춥니다.'
                            : '진행 중 회차가 끝나면 워커를 멈춥니다.',
                        style: small,
                      ),
                    ],
                  ),
                ),
                _AppToggle(w.stopAfterCycle!),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('누적 손익으로 워커 종료', style: strong),
                    SizedBox(height: 4),
                    Text('실현 누적 손익에 보유 평가손익을 더해 기준에 닿으면, 보유를 청산하고 워커를 종료합니다.', style: small),
                  ],
                ),
              ),
              _AppToggle(limit != null),
            ],
          ),
          if (limit != null) _PnlLimitBody(w, limit),
        ],
      ],
    );
  }
}

/// 앱 PnlLimitSection 의 켜져 있을 때 내용.
class _PnlLimitBody extends StatelessWidget {
  const _PnlLimitBody(this.worker, this.limit);

  final MemberWorker worker;
  final WorkerPnlLimit limit;

  String _ticks(double v) => '${v > 0 ? '+' : ''}${_num(v)}틱';

  /// 한도 값. 금액이면 $500, 500원, 틱이면 500틱.
  String _limitText(double v) {
    if (limit.isTick) return '${_num(v)}틱';
    return worker.currency == 'KRW' ? '${_num(v)}원' : '${_currencySymbol(worker.currency)}${_num(v)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = limit;
    final ccy = worker.currency;
    final unreal = worker.unrealizedPnl;
    final hasPosition = worker.jobs.any((j) => j.position != null);
    final main = l.isTick ? _ticks(l.accumTicks) : _appSigned(l.accumAmount, ccy);
    final sub = l.isTick ? _appSigned(l.accumAmount, ccy) : _ticks(l.accumTicks);
    final current = l.isTick ? l.accumTicks : l.accumAmount;
    final meta = [
      if (l.periodStart != null) '${formatDateTime(l.periodStart!)}부터',
      if (l.accumCount > 0) '청산 ${l.accumCount}회',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [l.accumTitle, if (meta.isNotEmpty) meta].join(' · '),
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: main,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _pnlColor(current)),
                          ),
                          TextSpan(
                            text: '  ($sub)',
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (hasPosition && !l.isTick && worker.currentPrice != null)
                      Text(
                        '평가 포함 ${_appSigned(l.accumAmount + unreal, ccy)}  (평가 ${_appSigned(unreal, ccy)})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: current + unreal >= 0 ? AppColors.up : AppColors.down,
                        ),
                      ),
                  ],
                ),
              ),
              const OutlinedButton(onPressed: null, child: Text('0으로 초기화', style: TextStyle(fontSize: 12))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: null,
            child: Text('누적 손익 설정 변경', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              _summaryRow('초기화 주기', l.periodLabel, null, first: true),
              _summaryRow('기준 단위', l.isTick ? '틱' : '금액', null),
              _summaryRow(
                '청산 수익 종료',
                l.profitTarget == null ? null : '+${_limitText(l.profitTarget!)} 이상',
                AppColors.up,
              ),
              _summaryRow('청산 손실 종료', l.lossLimit == null ? null : '−${_limitText(l.lossLimit!)} 이하', AppColors.down),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l.isTick ? '틱은 실현손익 ÷ 1틱 가치입니다(계약 수까지 합친 틱).' : '금액은 이 종목 통화의 실현손익입니다(계약승수 반영).',
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String? value, Color? color, {bool first = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      border: first ? null : const Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value ?? '사용 안 함',
            textAlign: TextAlign.right,
            style: value == null
                ? const TextStyle(color: AppColors.textTertiary, fontSize: 13)
                : TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

// ── 설정 보기 ──────────────────────────────────────────

class _AppField extends StatelessWidget {
  const _AppField(this.label, this.child);

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _AppValue extends StatelessWidget {
  const _AppValue(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}

/// 앱 세그먼트 선택. 고른 값만 칠한다.
class _AppSegment extends StatelessWidget {
  const _AppSegment(this.options, this.selected);

  final List<String> options;
  final String selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: o == selected ? AppColors.brand : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: o == selected ? FontWeight.w500 : FontWeight.w500,
                    color: o == selected ? AppColors.textPrimary : AppColors.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 값이 정해진 항목은 앱처럼 세그먼트로, 나머지는 값 칸으로 그린다.
Widget _settingWidget(String key, String value) {
  const fixed = {
    '돌파기준': ['가격', '현재가 대비', '일봉시가 대비'],
    '평가 시점': ['실시간', '봉 완성 시'],
    '진입 방식': ['실시간', '봉 완성 시', '하이브리드'],
  };
  const directions = [
    ['양방향', '양봉만', '음봉만'],
    ['매수', '매도', '양방향'],
    ['갭상승', '갭하락'],
  ];
  final options = key == '거래 방향' ? directions.firstWhere((d) => d.contains(value)) : fixed[key];
  return options == null ? _AppValue(value) : _AppSegment(options, value);
}

/// 앱 잡 상세의 [이력]·[설정 보기] 버튼과 같은 이름의 칸 제목.
class _DetailTitle extends StatelessWidget {
  const _DetailTitle(this.icon, this.title, {this.note});

  final IconData icon;
  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.brand),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        if (note != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '· $note',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}

class _JobSettings extends StatelessWidget {
  const _JobSettings(this.job, this.worker);

  final WorkerJob job;
  final MemberWorker worker;

  @override
  Widget build(BuildContext context) {
    final s = job.strategy;
    final items = s.liveItems;
    const section = TextStyle(fontSize: 16, fontWeight: FontWeight.w500);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailTitle(Icons.visibility_outlined, '설정 보기', note: s.label),
        const SizedBox(height: 12),
        _AppField(
          '계좌',
          _AppValue(job.accountNumber == null ? _jobAccount(job) : '계좌 ${job.accountName} · ${job.accountNumber}'),
        ),
        const Text('진입설정', style: section),
        const SizedBox(height: 10),
        _AppField('전략 이름', _AppValue(s.liveName ?? job.name)),
        if (items != null) ...[for (final item in items) _liveItem(item)],
        if (items == null && !s.entrySettings.containsKey('거래 방향') && !job.isAlert && s.templateId != 'breakout')
          _AppField('거래 방향', _settingWidget('거래 방향', job.entrySideLabel)),
        for (final MapEntry(:key, :value) in s.entrySettings.entries) _AppField(key, _settingWidget(key, value)),
        if (s.entryMode != null) _AppField('진입 방식', _settingWidget('진입 방식', s.entryMode!)),
        if (s.conditions.isNotEmpty) ...[
          const _SectionTitle('신호 조건'),
          for (final MapEntry(key: group, value: all) in s.conditions.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  for (final (i, c) in all.indexed) Text(i == 0 ? c : 'AND $c', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
        ],
        if (items == null) ...[
          if (!job.isAlert) ...[
            _AppField('주문 유형', _AppSegment(const ['시장가', '지정가'], s.orderType)),
            _AppField('주문 수량', _AppValue('${_num(s.qty)}${worker.qtyUnit}')),
          ],
          _AppField('반복 횟수', _AppValue('${job.repeatCount} 회')),
        ],
        if (s.liveExitCards?.isNotEmpty ?? false) ...[
          const Divider(height: 24),
          for (final card in s.liveExitCards!) _liveItem(card),
        ],
        if (!job.isAlert) ...[
          const SizedBox(height: 4),
          const Text('청산설정', style: section),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _exitRow('익절', s.takeProfitPct, s.takeProfitUnit, signed: false, strategy: s),
                const Divider(height: 1),
                _exitRow('손절', s.stopLossPct, s.stopLossUnit, signed: true, strategy: s),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _AppToggle(items == null ? s.trailingStop != null : s.liveTrailingOn),
                          const SizedBox(width: 8),
                          const Text('트레일링 스탑', style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      if (items != null && s.stopLossPct != null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('손절과 함께 사용할 수 없습니다', style: TextStyle(color: AppColors.warning, fontSize: 12)),
                        ),
                      for (final MapEntry(:key, :value) in (s.trailingStop ?? const <String, String>{}).entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Text(key, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                              const Spacer(),
                              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        const Center(
          child: Text('읽기 전용 (모니터링 중)', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ),
      ],
    );
  }

  /// 앱 상세보기 항목 하나. 스위치 카드, 고르는 버튼, 값 칸 중 하나로 그린다.
  Widget _liveItem(LiveSetting item) {
    if (item.isToggle) {
      // 앱 카드처럼 켜져 있을 때만 카드 안 안내와 세부 항목이 나온다.
      final open = item.on! && (item.note != null || item.children.isNotEmpty);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(item.value, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _AppToggle(item.on!),
              ],
            ),
            if (open) ...[
              const Divider(height: 24),
              if (item.note != null) ...[
                Text(item.note!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),
              ],
              for (final child in item.children) _liveItem(child),
            ],
          ],
        ),
      );
    }
    final field = item.options.isEmpty ? _AppValue(item.value) : _AppSegment(item.options, item.value);
    return _AppField(
      item.label,
      item.note == null
          ? field
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 6),
                Text(item.note!, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ],
            ),
    );
  }

  /// 앱 ExitTickRow: [토글] 익절 값 단위. 손절은 음수로 보인다.
  Widget _exitRow(String label, double? value, String unit, {required bool signed, required JobStrategy strategy}) {
    final size = strategy.tickSize;
    final tickValue = strategy.tickValue;
    final shown = signed ? -(value ?? 0) : (value ?? 0);
    String point(double v) => num.parse(v.toStringAsFixed(6)).toString();
    // 앱 환산 줄: "30tick / 0.3point / 30.00$"
    final convert = value == null || value == 0 || size == null || tickValue == null || unit != '틱'
        ? null
        : '${_num(shown)}tick / ${point(shown * size)}point / ${(shown * tickValue).toStringAsFixed(2)}\$';
    final unitLabel = switch (unit) {
      '틱' => 'Tick',
      '포인트' => 'Point',
      _ => unit,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _AppToggle(value != null),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              if (value != null) ...[
                Text('${signed ? '-' : ''}${_num(value)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                Text(unitLabel, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              ],
            ],
          ),
          if (convert != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(convert, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

// ── 이력 ───────────────────────────────────────────────

enum _EventGroup {
  job('잡', AppColors.textTertiary),
  entry('진입', AppColors.accent),
  exit('청산', AppColors.up);

  const _EventGroup(this.label, this.color);
  final String label;
  final Color color;
}

class _TimelineEvent {
  const _TimelineEvent(this.event, this.group);
  final JobEvent event;
  final _EventGroup group;
}

/// 앱 이력 화면: 회차 카드 → 진입/청산/잡 범례 → 시간순 세로 타임라인.
class _JobHistory extends StatelessWidget {
  const _JobHistory(this.job, this.worker);

  final WorkerJob job;
  final MemberWorker worker;

  /// 앱 서버가 이력으로 내려주는 종류. 신호·접수·잔고·회차 종료는 앱에 나오지 않는다.
  static const _shownEvents = {
    'job_started',
    'job_closed_complete',
    'job_closed_by_user',
    'close_keep_position',
    'order_submitted',
    'fill',
    'order_rejected',
    'order_cancelled',
    'sold_elsewhere',
    'alert_signal',
  };

  /// 시각이 같으면 앱과 같은 순서로 놓는다.
  static int _rank(String type) => switch (type) {
    'job_started' => -1,
    'order_submitted' => 1,
    'job_closed_complete' || 'job_closed_by_user' || 'close_keep_position' => 6,
    _ => 3,
  };

  /// 샘플은 체결 전을 진입, 체결 뒤를 청산으로 본다. 테스트 DB 는 서버가 준 group 을 쓴다.
  List<_TimelineEvent> get _events {
    final list = <_TimelineEvent>[];
    for (final c in job.cycles) {
      var filled = false;
      for (final e in c.events) {
        final server = e.group;
        if (server != null) {
          if (!_shownEvents.contains(e.type)) continue;
          list.add(
            _TimelineEvent(e, switch (server) {
              'entry' => _EventGroup.entry,
              'exit' => _EventGroup.exit,
              _ => _EventGroup.job,
            }),
          );
          continue;
        }
        final group = switch (e.type) {
          'cycle_closed' || 'sold_elsewhere' => _EventGroup.job,
          _ => filled ? _EventGroup.exit : _EventGroup.entry,
        };
        list.add(_TimelineEvent(e, group));
        if (e.type == 'fill') filled = true;
      }
    }
    int byTime(_TimelineEvent a, _TimelineEvent b) {
      final order = a.event.at.compareTo(b.event.at);
      return order != 0 ? order : _rank(a.event.type).compareTo(_rank(b.event.type));
    }

    return list..sort(byTime);
  }

  /// 앱과 같은 문장: "진입 매도 주문 전송  1계약", "청산 매수 체결  1계약 @$95.95".
  String? _liveLabel(JobEvent e) {
    final group = e.group;
    if (group == null) return null;
    final phase = group == 'exit' ? '청산' : '진입';
    final qty = e.qty == null ? '' : '  ${_num(e.qty!)}${worker.qtyUnit}';
    final at = e.price == null ? '' : ' @${_money(e.price!, worker.currency)}';
    return switch (e.type) {
      'job_started' => '잡 감시 시작',
      'job_closed_complete' || 'job_closed_by_user' || 'close_keep_position' => '잡 감시 종료',
      'order_submitted' => '$phase ${e.sideLabel} 주문 전송$qty',
      'fill' => '$phase ${e.sideLabel} 체결$qty$at',
      _ => null,
    };
  }

  /// 앱은 서버 문구를 쓴다. 메시지는 거부 사유처럼 문장에 없는 것만 보여 준다.
  String _label(JobEvent e) {
    final live = _liveLabel(e);
    if (live != null) return live;
    final unit = worker.qtyUnit;
    final side = e.sideLabel;
    final qty = e.qty == null ? '' : '${_num(e.qty!)}$unit';
    final at = e.price == null ? '' : ' @${_appPrice(e.price!, worker.currency)}';
    return switch (e.type) {
      'alert_fired' => '$side 신호 발생${qty.isEmpty ? '' : ' · $qty'}${e.message == null ? '' : ' · ${e.message}'}',
      'order_submitted' => '$side주문${qty.isEmpty ? '' : ' $qty'}$at',
      'order_accepted' => e.message == null ? '접수됨' : '접수됨 · 주문번호 ${e.message}',
      'fill' => '체결${qty.isEmpty ? '' : ' $qty'}$at',
      'order_rejected' => '${side.isEmpty ? '주문' : side} 거부${e.message == null ? '' : ' · ${e.message}'}',
      'order_cancelled' => '주문 취소',
      'cycle_closed' => '사이클 종료',
      'sold_elsewhere' => '타 매체 매도됨',
      _ => liveLogText(e.type),
    };
  }

  Widget _row(_TimelineEvent t, {required bool last}) {
    final e = t.event;
    final showMessage = e.group == null && e.message != null && e.type != 'alert_fired' && e.type != 'order_rejected';
    final reason = _exitLabel(e.exitReason);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: t.group.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 3),
                  ),
                ),
                Expanded(child: Container(width: 2, color: last ? Colors.transparent : AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(_label(e), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      if (reason != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (reason == '손절' ? AppColors.down : AppColors.up).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            reason,
                            style: TextStyle(
                              color: reason == '손절' ? AppColors.down : AppColors.up,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [_appTime(e.at), if (showMessage) e.message!].join(' · '),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DetailTitle(Icons.timeline, '이력'),
        const SizedBox(height: 12),
        // 회차 밖 이벤트(잡 감시 시작 등)는 카드 없이 타임라인에만 나온다.
        for (final c in job.cycles)
          if (c.cycleNo != 0) _CycleCard(c, worker, label: _label),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Text('아직 이력이 없어요', style: TextStyle(fontWeight: FontWeight.w500)),
                  SizedBox(height: 4),
                  Text('주문·체결이 생기면 여기에 시간순으로 쌓입니다', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Wrap(
              spacing: 16,
              children: [
                for (final g in _EventGroup.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: g.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        g.label,
                        style: TextStyle(color: g.color, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          for (final (i, t) in events.indexed) _row(t, last: i == events.length - 1),
        ],
      ],
    );
  }
}

/// 앱 회차 카드: N회차 · 상태 · 실현손익, 그 아래 전략 스냅샷.
class _CycleCard extends StatefulWidget {
  const _CycleCard(this.cycle, this.worker, {required this.label});

  final JobCycle cycle;
  final MemberWorker worker;
  final String Function(JobEvent) label;

  @override
  State<_CycleCard> createState() => _CycleCardState();
}

class _CycleCardState extends State<_CycleCard> {
  bool _open = false; // 이 회차의 상세 로그를 펼쳤는지

  JobCycle get cycle => widget.cycle;
  MemberWorker get worker => widget.worker;

  /// 시각이 같으면 신호, 주문, 접수, 체결, 잔고, 회차 종료 순서로 놓는다.
  static int _order(String type) => switch (type) {
    'alert_fired' => 0,
    'order_submitted' => 1,
    'order_accepted' => 2,
    'fill' => 3,
    'balance_updated' => 4,
    'cycle_closed' || 'cycle_canceled' => 5,
    _ => 3,
  };

  /// 신호 문구에는 사유가 이미 들어 있어 겹치지 않게 한다.
  String _logLine(JobEvent e) {
    final label = widget.label(e);
    final reason = _exitLabel(e.exitReason);
    return reason == null || label.contains(reason) ? label : '$label · $reason';
  }

  /// 앱 이력에 나오지 않는 신호·접수·잔고·회차 종료까지 이 회차의 모든 기록을 보여 준다.
  Widget _log() {
    final events = [...cycle.events]
      ..sort((a, b) {
        final byTime = a.at.compareTo(b.at);
        return byTime != 0 ? byTime : _order(a.type).compareTo(_order(b.type));
      });
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.grid)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${cycle.cycleNo}회차 상세 로그 ${events.length}건',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          if (events.isEmpty)
            const Text('기록이 없습니다.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12))
          else
            for (final e in events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(_appTime(e.at), style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    ),
                    Expanded(child: Text(_logLine(e), style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// 앱 회차 카드: 주문 수량(방향 색)과 보유시간.
  List<Widget> _liveRows(JobCycle c) {
    final short = c.side == 'short';
    final qty = (short ? c.filledSellQty : c.filledBuyQty) ?? c.filledBuyQty ?? c.filledSellQty;
    // 보유는 첫 체결부터다. 체결 기록이 없으면 회차 시작 시각을 쓴다.
    final open = c.events.where((e) => e.type == 'fill').firstOrNull?.at ?? c.openedAt;
    final close = c.closedAt;
    String time(DateTime t) => formatDateTime(t, seconds: true);
    final sameDay = open != null && close != null && time(open).substring(0, 10) == time(close).substring(0, 10);
    final held = open == null
        ? '-'
        : '${time(open)} ~ ${close == null ? '' : (sameDay ? time(close).substring(11) : time(close))}';
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('주문 수량', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                children: [
                  TextSpan(
                    text: short ? '매도 ' : '매수 ',
                    style: TextStyle(color: short ? AppColors.down : AppColors.up),
                  ),
                  TextSpan(text: qty == null ? '-' : '${_num(qty)}${worker.qtyUnit}'),
                ],
              ),
            ),
          ],
        ),
      ),
      _kv('보유시간', held),
    ];
  }

  Widget _kv(String key, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(key, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        const SizedBox(width: 12),
        // 날짜를 넘긴 보유시간처럼 길면 줄을 바꾼다.
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = cycle;
    final s = c.strategy;
    final pnl = c.realizedPnl ?? 0;
    final statusColor = switch (c.status) {
      'open' => AppColors.success,
      'closed' => AppColors.down,
      _ => AppColors.textTertiary,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _indigo.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${c.cycleNo}회차',
                  style: const TextStyle(color: _indigo, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                c.statusLabel,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (c.status != 'open' && c.cycleNo != 0)
                Text(
                  '실현손익 ${pnl > 0 ? '+' : ''}${_money(pnl, worker.currency)}',
                  style: TextStyle(color: _pnlColor(pnl), fontSize: 13, fontWeight: FontWeight.w500),
                ),
              const SizedBox(width: 4),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 26),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setState(() => _open = !_open),
                child: Text(_open ? '접기' : '상세'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (c.side != null)
            ..._liveRows(c)
          else if (s == null && c.cycleNo != 0)
            const Text('설정 정보 없음', style: TextStyle(color: AppColors.textTertiary, fontSize: 13))
          else if (s != null) ...[
            _kv('전략', s.label),
            _kv('주문 수량', '${_num(s.qty)}${worker.qtyUnit}'),
            if (s.stopLossPct != null) _kv('손절', '${_num(s.stopLossPct!)}${s.stopLossUnit}'),
            if (s.takeProfitPct != null) _kv('청산(익절)', '${_num(s.takeProfitPct!)}${s.takeProfitUnit}'),
          ],
          if (_open) _log(),
        ],
      ),
    );
  }
}

String? _exitLabel(String? reason) => liveExitLabel(reason);

/// 앱 잡 시트의 체결 내역에 건수 요약을 더한 것. 한 줄이 한 회차다.
class _JobFills extends StatelessWidget {
  const _JobFills(this.job, this.worker);

  final WorkerJob job;
  final MemberWorker worker;

  @override
  Widget build(BuildContext context) {
    final events = job.cycles.expand((c) => c.events).toList();
    int count(String type) => events.where((e) => e.type == type).length;
    final rows = job.cycles.where((c) => c.events.any((e) => e.type == 'fill')).toList()
      ..sort((a, b) => b.cycleNo.compareTo(a.cycleNo));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('체결 내역', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('실현 손익', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            Text(
              _appSigned(job.realizedPnl, worker.currency),
              style: TextStyle(color: _pnlColor(job.realizedPnl), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '주문 ${count('order_submitted')}건 · 체결 ${count('fill')}건 · 거부 ${count('order_rejected')}건',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Text('아직 체결 내역이 없어요', style: TextStyle(color: AppColors.textTertiary, fontSize: 12))
        else
          for (final c in rows) _FillRow(c, job, worker),
      ],
    );
  }
}

/// 앱 체결 내역 한 줄: 방향, 종목, 계좌, 회차 손익과 청산 사유.
class _FillRow extends StatelessWidget {
  const _FillRow(this.cycle, this.job, this.worker);

  final JobCycle cycle;
  final WorkerJob job;
  final MemberWorker worker;

  /// 첫 체결이 진입, 마지막 체결이 청산이다. 초까지 보여 준다.
  String _times(bool open) {
    final fills = cycle.events.where((e) => e.type == 'fill').toList();
    final entry = '진입 ${_appTime(fills.first.at)}';
    return open || fills.length < 2 ? entry : '$entry · 청산 ${_appTime(fills.last.at)}';
  }

  /// 아직 체결되지 않은 쪽은 평균가가 비어 있거나 0 으로 온다.
  String _price(double? v) => v == null || v == 0 ? '-' : _appPrice(v, worker.currency);

  bool get _short {
    final side = cycle.side;
    if (side != null) return side == 'short';
    return cycle.events.firstWhere((e) => e.type == 'fill').side == 'sell';
  }

  @override
  Widget build(BuildContext context) {
    final open = cycle.status == 'open';
    final pnl = cycle.realizedPnl ?? 0;
    final exit = cycle.events.where((e) => e.exitReason != null).lastOrNull?.exitReason;
    final color = open ? AppColors.textPrimary : _pnlColor(pnl);
    final note = open ? '보유중' : _exitLabel(exit) ?? cycle.statusLabel;
    final noteColor = open || pnl < 0
        ? AppColors.down
        : pnl > 0
        ? AppColors.up
        : AppColors.textTertiary;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _short ? '매도' : '매수',
                style: TextStyle(
                  color: _short ? AppColors.down : AppColors.up,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${worker.symbolCode} ${worker.symbolName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      job.accountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    open ? '-' : '${pnl > 0 ? '+' : ''}${_num(pnl)}',
                    style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(note, style: TextStyle(color: noteColor, fontSize: 12)),
                ],
              ),
            ],
          ),
          // 가격과 시각은 잘리지 않게 줄 전체를 쓴다.
          const SizedBox(height: 2),
          Text(
            '매수가 ${_price(cycle.avgBuyPrice)} · 매도가 ${_price(cycle.avgSellPrice)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          Text(_times(open), style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}
