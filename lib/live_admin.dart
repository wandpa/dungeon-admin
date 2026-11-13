/// 관리자 API 의 목업 저장소(공지·등급별 화면) 연결. 서버가 메모리에 두므로 API 를 다시 켜면 사라진다.
library;

import 'package:flutter/foundation.dart';

import 'deep_link.dart';
import 'live_api.dart';
import 'mock_admin.dart';
import 'mock_data.dart';

AdminRole? _role(Object? name) => AdminRole.values.asNameMap()[name];

/// 서버에 저장된 등급별 화면을 받아 온다. 실패하면 브라우저에 있던 값을 그대로 쓴다.
Future<void> loadLiveRoleScreens() async {
  try {
    final body = await adminGet('/role-screens') as Map<String, dynamic>;
    for (final r in (body['roles'] as List).cast<Map<String, dynamic>>()) {
      final role = _role(r['role']);
      if (role != null) applyRoleScreensFromApi(role, r['screens'] as List);
    }
  } on LiveApiException catch (e) {
    debugPrint('등급별 화면을 받지 못했습니다: ${e.message}');
  }
}

/// 등급의 화면 하나를 켜거나 끄고 서버에 저장한다. 서버가 거절하면 [LiveApiException].
Future<void> saveLiveRoleScreen(AdminRole role, String key, bool on) async {
  final body = await adminSend('PUT', '/role-screens/${role.name}', {
    'screens': roleScreensForApi(role, key: key, on: on),
  }) as Map<String, dynamic>;
  applyRoleScreensFromApi(role, body['screens'] as List);
}

// ---------------------------------------------------------------- 공지

NoticeStatus _status(Object? v) => switch (v) {
  'published' => NoticeStatus.published,
  'scheduled' => NoticeStatus.scheduled,
  _ => NoticeStatus.draft,
};

DateTime? _time(Object? v) => liveTime(v);

Notice _notice(Map<String, dynamic> n) => Notice(
  n['id'] as int,
  n['title'] as String? ?? '',
  n['body'] as String? ?? '',
  n['author'] as String? ?? '-',
  _time(n['createdAt']) ?? DateTime.now(),
  (n['views'] as num?)?.toInt() ?? 0,
  n['pinned'] == true,
  _status(n['status']),
  publishAt: _time(n['publishAt']),
  updatedAt: _time(n['updatedAt']),
  category: n['category'] as String? ?? '공지',
  grades: {...(n['grades'] as List? ?? const []).cast<String>()},
  popup: n['popup'] == true,
  endAt: _time(n['endAt']),
  images: [
    for (final i in (n['images'] as List? ?? const []).cast<Map<String, dynamic>>())
      NoticeImage(i['name'] as String? ?? '', null, id: i['id'] as String?, url: adminUrl(i['url'] as String)),
  ],
  link: DeepLink.fromJson(n['link']),
);

/// 공지 전체. 서버 목업은 많아야 수십 건이라 한 번에 받는다.
Future<List<Notice>> loadLiveNotices() async {
  final body = await adminGet('/notices?page=1&pageSize=200') as Map<String, dynamic>;
  return [for (final n in (body['items'] as List).cast<Map<String, dynamic>>()) _notice(n)];
}

/// 작성·수정 본문.
Map<String, Object?> noticeRequest({
  required String title,
  required String body,
  required String category,
  required Set<String> grades,
  required bool pinned,
  required bool popup,
  required DateTime? publishAt,
  required DateTime? endAt,
  required String status,
  required bool notifyPush,
  required List<NoticeImage> images,
  DeepLink link = DeepLink.none,
}) => {
  'title': title,
  'body': body,
  'category': category,
  'grades': grades.toList(),
  'pinned': pinned,
  'popup': popup,
  'publishAt': publishAt?.toUtc().toIso8601String(),
  'endAt': endAt?.toUtc().toIso8601String(),
  'status': status,
  'notifyPush': notifyPush,
  'imageIds': [for (final i in images) ?i.id],
  'link': link.toJson(),
};

/// 새 공지면 id 없이 만든다.
Future<Notice> saveLiveNotice(int? id, Map<String, Object?> request) async => _notice(
  await adminSend(id == null ? 'POST' : 'PUT', id == null ? '/notices' : '/notices/$id', request)
      as Map<String, dynamic>,
);

Future<Notice> setLiveNoticePublished(int id, bool published) async =>
    _notice(await adminSend('POST', '/notices/$id/${published ? 'publish' : 'unpublish'}') as Map<String, dynamic>);

Future<Notice> setLiveNoticePinned(int id, bool pinned) async =>
    _notice(await adminSend('PATCH', '/notices/$id/pin', {'pinned': pinned}) as Map<String, dynamic>);

Future<void> deleteLiveNotice(int id) => adminSend('DELETE', '/notices/$id');

/// 이미지를 올리고 서버 id·주소를 붙인 이미지를 돌려준다.
Future<NoticeImage> uploadLiveNoticeImage(String name, Uint8List bytes) async {
  final i = await adminUpload('/notices/images', name, bytes);
  return NoticeImage(name, bytes, id: i['id'] as String?, url: adminUrl(i['url'] as String));
}
