import 'dart:convert';

import 'package:dungeon_admin/live_api.dart';
import 'package:dungeon_admin/mock_admin.dart';
import 'package:dungeon_admin/mock_data.dart';
import 'package:dungeon_admin/pages/live_notifications_page.dart';
import 'package:dungeon_admin/pages/member_detail_dialog.dart';
import 'package:dungeon_admin/pages/push_page.dart' show pushTargetRequest;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _notConnected = '아직 API 가 연결되지 않았습니다.';

Member _member(MemberStatus status) => Member(
  9001,
  'liveuser',
  'li***@test.com',
  DateTime(2026, 1, 1),
  null,
  status,
  liveId: '11111111-0000-0000-0000-000000000000',
);

void main() {
  setUp(() {
    resetMockAdmins();
    signIn('admin', samplePassword);
    useLiveData.value = true;
    liveMembers.clear();
  });

  tearDown(() => useLiveData.value = false);

  Future<void> pumpDetail(WidgetTester tester, Member m) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: MemberDetailView(m))),
      ),
    );
  }

  testWidgets('테스트 DB 회원: 처리 버튼은 칸 안에 입력 화면을 열고 마지막에 안내만 한다', (tester) async {
    final m = _member(MemberStatus.active);
    await pumpDetail(tester, m);

    await tester.tap(find.text('이용 정지'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    final send = find.widgetWithText(FilledButton, '정지');
    expect(tester.widget<FilledButton>(send).onPressed, isNull); // 사유가 있어야 누를 수 있다
    await tester.enterText(find.widgetWithText(TextField, '정지 사유 (회원에게 안내됩니다)'), '약관 위반');
    await tester.tap(find.widgetWithText(ChoiceChip, '30일'));
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pump();
    expect(find.text(_notConnected), findsOneWidget);
    expect(m.status, MemberStatus.active);

    await tester.tap(find.widgetWithText(OutlinedButton, '접속 차단'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '차단 사유'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '정지'), findsNothing);
    expect(m.accessBlocked, isFalse);

    await tester.tap(find.widgetWithText(OutlinedButton, '휴면 전환'));
    await tester.pumpAndSettle();
    expect(find.text('${m.username} 회원을 휴면으로 전환합니다.'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '취소'));
    await tester.pumpAndSettle();
    expect(find.text('${m.username} 회원을 휴면으로 전환합니다.'), findsNothing);
  });

  testWidgets('테스트 DB 회원: 승인 대기는 승인 화면이 열리고 상담 입력도 보인다', (tester) async {
    await pumpDetail(tester, _member(MemberStatus.pending));
    await tester.tap(find.text('가입 승인'));
    await tester.pumpAndSettle();
    expect(find.text('liveuser 회원의 가입을 승인합니다.'), findsOneWidget);

    expect(find.widgetWithText(TextField, '상담·문의 내용을 남겨 두세요'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '상담·문의 내용을 남겨 두세요'), '문의');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pump();
    expect(find.text(_notConnected), findsOneWidget);
  });

  testWidgets('푸시 알림: 회원 상세에서 오면 그 회원이 받는 사람으로 골라져 있다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    setLiveClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'token': 't'}), 200);
        final Object body = request.url.path.endsWith('/live/notifications')
            ? {'items': [], 'page': 1, 'pageSize': 20, 'total': 0}
            : {
                'items': [
                  {
                    'id': '11111111-0000-0000-0000-000000000000',
                    'username': 'superman',
                    'status': 'active',
                    'maskedEmail': 'su***@test.com',
                    'joinedAt': '2026-10-28T03:20:00Z',
                    'workerCount': 0,
                    'runningWorkerCount': 0,
                  },
                ],
                'page': 1,
                'pageSize': 100,
                'total': 1,
              };
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );
    await refreshLiveMembers();
    final m = liveMembers.single;
    pushTargetRequest.value = m.id;

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LiveNotificationsPage())));
    await tester.pumpAndSettle();

    expect(pushTargetRequest.value, isNull);
    expect(find.text('superman에게 보내기'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '제목'), '점검 안내');
    await tester.enterText(find.widgetWithText(TextField, '내용'), '오늘 점검합니다');
    await tester.pumpAndSettle();
    await tester.tap(find.text('superman에게 보내기'));
    await tester.pump();
    expect(find.text(_notConnected), findsOneWidget);
  });
}
