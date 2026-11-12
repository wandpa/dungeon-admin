/// 브라우저에서 파일을 고른다. 테스트(VM)에서는 아무것도 고르지 않는다.
library;

export 'file_pick_stub.dart' if (dart.library.js_interop) 'file_pick_web.dart';
