import 'dart:convert';

import 'package:dungeon_admin/live_admin.dart';
import 'package:dungeon_admin/live_api.dart';
import 'package:dungeon_admin/mock_admin.dart';
import 'package:dungeon_admin/mock_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _ok(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

void main() {
  setUp(resetMockAdmins);

  test('공지 목업 API 응답을 화면 공지로 바꾸고, 저장할 때 이미지 id 를 보낸다', () async {
    Map<String, dynamic>? sent;
    setLiveClient(
      MockClient((req) async {
        if (req.url.path.endsWith('/auth/login')) return _ok({'token': 't'});
        if (req.method == 'GET' && req.url.path.endsWith('/notices')) {
          return _ok({
            'items': [
              {
                'id': 7,
                'title': '점검 안내',
                'body': '내용',
                'category': '점검',
                'grades': ['골드'],
                'pinned': true,
                'popup': true,
                'status': 'scheduled',
                'publishAt': '2026-11-20T00:00:00Z',
                'endAt': null,
                'author': '김대표',
                'createdAt': '2026-11-12T00:00:00Z',
                'views': 0,
                'images': [
                  {'id': 'abc', 'url': '/api/admin/notices/images/abc', 'name': 'a.png'},
                ],
              },
            ],
          });
        }
        if (req.method == 'POST' && req.url.path.endsWith('/notices')) {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _ok({'id': 8, 'title': sent!['title'], 'status': 'draft', 'createdAt': '2026-11-12T00:00:00Z'}, 201);
        }
        return http.Response('', 404);
      }),
    );

    final list = await loadLiveNotices();
    final n = list.single;
    expect(n.status, NoticeStatus.scheduled);
    expect(n.grades, {'골드'});
    expect(n.pinned && n.popup, isTrue);
    expect(n.images.single.url, 'http://localhost:5185/api/admin/notices/images/abc');

    final saved = await saveLiveNotice(
      null,
      noticeRequest(
        title: '새 공지',
        body: '본문',
        category: '공지',
        grades: const {},
        pinned: false,
        popup: true,
        publishAt: null,
        endAt: null,
        status: 'draft',
        notifyPush: false,
        images: n.images,
      ),
    );
    expect(saved.id, 8);
    expect(sent!['imageIds'], ['abc']);
    expect(sent!['popup'], isTrue);
  });

  test('등급별 화면을 API key 로 주고받는다', () async {
    List<dynamic>? put;
    setLiveClient(
      MockClient((req) async {
        if (req.url.path.endsWith('/auth/login')) return _ok({'token': 't'});
        if (req.method == 'GET') {
          return _ok({
            'roles': [
              {'role': 'superAdmin', 'screens': <String>[]},
              {
                'role': 'consultant',
                'screens': ['dashboard', 'dashboard.overview', 'members', 'members.monitor', 'members.monitor.logs'],
              },
            ],
          });
        }
        put = (jsonDecode(req.body) as Map<String, dynamic>)['screens'] as List;
        return _ok({'role': 'consultant', 'screens': put});
      }),
    );

    await loadLiveRoleScreens();
    expect(roleScreenOn(AdminRole.consultant, monitorTabKey('로그')), isTrue);
    expect(roleScreenOn(AdminRole.consultant, monitorTabKey('워커')), isFalse);
    expect(roleCanSee(AdminRole.superAdmin, '관리자'), isTrue);

    await saveLiveRoleScreen(AdminRole.consultant, monitorTabKey('워커'), true);
    expect(put, contains('members.monitor.workers'));
    expect(roleScreenOn(AdminRole.consultant, monitorTabKey('워커')), isTrue);
  });
}
