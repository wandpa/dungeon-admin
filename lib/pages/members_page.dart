import 'package:flutter/material.dart';

import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: '회원 관리',
      description: '가입 회원을 조회하고 상태를 관리합니다.',
      actions: [
        OutlinedButton.icon(
          onPressed: () => showNotConnected(context),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('엑셀 내보내기'),
        ),
      ],
      children: [
        FilterBar(
          hint: '아이디·이메일 검색',
          filters: ['전체', for (final s in MemberStatus.values) s.label],
        ),
        AdminTable(
          columns: const ['번호', '아이디', '이메일', '가입일', '최근 접속', '상태', ''],
          rows: [
            for (final m in mockMembers)
              [
                Text('${m.id}'),
                Text(m.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(m.email),
                Text(formatDateTime(m.joinedAt)),
                Text(formatDateTime(m.lastLoginAt)),
                StatusBadge(m.status.label, color: _statusColor(m.status)),
                TextButton(onPressed: () => showNotConnected(context), child: const Text('상세')),
              ],
          ],
        ),
      ],
    );
  }

  Color _statusColor(MemberStatus s) => switch (s) {
        MemberStatus.active => AppColors.success,
        MemberStatus.dormant => AppColors.textTertiary,
        MemberStatus.suspended => AppColors.up,
        MemberStatus.deleteRequested => AppColors.warning,
      };
}
