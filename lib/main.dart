import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_shell.dart';
import 'mock_admin.dart';
import 'mock_data.dart';
import 'pages/login_page.dart';
import 'theme.dart';

/// 로그인 직후 시작 화면을 보여 줄지. 앱 실행 때만 켠다.
bool showStartScreen = false;

void main() {
  useLiveData.value = true; // 회원 목록·모니터링은 테스트 DB 를 본다
  showStartScreen = true;
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '던전우상향 관리자',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ValueListenableBuilder(
        valueListenable: signedInAdmin,
        builder: (context, admin, _) => admin == null ? const LoginPage() : const _SignedIn(),
      ),
    );
  }
}

/// 로그인 뒤 1초 동안 시작 화면을 덮어 둔다. 그동안 뒤에서 첫 화면이 조회를 마친다.
class _SignedIn extends StatefulWidget {
  const _SignedIn();

  @override
  State<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<_SignedIn> {
  bool _starting = showStartScreen;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_starting) {
      _timer = Timer(const Duration(seconds: 1), () => setState(() => _starting = false));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const AdminShell(),
        if (_starting)
          Material(
            color: AppColors.background,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/admin_icon.png', width: 96, height: 96),
                  const SizedBox(height: 16),
                  const Text(
                    '던전 관리자',
                    style: TextStyle(color: AppColors.brand, fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
