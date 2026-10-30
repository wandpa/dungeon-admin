import 'package:dungeon_admin/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
