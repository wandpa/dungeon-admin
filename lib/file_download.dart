/// 브라우저에서 파일을 내려받는다. 테스트(VM)에서는 아무 일도 하지 않는다.
library;

export 'file_download_stub.dart' if (dart.library.js_interop) 'file_download_web.dart';
