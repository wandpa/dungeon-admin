import 'package:dungeon_admin/deep_link.dart';
import 'package:dungeon_admin/live_admin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('앱 화면은 path 로 실린다', () {
    const l = DeepLink(DeepLinkType.screen, target: '/worker');
    expect(l.error, isNull);
    expect(l.pushData, {'path': '/worker'});
    expect(l.toJson(), {'type': 'screen', 'target': '/worker'});
  });

  test('목록에 없는 앱 경로는 막는다', () {
    expect(const DeepLink(DeepLinkType.screen, target: '/symbol/1').error, isNotNull);
  });

  test('공지는 /notice/{id} 로 실린다', () {
    const l = DeepLink(DeepLinkType.notice, target: '12', label: '참여하기');
    expect(l.error, isNull);
    expect(l.pushData, {'path': '/notice/12'});
    expect(l.toJson(), {'type': 'notice', 'target': '12', 'label': '참여하기'});
  });

  test('웹 주소는 https 만 받고, 예전 앱을 위해 알림함 path 도 싣는다', () {
    expect(const DeepLink(DeepLinkType.url, target: 'http://a.com').error, isNotNull);
    expect(const DeepLink(DeepLinkType.url, target: 'javascript:alert(1)').error, isNotNull);
    const ok = DeepLink(DeepLinkType.url, target: 'https://dungeon.example/event');
    expect(ok.error, isNull);
    expect(ok.pushData, {'path': '/notification', 'url': 'https://dungeon.example/event'});
  });

  test('연결 없음은 null 로 보내고, 읽을 때도 없음이 된다', () {
    expect(DeepLink.none.toJson(), isNull);
    expect(DeepLink.fromJson(null), DeepLink.none);
    expect(DeepLink.fromJson({'type': 'zzz'}), DeepLink.none);
    expect(
      DeepLink.fromJson({'type': 'url', 'target': 'https://a.com', 'label': '보기'}),
      const DeepLink(DeepLinkType.url, target: 'https://a.com', label: '보기'),
    );
  });

  test('공지 저장 본문에 link 가 들어간다', () {
    final r = noticeRequest(
      title: 't',
      body: 'b',
      category: '공지',
      grades: {},
      pinned: false,
      popup: false,
      publishAt: null,
      endAt: null,
      status: 'draft',
      notifyPush: false,
      images: const [],
      link: const DeepLink(DeepLinkType.screen, target: '/history'),
    );
    expect(r['link'], {'type': 'screen', 'target': '/history'});
    expect(noticeRequest(
      title: 't',
      body: 'b',
      category: '공지',
      grades: {},
      pinned: false,
      popup: false,
      publishAt: null,
      endAt: null,
      status: 'draft',
      notifyPush: false,
      images: const [],
    )['link'], isNull);
  });
}
