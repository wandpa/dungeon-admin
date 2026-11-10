/// 테스트 DB 잡의 templateParams 를 앱 "상세보기" 화면과 같은 항목으로 바꾼다.
/// 항목 이름과 순서는 dungeon-app 의 전략 템플릿 화면을 따른다.
library;

import 'mock_workers.dart';

String _number(Object? v) {
  if (v is! num) return '-';
  return v == v.roundToDouble() ? '${v.round()}' : '$v';
}

String _timeframe(Object? v) {
  // 옛 잡은 ["minute", 1, 100] / ["day", 1, 100] 꼴로 저장돼 있다.
  if (v is List && v.length >= 2) return v[0] == 'day' ? '일봉' : '${v[1]}분';
  final text = '${v ?? ''}';
  if (text.isEmpty || text == '1t') return '실시간';
  final minutes = RegExp(r'^(\d+)m$').firstMatch(text);
  return minutes == null ? text : '${minutes.group(1)}분';
}

/// 앱 틱 환산 줄: "20tick / 0.2point / 20.00$". 틱 크기·틱 가치를 모르면 없다.
String? _tickLine(Object? v, (double, double)? tick) {
  if (v is! num || v == 0 || tick == null) return null;
  final point = num.parse((v * tick.$1).toStringAsFixed(6));
  return '${_number(v)}tick / ${_number(point)}point / ${(v * tick.$2).toStringAsFixed(2)}\$';
}

String? _lines(List<String?> lines) {
  final kept = lines.whereType<String>().toList();
  return kept.isEmpty ? null : kept.join('\n');
}

const _hybridTitle = '첫 진입 후 최초가 돌파로 전환 ✦ 하이브리드';

/// 앱 하이브리드 카드. 켜져 있으면 카드 안에 안내와 돌파 감지 타임프레임이 나온다.
LiveSetting _hybrid(
  Map<String, dynamic> p, {
  required String first,
  required String note,
  bool needsRepeat = false,
}) {
  final repeat = p['repeat_count'];
  final allowed = !needsRepeat || (repeat is num && repeat >= 2);
  final tf = _timeframe(p['signal_timeframe']);
  return LiveSetting.toggle(
    _hybridTitle,
    allowed ? '1회차는 $first, 2회차부터 최초 체결가 돌파로 재진입' : '반복 횟수가 2회 이상일 때만 켤 수 있습니다',
    allowed && p['switch_to_first_entry_breakout'] == true,
    note: note,
    children: [
      LiveSetting.value(
        '돌파 감지 타임프레임',
        tf,
        note: tf == '실시간' ? '틱이 올 때마다 바로 판정합니다 (봉 마감을 안 기다립니다)' : '고른 봉이 마감될 때 판정합니다',
      ),
    ],
  );
}

const _directions = <String, List<(String, String, String)>>{
  'candle_direction_breakout': [
    ('both', '양방향', '직전봉이 양봉일 경우 매수, 음봉일 경우 매도합니다'),
    ('buy_only', '양봉만', '직전봉이 양봉일 경우에만 매수합니다'),
    ('sell_only', '음봉만', '직전봉이 음봉일 경우에만 매도합니다'),
  ],
  'gap_trading_breakout': [
    ('both', '양방향', '갭 상승 시 매수, 갭 하락 시 매도합니다'),
    ('gap_up_only', '갭상승', '갭 상승이 발생했을 경우에만 매수합니다'),
    ('gap_down_only', '갭하락', '갭 하락이 발생했을 경우에만 매도합니다'),
  ],
  'first_fill_breakout': [('buy', '매수', '조건 충족 시 매수 주문을 실행합니다'), ('sell', '매도', '조건 충족 시 매도 주문을 실행합니다')],
  'trailing_entry': [
    ('buy_only', '매수', '가격을 따라 내려가는 진입선을 위로 넘으면 매수합니다'),
    ('sell_only', '매도', '가격을 따라 올라가는 진입선을 아래로 넘으면 매도합니다'),
  ],
};

LiveSetting _direction(String templateId, Map<String, dynamic> p) {
  final options = _directions[templateId]!;
  final picked = options.where((o) => o.$1 == p['direction']).firstOrNull ?? options.first;
  return LiveSetting.segment('거래 방향', [for (final o in options) o.$2], picked.$2, note: picked.$3);
}

/// 앱 전략 화면의 항목. 주문 유형·수량·반복 횟수는 전략마다 놓이는 자리가 다르다.
List<LiveSetting> liveSettings({
  required String templateId,
  required Map<String, dynamic> params,
  required String marketType,
  required String qtyUnit,
  required bool isAlert,
  (double, double)? tick,
}) {
  final p = params;
  final domestic = marketType == '국내주식';
  final repeat = LiveSetting.value('반복 횟수', '${_number(p['repeat_count'] ?? 1)} 회');
  final orderType = [
    if (!isAlert) LiveSetting.segment('주문 유형', const ['시장가', '지정가'], p['order_type'] == 'limit' ? '지정가' : '시장가'),
    if (!isAlert && p['order_type'] == 'limit') LiveSetting.value('지정가 (진입)', '${_number(p['limit_price'])} 원'),
  ];
  final quantity = [
    if (!isAlert)
      qtyUnit == '주'
          ? LiveSetting.value('주문 금액', '${_number(p['entry_amount_manwon'] ?? 10)} 만원')
          : LiveSetting.value('주문 수량', '${_number(p['quantity'] ?? p['qty'] ?? 1)} $qtyUnit'),
  ];
  final timeframe = LiveSetting.value('신호 주기', _timeframe(p['signal_timeframe']));

  return switch (templateId) {
    'breakout' => [
      LiveSetting.segment(
        '돌파기준',
        const ['가격', '현재가 대비', '일봉시가 대비'],
        switch (p['breakout_basis']) {
          'current' => '현재가 대비',
          'dayopen' => '일봉시가 대비',
          _ => '가격',
        },
      ),
      LiveSetting.toggle('매수', _breakoutTarget(p, 'buy', domestic), p['buy_enabled'] != false),
      if (!isAlert || p['sell_enabled'] == true)
        LiveSetting.toggle('매도', _breakoutTarget(p, 'sell', domestic), p['sell_enabled'] == true),
      timeframe,
      ...orderType,
      ...quantity,
      repeat,
    ],
    'candle_direction_breakout' => [
      _direction(templateId, p),
      timeframe,
      ...orderType,
      ...quantity,
      LiveSetting.value('등락률', '${_number(p['min_change_pct'] ?? 0)} %', note: '양봉은 + 이상, 음봉은 − 이하일 때'),
      LiveSetting.toggle('양->음, 음->양 전환', '양봉 다음 음봉이면 매도, 음봉 다음 양봉이면 매수한다', p['use_prev2_candle'] == true),
      if (p.containsKey('candle_reverse_entry'))
        LiveSetting.toggle('반대진입', '양봉이면 매도, 음봉이면 매수한다', p['candle_reverse_entry'] == true),
      if (p.containsKey('use_bar_reentry'))
        LiveSetting.toggle(
          '봉 내 재진입',
          '청산된 뒤 같은 봉 안에서 가격이 직전 봉 종가를 다시 넘으면 같은 방향으로 다시 들어간다',
          p['use_bar_reentry'] == true,
          children: [LiveSetting.value('재진입 횟수', '${_number(p['bar_reentry_count'])} 회')],
        ),
      repeat,
    ],
    'first_fill_breakout' => [_direction(templateId, p), timeframe, ...orderType, ...quantity, repeat],
    'gap_trading_breakout' => [
      _direction(templateId, p),
      LiveSetting.value(
        '갭 크기',
        '${_number(p['gap_min_ticks'] ?? (domestic ? 3 : 5))} ${domestic ? '%' : '틱'}',
        note: _lines([
          if (!domestic) _tickLine(p['gap_min_ticks'] ?? 5, tick),
          domestic ? '전일 종가 대비 이 % 이상 벌어져야 갭으로 봅니다' : '전일 종가와 당일 시가의 차이가 이 값 이상이어야 갭으로 봅니다',
        ]),
      ),
      ...orderType,
      ...quantity,
      repeat,
      if (!isAlert)
        _hybrid(p, first: '갭으로 진입', note: '양방향은 1회차에 먼저 진입한 방향으로만 재진입합니다', needsRepeat: true),
    ],
    'trailing_entry' => [
      _direction(templateId, p),
      // 하이브리드가 생긴 뒤의 앱은 1회차를 늘 실시간으로 따라가고, 봉 주기는 돌파 감지에만 쓴다.
      if (!p.containsKey('switch_to_first_entry_breakout')) timeframe,
      ...orderType,
      ...quantity,
      _trailingStep(p, domestic, tick),
      repeat,
      if (!isAlert && p.containsKey('switch_to_first_entry_breakout'))
        _hybrid(
          p,
          first: '트레일링 진입',
          note: '끄면 회차마다 진입선을 새로 놓고(재무장) 다시 트레일링 합니다. 1회차 트레일링 진입은 늘 실시간입니다.',
        ),
    ],
    'indicator_combination' => [
      qtyUnit == '주' || domestic
          ? LiveSetting.value('주문 금액', '${_number(p['entry_amount_manwon'] ?? 10)} 만원')
          : LiveSetting.value('진입 수량', '${_number(p['quantity'] ?? p['qty'] ?? 1)} $qtyUnit'),
      repeat,
      ...orderType,
      if (!isAlert) ...[
        LiveSetting.toggle('첫 반복 시 즉시 진입', '1회차: 조건 없이 즉시 진입, 2회차~: 조건 평가 후 진입', p['immediate_first_entry'] == true),
        _hybrid(
          {...p, if (p['immediate_first_entry'] == true) 'switch_to_first_entry_breakout': false},
          first: '지표 조건으로 진입',
          note: '매수·매도를 둘 다 설정한 경우 먼저 진입하는 방향으로만 동작합니다',
        ),
      ],
    ],
    // 모르는 전략은 원본 이름 그대로 보여 준다.
    _ => [
      for (final MapEntry(:key, :value) in p.entries)
        if (value != null && value is! Map && value is! List) LiveSetting.value(key, '$value'),
    ],
  };
}

/// 트레일링 진입 간격. 아래에 틱 환산 줄과 진입선 안내가 붙는다.
LiveSetting _trailingStep(Map<String, dynamic> p, bool domestic, (double, double)? tick) {
  final unit = switch (p['trailing_entry_step_unit']) {
    'percent' || 'pct' || '%' => '%',
    'point' || 'pt' => 'pt',
    _ => domestic && p['trailing_entry_step_unit'] == null ? '%' : '틱',
  };
  final step = p['trailing_entry_step'];
  final sign = p['direction'] == 'sell_only' ? '−' : '+';
  return LiveSetting.value(
    '진입 간격',
    '${_number(step)} $unit',
    note: _lines([
      if (unit == '틱') _tickLine(step, tick),
      '진입선 = 현재가 $sign ${step is num ? _number(step) : 'N'}$unit · 트레일링 스탑처럼 끝없이 따라갑니다',
    ]),
  );
}

/// 돌파 전략의 매수·매도 값. 기준이 가격이면 돌파가격, 아니면 기준에서의 거리다.
String _breakoutTarget(Map<String, dynamic> p, String side, bool domestic) {
  final raw = p['${side}_target_set_price'] ?? p['${side}_target_price'];
  final unit = switch (p['breakout_offset_unit']) {
    'percent' => '%',
    'tick' => '틱',
    _ => domestic ? '%' : '틱',
  };
  final signed = raw is num && raw > 0 ? '+${_number(raw)}' : _number(raw);
  return switch (p['breakout_basis']) {
    'current' => '현재가 대비 $signed$unit',
    'dayopen' => '일봉시가 대비 $signed$unit',
    _ => '돌파가격 ${_number(raw)}',
  };
}

const _comparisons = {
  'crossover': '상향 돌파',
  'crossunder': '하향 돌파',
  'greater_than_or_equal': '이상',
  'less_than_or_equal': '이하',
  'greater_than': '초과',
  'less_than': '미만',
  'bull': '양봉',
  'bear': '음봉',
};

const _bbLines = {'upper': '상단선', 'middle': '중앙선', 'lower': '하단선'};

String _condition(Map<String, dynamic> p, String prefix) {
  final compare = _comparisons[p['${prefix}_comparison']] ?? '${p['${prefix}_comparison'] ?? ''}';
  final period = _number(p['${prefix}_period']);
  final value = _number(p['${prefix}_value']);
  return switch (p['${prefix}_type']) {
    'rsi' => 'RSI($period) $compare $value',
    'sma' => 'SMA($period) $compare',
    'bb' => 'BB($period, ${_number(p['${prefix}_mult'])}) ${_bbLines[p['${prefix}_bb_line']] ?? ''} $compare',
    'price' => '가격 $compare $value',
    'candle' => '캔들 $compare',
    final type => '$type $compare',
  };
}

String _orTitle(Map<String, dynamic> p, String prefix) {
  final frame = p['${prefix}_timeframe'];
  final interval = p['${prefix}_timing_itv'];
  final timing = switch (p['${prefix}_timing_mode']) {
    _ when interval is num && interval > 0 => '${_number(interval)}분 완성 시',
    'realtime' => '실시간',
    'on_candle_close' => '봉 완성 시',
    _ => null,
  };
  final frameText = frame is List && frame.length >= 2 ? (frame[0] == 'day' ? '일봉' : '${frame[1]}분') : null;
  return [?frameText, ?timing].join(' · ');
}

/// 지표 조건을 "묶음 이름 → AND 조건 목록" 으로 만든다. 청산 조건은 [liveExitCards] 에 있다.
Map<String, List<String>> liveConditions(Map<String, dynamic> p) {
  final sets = <(String, String)>[
    ('매수 전제', 'buy_pre_or'),
    ('매수', 'buy_or'),
    ('매도 전제', 'sell_pre_or'),
    ('매도', 'sell_or'),
  ];
  final result = <String, List<String>>{};
  for (final (label, key) in sets) {
    final count = p['num_$key'];
    if (count is! num) continue;
    for (var i = 1; i <= count; i++) {
      final prefix = '$key$i';
      final ands = p['${prefix}_num_and'];
      if (ands is! num) continue;
      final title = _orTitle(p, prefix);
      result['$label OR $i${title.isEmpty ? '' : ' · $title'}'] = [
        for (var j = 1; j <= ands; j++)
          if (p['${prefix}_and${j}_type'] != null) _condition(p, '${prefix}_and$j'),
      ];
    }
  }
  return result;
}

/// 앱 커스텀 청산 조건 카드. 켜져 있으면 설명 아래에 조건을 붙인다.
/// 매수만 쓰는 전략에는 매도 카드가, 매도만 쓰는 전략에는 매수 카드가 없다.
List<LiveSetting> liveExitCards(Map<String, dynamic> p, {required bool isAlert}) {
  if (isAlert) return const [];
  final direction = p['direction'];
  final sellOnly = const {'sell', 'sell_only', 'gap_down_only'}.contains(direction);
  final buyOnly = const {'buy', 'buy_only', 'gap_up_only'}.contains(direction);
  LiveSetting card(String side, String key) {
    final count = p['num_$key'];
    final on = p['use_custom_exit'] == true && count is num && count > 0;
    final lines = <String>[
      '$side 보유 중 지표 조건으로 나간다 (가격으로 나가는 청산설정과 별개)',
      if (on)
        for (var i = 1; i <= count; i++)
          if (p['$key${i}_num_and'] case final num ands)
            'OR $i${_orTitle(p, '$key$i').isEmpty ? '' : ' · ${_orTitle(p, '$key$i')}'}: ${[for (var j = 1; j <= ands; j++)
              if (p['$key${i}_and${j}_type'] != null) _condition(p, '$key${i}_and$j')].join(' AND ')}',
    ];
    return LiveSetting.toggle('$side 커스텀 청산 조건', lines.join('\n'), on);
  }

  return [if (!sellOnly) card('매수', 'buy_exit_or'), if (!buyOnly) card('매도', 'sell_exit_or')];
}

/// 앱 트레일링 스탑 칸의 항목. 꺼져 있어도 보여 준다. 회차가 있으면 회차마다 마디가 있다.
Map<String, String> liveTrailingRows(Map<String, dynamic> p, String unit) {
  final legacyOne = p['trailing_stop_count'] == null && p['trailing_stop_mode'] == 'breakeven';
  final count = (p['trailing_stop_count'] as num?)?.toInt() ?? (legacyOne ? 1 : 0);
  final first = p['trailing_stop_step'] ?? p['breakeven_trigger_value'];
  String step(Object? v) => v == null ? '-' : '${_number(v)} $unit';
  final steps = p['trailing_stop_steps'];
  return {
    '동작 회차': '$count 회',
    if (count == 0) '동작 마디': step(first),
    for (var r = 1; r <= count.clamp(0, 10); r++)
      '$r회차 마디': step(
        r == 1 ? first : (steps is List && steps.length >= r && steps[r - 1] != null ? steps[r - 1] : first),
      ),
  };
}
