import 'package:dungeon_admin/main.dart';
import 'package:dungeon_admin/mock_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(resetMockMembers);

  testWidgets('넓은 화면: 사이드바 메뉴로 모든 화면을 오갈 수 있다', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AdminApp());
    expect(find.text('오늘의 던전 현황을 한눈에 봅니다.'), findsOneWidget);

    const pages = {
      '회원 관리': 'risingkang',
      '신호 관리': '마이크로 WTI 원유 12월물',
      '푸시 알림': '오늘의 던전이 열렸습니다',
      '공지사항': '던전우상향 정식 출시 안내',
      '대시보드': '최근 신호',
    };
    for (final MapEntry(key: menu, value: content) in pages.entries) {
      await tester.tap(find.widgetWithText(ListTile, menu));
      await tester.pumpAndSettle();
      expect(find.text(content), findsWidgets, reason: menu);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 화면: 서랍 메뉴로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '공지사항'));
    await tester.pumpAndSettle();

    expect(find.text('던전우상향 정식 출시 안내'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> openMembers(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AdminApp());
    await tester.tap(find.widgetWithText(ListTile, '회원 관리'));
    await tester.pumpAndSettle();
  }

  testWidgets('회원: 승인 대기 회원을 골라 한 번에 승인한다', (tester) async {
    await openMembers(tester);
    expect(find.text('가입 승인을 기다리는 회원이 3명 있습니다.'), findsOneWidget);

    await tester.tap(find.text('승인 대기 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first); // 전체 선택
    await tester.pumpAndSettle();
    expect(find.text('3명 선택됨'), findsOneWidget);

    await tester.tap(find.text('선택 승인'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '승인'));
    await tester.pumpAndSettle();

    expect(find.text('승인 대기 0'), findsOneWidget);
    expect(mockMembers.where((m) => m.status == MemberStatus.pending), isEmpty);
    expect(mockMembers.firstWhere((m) => m.id == 1027).history.first.text, '가입 승인');
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원: 검색하고 상세에서 정지·해제한다', (tester) async {
    await openMembers(tester);
    await tester.enterText(find.byType(TextField), 'uptrend');
    await tester.pumpAndSettle();
    expect(find.text('uptrend99'), findsOneWidget);
    expect(find.text('risingkang'), findsNothing);
    expect(find.text('up**@example.com'), findsOneWidget); // 목록은 이메일을 가린다

    await tester.tap(find.text('uptrend99')); // 아이디를 눌러도 상세가 열린다
    await tester.pumpAndSettle();
    await tester.tap(find.text('이용 정지'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '정지 사유 (회원에게 안내됩니다)'), '테스트 정지');
    await tester.tap(find.text('30일'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '정지'));
    await tester.pumpAndSettle();

    final m = mockMembers.firstWhere((m) => m.username == 'uptrend99');
    expect(m.status, MemberStatus.suspended);
    expect(find.text('테스트 정지'), findsOneWidget);

    await tester.tap(find.text('정지 해제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '해제'));
    await tester.pumpAndSettle();
    expect(m.status, MemberStatus.active);
    expect(m.history.first.text, '정지 해제');
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원: 탈퇴 요청을 처리하면 목록에서 사라진다', (tester) async {
    await openMembers(tester);
    await tester.tap(find.text('탈퇴 요청 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('dungeon_walker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴 처리 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '탈퇴 처리'));
    await tester.pumpAndSettle();

    expect(find.text('dungeon_walker'), findsNothing);
    expect(find.text('탈퇴 요청 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
