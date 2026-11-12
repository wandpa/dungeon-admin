import 'dart:typed_data';

/// 고른 파일 이름과 내용.
typedef PickedFile = ({String name, Uint8List bytes});

Future<List<PickedFile>> pickImages() async => const [];
