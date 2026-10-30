import 'package:flutter/material.dart';

import 'admin_shell.dart';
import 'theme.dart';

void main() {
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
      home: const AdminShell(),
    );
  }
}
