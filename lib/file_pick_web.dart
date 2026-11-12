import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// 고른 파일 이름과 내용.
typedef PickedFile = ({String name, Uint8List bytes});

/// 이미지 파일을 여러 장 고른다. 취소하면 빈 목록이다.
Future<List<PickedFile>> pickImages() {
  final done = Completer<List<PickedFile>>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/png,image/jpeg,image/gif,image/webp'
    ..multiple = true;
  input.onchange = (web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) return done.complete(const []);
    Future.wait([
      for (var i = 0; i < files.length; i++)
        files.item(i)!.arrayBuffer().toDart.then((b) => (name: files.item(i)!.name, bytes: b.toDart.asUint8List())),
    ]).then(done.complete, onError: done.completeError);
  }.toJS;
  input.oncancel = (web.Event _) {
    if (!done.isCompleted) done.complete(const []);
  }.toJS;
  input.click();
  return done.future;
}
