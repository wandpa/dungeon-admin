import 'package:web/web.dart' as web;

const _prefix = 'dungeon-admin/';

/// 브라우저가 저장소를 막아 두면 기본값으로 동작한다.
String? readView(String key) {
  try {
    return web.window.localStorage.getItem('$_prefix$key');
  } catch (_) {
    return null;
  }
}

void writeView(String key, String value) {
  try {
    web.window.localStorage.setItem('$_prefix$key', value);
  } catch (_) {
    // 이번 화면에서만 유지된다.
  }
}
