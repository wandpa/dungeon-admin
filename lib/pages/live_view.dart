import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// 테스트 DB 값을 받아 그린다. 실패하면 샘플로 채우지 않고 오류와 다시 시도 버튼을 보여 준다.
class LiveLoader<T> extends StatefulWidget {
  const LiveLoader({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<LiveLoader<T>> createState() => _LiveLoaderState<T>();
}

class _LiveLoaderState<T> extends State<LiveLoader<T>> {
  late Future<T> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${snapshot.error}', style: const TextStyle(color: AppColors.up)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => setState(() => _future = widget.load()), child: const Text('다시 시도')),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(padding: EdgeInsets.all(24), child: LinearProgressIndicator());
        }
        return widget.builder(context, snapshot.requireData);
      },
    );
  }
}

/// 검색 입력이 멈춘 뒤에만 서버에 묻는다.
class SearchDebounce {
  Timer? _timer;

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), action);
  }

  void dispose() => _timer?.cancel();
}

/// 서버 페이지 이동.
class LivePager extends StatelessWidget {
  const LivePager({
    super.key,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.onPage,
    this.unit = '건',
  });

  final int total;
  final int page; // 1부터
  final int pageSize;
  final ValueChanged<int> onPage;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final pages = (total / pageSize).ceil().clamp(1, 1 << 30);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('총 $total$unit · $page / $pages', style: const TextStyle(color: AppColors.textTertiary)),
        IconButton(
          tooltip: '이전 페이지',
          onPressed: page > 1 ? () => onPage(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: '다음 페이지',
          onPressed: page < pages ? () => onPage(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
