import 'package:flutter/material.dart';

import '../mock_data.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

class PushPage extends StatelessWidget {
  const PushPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: '푸시 알림',
      description: '앱 사용자에게 푸시 알림을 보내고 발송 이력을 확인합니다.',
      actions: [
        FilledButton.icon(
          onPressed: () => showNotConnected(context),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('새 알림 보내기'),
        ),
      ],
      children: [
        AdminTable(
          columns: const ['번호', '제목', '내용', '대상', '발송 시각', '발송', '열람'],
          rows: [
            for (final p in mockPushes)
              [
                Text('${p.id}'),
                Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(
                  width: 260,
                  child: Text(p.body, overflow: TextOverflow.ellipsis),
                ),
                Text(p.target),
                Text(formatDateTime(p.sentAt)),
                Text(formatNumber(p.sentCount)),
                Text(
                  '${formatNumber(p.openCount)} (${(p.openCount / p.sentCount * 100).round()}%)',
                  style: const TextStyle(color: AppColors.accent),
                ),
              ],
          ],
        ),
      ],
    );
  }
}
