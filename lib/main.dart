import 'package:flutter/material.dart';

import 'admin_shell.dart';
import 'mock_admin.dart';
import 'mock_data.dart';
import 'pages/login_page.dart';
import 'theme.dart';

void main() {
  useLiveData.value = true; // 회원 목록·모니터링은 테스트 DB 를 본다
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
        builder: (context, admin, _) => admin == null ? const LoginPage() : const AdminShell(),
      ),
    );
  }
}
