import 'package:dungeon_admin/mock_admin.dart';
import 'package:dungeon_admin/widgets/admin_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<(String, String)> files;
  late List<(String, int, String?)> logged;

  setUp(() {
    files = [];
    logged = [];
    csvDownloader = (name, text) => files.add((name, text));
    onAdminTableExported = (name, count, memberId) => logged.add((name, count, memberId));
  });

  tearDown(() => onAdminTableExported = null);

  test('CSV: 수식처럼 보이는 값은 막고 숫자는 그대로 둔다', () {
    exportCsv('시험', ['이름', '값'], [
      ['=SUM(A1)', '-12,000'],
      ['a"b', '+82 10'],
    ], memberLiveId: 'm1');
    final (name, text) = files.single;
    expect(name, startsWith('시험_'));
    expect(text.split('\r\n'), ['"이름","값"', '"\'=SUM(A1)","-12,000"', '"a""b","\'+82 10"']);
    expect(logged.single, ('시험', 2, 'm1'));
  });

  testWidgets('표 내보내기: 화면에 그려진 글자를 모으고 버튼 칸은 뺀다', (tester) async {
    signedInAdmin.value = mockAdmins.first; // 최고 관리자는 내보내기 권한이 있다
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminTable(
            exportName: '목록',
            columns: const ['보기', '아이디', '상태'],
            buttonColumns: const {0},
            rows: [
              [TextButton(onPressed: () {}, child: const Text('상세')), const Text('tester'), const Text('정상')],
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('엑셀 내보내기 1건'));
    expect(files.single.$2.split('\r\n'), ['"아이디","상태"', '"tester","정상"']);
    expect(logged.single, ('목록', 1, null));
    signedInAdmin.value = null;
  });
}
