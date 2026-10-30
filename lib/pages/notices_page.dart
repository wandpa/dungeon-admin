import 'package:flutter/material.dart';

import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: '공지사항',
      description: '앱과 홈페이지에 노출되는 공지를 관리합니다.',
      actions: [
        FilledButton.icon(
          onPressed: () => showNotConnected(context),
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('공지 작성'),
        ),
      ],
      children: [
        const FilterBar(hint: '제목 검색', filters: ['전체', '게시', '임시저장']),
        AdminTable(
          columns: const ['번호', '제목', '작성자', '작성일', '조회수', '상태', ''],
          rows: [
            for (final n in mockNotices)
              [
                Text('${n.id}'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (n.pinned) ...[
                      const Icon(Icons.push_pin, size: 16, color: AppColors.accent),
                      const SizedBox(width: 6),
                    ],
                    Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                Text(n.author),
                Text(formatDateTime(n.createdAt)),
                Text(formatNumber(n.views)),
                n.published
                    ? const StatusBadge('게시', color: AppColors.success)
                    : const StatusBadge('임시저장', color: AppColors.textTertiary),
                TextButton(onPressed: () => showNotConnected(context), child: const Text('수정')),
              ],
          ],
        ),
      ],
    );
  }
}
