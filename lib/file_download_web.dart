import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 앞의 BOM 이 있어야 엑셀이 한글을 UTF-8 로 읽는다.
void downloadCsv(String fileName, String text) {
  final blob = web.Blob(['﻿$text'.toJS].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..click();
  web.URL.revokeObjectURL(url);
}
