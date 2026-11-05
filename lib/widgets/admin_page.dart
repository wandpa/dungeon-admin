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
///
/// [selected] 를 주면 앞에 체크박스 열이 생긴다. 값은 rows 의 순번이다.
class AdminTable extends StatelessWidget {
  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.selected,
    this.onSelectChanged,
    this.onSelectAll,
    this.emptyText = '표시할 항목이 없습니다.',
  });

  final List<String> columns;
  final List<List<Widget>> rows;
  final Set<int>? selected;
  final void Function(int index, bool selected)? onSelectChanged;
  final ValueChanged<bool>? onSelectAll;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final selectable = selected != null;
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  showCheckboxColumn: selectable,
                  columnSpacing: 32,
                  onSelectAll: selectable ? (v) => onSelectAll?.call(v ?? false) : null,
                  columns: [for (final c in columns) DataColumn(label: Text(c))],
                  rows: [
                    for (final (i, r) in rows.indexed)
                      DataRow(
                        selected: selected?.contains(i) ?? false,
                        onSelectChanged: selectable ? (v) => onSelectChanged?.call(i, v ?? false) : null,
                        cells: [for (final cell in r) DataCell(cell)],
                      ),
                  ],
                ),
              ),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  emptyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 검색창 + 필터 칩 줄. 콜백을 주지 않으면 모양만 보인다.
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.hint,
    this.filters = const [],
    this.selectedIndex = 0,
    this.onFilterSelected,
    this.onSearchChanged,
  });

  final String hint;
  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int>? onFilterSelected;
  final ValueChanged<String>? onSearchChanged;

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
            onChanged: onSearchChanged,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 20), hintText: hint),
          ),
        ),
        for (final (i, f) in filters.indexed)
          FilterChip(label: Text(f), selected: i == selectedIndex, onSelected: (_) => onFilterSelected?.call(i)),
      ],
    );
  }
}

/// 표 아래 페이지 넘김.
class Pager extends StatelessWidget {
  const Pager({super.key, required this.page, required this.pageCount, required this.summary, required this.onChanged});

  final int page;
  final int pageCount;
  final String summary;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$summary · ${page + 1} / $pageCount', style: const TextStyle(color: AppColors.textTertiary)),
        IconButton(
          tooltip: '이전 페이지',
          onPressed: page > 0 ? () => onChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: '다음 페이지',
          onPressed: page < pageCount - 1 ? () => onChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// [range] 가 비어 있으면 모든 날짜를 받는다. 끝나는 날은 그날 전체를 포함한다.
bool inDateRange(DateTime at, DateTimeRange? range) =>
    range == null || (!at.isBefore(range.start) && at.isBefore(range.end.add(const Duration(days: 1))));

/// 기간 선택 버튼.
class DateRangeFilter extends StatelessWidget {
  const DateRangeFilter({super.key, required this.range, required this.onChanged});

  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onChanged;

  @override
  Widget build(BuildContext context) {
    final r = range;
    String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2026, 1, 1),
              lastDate: DateTime(2027, 12, 31),
              initialDateRange: r,
            );
            if (picked != null) onChanged(picked);
          },
          icon: const Icon(Icons.date_range, size: 18),
          label: Text(r == null ? '전체 기간' : '${day(r.start)} ~ ${day(r.end)}'),
        ),
        if (r != null)
          IconButton(
            tooltip: '기간 지우기',
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.close, size: 18),
          ),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 아직 API 가 없는 버튼을 눌렀을 때 안내.
void showNotConnected(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('아직 API 가 연결되지 않았습니다.')));
}

/// 확인/취소 대화상자. 확인을 누르면 true.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '확인',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.up) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 짧은 안내 메시지.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
