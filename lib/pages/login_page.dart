import 'package:flutter/material.dart';

import '../mock_admin.dart';
import '../theme.dart';
import '../widgets/admin_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final error = signIn(_id.text, _password.text);
    if (error != null) setState(() => _error = error);
  }

  void _fill(AdminUser a) => setState(() {
    _id.text = a.loginId; // 비밀번호는 직접 입력한다
    _password.clear();
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset('assets/admin_icon.png', width: 48, height: 48),
                  ),
                  const SizedBox(height: 8),
                  const Text('던전우상향', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const Text('관리자', style: TextStyle(color: AppColors.accent, fontSize: 13)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _id,
                    decoration: const InputDecoration(hintText: '아이디'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(hintText: '비밀번호'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: AppColors.up, fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _submit, child: const Text('로그인')),
                  const SizedBox(height: 16),
                  const Text('계정을 고르고 비밀번호를 입력하세요.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in mockAdmins.where((a) => a.active))
                        ActionChip(
                          label: Text(a.role.label, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _fill(a),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
