import 'package:flutter/material.dart';

import '../file_download.dart';
import '../mock_admin.dart' show AdminPermission, can;
import '../theme.dart';

const adminSideWidth = 470.0;

/// 아래 상태줄에 보여 줄 문구. 화면이 조회를 마치면 건수를 알린다.
final adminStatus = ValueNotifier('준비되었습니다.');

/// 표를 내보낸 뒤 부른다. 테스트 DB 화면이면 서버 활동 기록에 남긴다. (이름, 건수, 회원 GUID)
void Function(String name, int count, String? memberLiveId)? onAdminTableExported;

/// 실제로 파일을 내려받는 함수. 테스트에서 바꿔 끼운다.
@visibleForTesting
void Function(String fileName, String text) csvDownloader = downloadCsv;

/// 표가 아닌 목록도 같은 방식으로 CSV 를 내려받는다. 엑셀이 값을 수식으로 실행하지 않게 막고, 내보낸 기록을 남긴다.
void exportCsv(String name, List<String> columns, List<List<String>> rows, {String? memberLiveId}) {
  String cell(String v) {
    final safe = RegExp(r'^[=+\-@]').hasMatch(v) && double.tryParse(v.replaceAll(',', '')) == null ? "'$v" : v;
    return '"${safe.replaceAll('"', '""')}"';
  }

  final lines = [
    columns.map(cell).join(','),
    for (final r in rows) r.map(cell).join(','),
  ];
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
  csvDownloader('${name}_$stamp.csv', lines.join('\r\n'));
  adminStatus.value = '$name ${rows.length}건을 내보냈습니다.';
  onAdminTableExported?.call(name, rows.length, memberLiveId);
}

/// 관리 화면 공통 틀: 제목줄(제목·설명·우측 버튼), 본문.
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.title,
    required this.description,
    required this.children,
    this.actions = const [],
    this.side,
  });

  final String title;
  final String description;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? side; // 본문 오른쪽에 붙는 패널

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.page, vertical: 12),
          child: Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(description, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpace.page),
                  children: [
                    for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: AppSpace.gap), c],
                  ],
                ),
              ),
              if (side != null)
                Container(
                  width: adminSideWidth,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(left: BorderSide(color: AppColors.border)),
                  ),
                  child: SingleChildScrollView(padding: const EdgeInsets.all(AppSpace.gap), child: side),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 테두리 있는 카드.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.title, this.padding = const EdgeInsets.all(AppSpace.card)});

  final String? title;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Container 대신 Material 이어야 안쪽 ListTile 의 선택 배경·물결 효과가 보인다.
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
    this.columnSpacing = 16,
    this.onRowTap,
    this.onRowDoubleTap,
    this.highlightedRow,
    this.buttonColumns = const {},
    this.selected,
    this.onSelectChanged,
    this.onSelectAll,
    this.emptyText = '표시할 항목이 없습니다.',
    this.exportName,
    this.exportMemberLiveId,
  });

  final List<String> columns;
  /// 주면 표 위에 "엑셀 내보내기" 가 생긴다. 파일 이름 앞부분이다. 회원 내보내기 권한이 있어야 보인다.
  final String? exportName;
  final String? exportMemberLiveId; // 회원 한 명의 표면 그 회원 GUID. 열람 기록에 남는다
  final double columnSpacing;
  final List<List<Widget>> rows;
  final Set<int>? selected;
  final void Function(int index, bool selected)? onSelectChanged;
  final ValueChanged<bool>? onSelectAll;
  final String emptyText;
  final ValueChanged<int>? onRowTap;
  final ValueChanged<int>? onRowDoubleTap;
  final int? highlightedRow; // 오른쪽 패널에 보여 주는 줄
  final Set<int> buttonColumns; // 버튼이 있는 칸

  /// 화면에 그려진 칸의 글자를 그대로 모아 CSV 로 내려받는다. 가린 값은 가린 채로 나간다.
  void _export(BuildContext context) {
    final texts = <(int, int), List<String>>{};
    void collect(Element e, (int, int)? at) {
      final w = e.widget;
      final here = w is _TableCellMark ? (w.row, w.column) : at;
      if (here != null && w is RichText) {
        (texts[here] ??= []).add(w.text.toPlainText().replaceAll('\n', ' ').trim());
        return;
      }
      e.visitChildElements((c) => collect(c, here));
    }

    (context as Element).visitChildElements((c) => collect(c, null));
    final skip = {...buttonColumns};
    exportCsv(
      exportName!,
      [for (final (c, name) in columns.indexed) if (!skip.contains(c)) name],
      [
        for (var r = 0; r < rows.length; r++)
          [
            for (var c = 0; c < columns.length; c++)
              if (!skip.contains(c)) (texts[(r, c)] ?? const []).where((t) => t.isNotEmpty).join(' '),
          ],
      ],
      memberLiveId: exportMemberLiveId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectable = selected != null;
    final exportable = exportName != null && can(AdminPermission.exportMembers);
    return Panel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (exportable)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: TextButton.icon(
                    onPressed: rows.isEmpty ? null : () => _export(context),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: Text('엑셀 내보내기 ${rows.length}건', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  showCheckboxColumn: selectable,
                  dividerThickness: 1,
                  columnSpacing: columnSpacing,
                  border: const TableBorder(horizontalInside: BorderSide(color: AppColors.border)),
                  onSelectAll: selectable ? (v) => onSelectAll?.call(v ?? false) : null,
                  columns: [for (final c in columns) DataColumn(label: Text(c))],
                  rows: [
                    for (final (i, r) in rows.indexed)
                      DataRow(
                        selected: selected?.contains(i) ?? false,
                        color: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected) || i == highlightedRow
                              ? AppColors.brandSoft
                              : states.contains(WidgetState.hovered)
                              ? AppColors.surfaceSoft
                              : null,
                        ),
                        onSelectChanged: selectable ? (v) => onSelectChanged?.call(i, v ?? false) : null,
                        cells: [
                          // 버튼 칸에 두 번 누르기를 걸면 버튼 반응이 늦어진다.
                          for (final (c, cell) in r.indexed)
                            DataCell(
                              _TableCellMark(row: i, column: c, child: cell),
                              onTap: onRowTap == null || buttonColumns.contains(c) ? null : () => onRowTap!(i),
                              onDoubleTap: onRowDoubleTap == null || buttonColumns.contains(c)
                                  ? null
                                  : () => onRowDoubleTap!(i),
                            ),
                        ],
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
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 18), labelText: hint),
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
        Text('$summary · ${page + 1} / $pageCount', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusDot(color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// 상태 점. 가동·정지·문제 같은 상태를 화면 어디서나 같은 모양으로 보인다.
class StatusDot extends StatelessWidget {
  const StatusDot(this.color, {super.key, this.size = 7});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// 아직 API 가 없는 버튼을 눌렀을 때 안내.
/// 테스트 DB 연결 중인데 아직 샘플로 보여 주는 화면의 안내.
class SampleNotice extends StatelessWidget {
  const SampleNotice(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(AppRadius.control),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.warning, fontSize: 13))),
      ],
    ),
  );
}

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
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
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

/// 내보낼 때 칸 위치를 찾으려고 칸마다 감싼다. 화면에는 아무 영향이 없다.
class _TableCellMark extends StatelessWidget {
  const _TableCellMark({required this.row, required this.column, required this.child});

  final int row;
  final int column;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
