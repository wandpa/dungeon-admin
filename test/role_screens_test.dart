import 'package:dungeon_admin/mock_admin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(resetMockAdmins);

  test('최고 관리자가 끈 화면은 그 등급에게 보이지 않는다', () {
    expect(signIn('cs', samplePassword), isNull);
    expect(canSee('공지사항'), isTrue);
    expect(canSee('관리자'), isFalse);

    setRoleScreen(AdminRole.consultant, '공지사항', false);
    setRoleScreen(AdminRole.consultant, '관리자', true);
    expect(canSee('공지사항'), isFalse);
    expect(canSee('관리자'), isTrue);
  });

  test('최고 관리자 화면은 끌 수 없고 등급마다 화면이 하나는 남는다', () {
    setRoleScreen(AdminRole.superAdmin, '대시보드', false);
    expect(roleCanSee(AdminRole.superAdmin, '대시보드'), isTrue);

    for (final s in adminScreens) {
      setRoleScreen(AdminRole.operator, s, false);
    }
    expect(adminScreens.where((s) => roleScreenOn(AdminRole.operator, s)).length, 1);
  });

  test('대화면을 끄면 그 안의 소화면도 안 보인다', () {
    expect(signIn('cs', samplePassword), isNull);
    final worker = monitorTabKey('워커');
    expect(canSee(worker), isTrue);

    setRoleScreen(AdminRole.consultant, monitorTabKey('로그'), false);
    expect(canSee(monitorTabKey('로그')), isFalse);
    expect(canSee(worker), isTrue);

    setRoleScreen(AdminRole.consultant, '회원 관리', false);
    expect(canSee(worker), isFalse);
    expect(roleParentOn(AdminRole.consultant, worker), isFalse);
  });
}
