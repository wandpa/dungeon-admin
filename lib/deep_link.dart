/// 푸시·공지를 눌렀을 때 앱이 열 곳.
///
/// 앱은 푸시 data 의 `path` 로 화면을 연다(dungeon-app `handleNotificationTap`).
/// 허용 목록(`AppRoutes.isAllowedPushPath`)에 없는 경로는 알림함(/notification)으로 열리므로,
/// 앱이 아직 모르는 공지 경로를 보내도 앱이 깨지지 않는다.
enum DeepLinkType {
  none('연결 없음'),
  screen('앱 화면'),
  notice('공지'),
  url('웹 주소');

  const DeepLinkType(this.label);
  final String label;

  static DeepLinkType parse(Object? v) => values.firstWhere((t) => t.name == v, orElse: () => none);
}

/// 앱 화면 하나. [ready] 가 false 면 앱에 아직 없는 화면이라 앱 업데이트 전에는 알림함으로 열린다.
class AppScreen {
  const AppScreen(this.path, this.label, {this.ready = true});

  final String path;
  final String label;
  final bool ready;
}

/// 관리자가 고를 수 있는 앱 화면. 경로를 직접 적지 않고 여기서만 고른다.
const appScreens = [
  AppScreen('/worker', '워커'),
  AppScreen('/watchlist', '관심종목'),
  AppScreen('/history', '내역 (신호·거래)'),
  AppScreen('/notification', '알림함'),
  AppScreen('/my', '마이'),
  AppScreen('/notice', '공지 목록', ready: false),
];

AppScreen? appScreenOf(String? path) {
  for (final s in appScreens) {
    if (s.path == path) return s;
  }
  return null;
}

/// 공지 상세 경로. 앱에 공지 화면이 생기면 이 경로를 연다.
String noticePath(int id) => '/notice/$id';

/// 웹 주소 최대 길이.
const maxLinkUrl = 2048;

class DeepLink {
  const DeepLink(this.type, {this.target, this.label});

  static const none = DeepLink(DeepLinkType.none);

  final DeepLinkType type;

  /// screen: 앱 경로, notice: 공지 번호, url: https 주소.
  final String? target;

  /// 공지 본문 아래 버튼 글자(공지에만 쓴다). 비어 있으면 앱이 '자세히 보기'로 보인다.
  final String? label;

  bool get isNone => type == DeepLinkType.none;

  int? get noticeId => type == DeepLinkType.notice ? int.tryParse(target ?? '') : null;

  /// 푸시 data 에 실을 값. 앱은 path 로 화면을 열고, url 이 있으면 바깥 브라우저로 연다.
  /// 웹 주소일 때도 path 를 알림함으로 두어, url 을 모르는 예전 앱은 알림함을 연다.
  Map<String, String> get pushData => switch (type) {
    DeepLinkType.none => const {},
    DeepLinkType.screen => {'path': target ?? ''},
    DeepLinkType.notice => {'path': noticePath(noticeId ?? 0)},
    DeepLinkType.url => {'path': '/notification', 'url': target ?? ''},
  };

  /// 잘못된 곳이면 이유, 괜찮으면 null.
  String? get error {
    final t = target?.trim() ?? '';
    switch (type) {
      case DeepLinkType.none:
        return null;
      case DeepLinkType.screen:
        return appScreenOf(t) == null ? '앱 화면을 고르세요.' : null;
      case DeepLinkType.notice:
        return noticeId == null ? '연결할 공지를 고르세요.' : null;
      case DeepLinkType.url:
        if (t.isEmpty) return '웹 주소를 적으세요.';
        if (t.length > maxLinkUrl) return '웹 주소는 $maxLinkUrl자까지입니다.';
        final u = Uri.tryParse(t);
        if (u == null || u.scheme != 'https' || u.host.isEmpty) return 'https:// 로 시작하는 주소만 쓸 수 있습니다.';
        return null;
    }
  }

  /// 표·확인 창에 보일 짧은 설명.
  String describe({String Function(int id)? noticeTitle}) => switch (type) {
    DeepLinkType.none => '연결 없음',
    DeepLinkType.screen => '앱 · ${appScreenOf(target)?.label ?? target}',
    DeepLinkType.notice => '공지 · ${noticeId == null ? '-' : (noticeTitle?.call(noticeId!) ?? '#$noticeId')}',
    DeepLinkType.url => '웹 · ${target ?? ''}',
  };

  /// API 로 보내는 값. 연결이 없으면 null.
  Map<String, Object?>? toJson() => isNone
      ? null
      : {
          'type': type.name,
          'target': target?.trim(),
          if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
        };

  static DeepLink fromJson(Object? v) {
    if (v is! Map) return none;
    final type = DeepLinkType.parse(v['type']);
    if (type == DeepLinkType.none) return none;
    return DeepLink(type, target: v['target']?.toString(), label: v['label'] as String?);
  }

  DeepLink copyWith({DeepLinkType? type, String? target, String? label}) =>
      DeepLink(type ?? this.type, target: target ?? this.target, label: label ?? this.label);

  @override
  bool operator ==(Object other) =>
      other is DeepLink && other.type == type && other.target == target && other.label == label;

  @override
  int get hashCode => Object.hash(type, target, label);
}
