import 'package:flutter/material.dart';

import '../theme.dart';

/// 관리 화면 공통 틀: 제목, 설명, 우측 버튼, 본문.
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.title,
    required this.description,
    required this.children,
    this.actions = const [],
  });

  final String title;
  final String description;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: AppColors.textTertiary)),
              ],
            ),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
        const SizedBox(height: 20),
        for (final c in children) ...[c, const SizedBox(height: 16)],
      ],
    );
  }
}

/// 테두리 있는 카드.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.title, this.padding = const EdgeInsets.all(20)});

  final String? title;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Container 대신 Material 이어야 안쪽 ListTile 의 선택 배경·물결 효과가 보인다.
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// 가로로 넘치면 스크롤되는 표.
class AdminTable extends StatelessWidget {
  const AdminTable({super.key, required this.columns, required this.rows});

  final List<String> columns;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columns: [for (final c in columns) DataColumn(label: Text(c))],
              rows: [
                for (final r in rows) DataRow(cells: [for (final cell in r) DataCell(cell)]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 검색창 + 필터 칩 줄.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.hint, this.filters = const []});

  final String hint;
  final List<String> filters;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 20), hintText: hint),
          ),
        ),
        for (final (i, f) in filters.indexed)
          FilterChip(label: Text(f), selected: i == 0, onSelected: (_) {}),
      ],
    );
  }
}

/// 상태 표시 라벨.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// 아직 API 가 없는 버튼을 눌렀을 때 안내.
void showNotConnected(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('아직 API 가 연결되지 않았습니다.')));
}
