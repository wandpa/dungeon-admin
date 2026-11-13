import 'package:flutter/material.dart';

import '../live_api.dart';
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
  String? _error = takeLiveSessionMessage(); // 로그인이 만료되어 돌아왔으면 알려 준다

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
                  const Text('던전우상향', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  const Text('관리자', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                  const SizedBox(height: 20),
                  // 비밀번호 관리자가 채울 수 있게 아이디·비밀번호로 묶는다.
                  AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _id,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(labelText: '아이디'),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(labelText: '비밀번호'),
                        ),
                      ],
                    ),
                  ),
                  // 오류가 생기면 화면 읽기 프로그램도 읽어 준다.
                  Semantics(
                    liveRegion: true,
                    child: _error == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                          ),
                  ),
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
