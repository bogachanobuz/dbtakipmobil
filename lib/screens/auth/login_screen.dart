import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/note_drafts.dart';
import '../../data/site_session.dart';
import '../../demo/demo_account.dart';
import '../../screens/program/program_screen.dart';
import '../../theme/db_theme.dart';
import '../../widgets/db_logo.dart';
import '../../widgets/lip_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (_busy) return;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'E-posta ve şifre gerekli.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (DemoAccount.matches(email, password)) {
      await SiteSession.instance.clear();
      await prefs.setBool(DemoAccount.sessionKey, true);
      await prefs.setBool(SiteSession.liveKey, false);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ProgramScreen()),
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final error = await SiteSession.instance.login(email, password);
      if (!mounted) return;
      if (error != null) {
        setState(() {
          _busy = false;
          _error = error;
        });
        return;
      }
      await prefs.setBool(DemoAccount.sessionKey, true);
      await prefs.setBool(SiteSession.liveKey, true);
      final profile = await SiteSession.instance.profile();
      final account = (profile?.email.trim().isNotEmpty ?? false) ? profile!.email : email;
      await NoteDrafts.instance.rememberAccount(account);
      await NoteDrafts.instance.flushCurrent();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ProgramScreen(live: true)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Siteye bağlanılamadı.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: DbLogo(height: 48)),
              const SizedBox(height: 36),
              Text(
                'Tekrar hoş geldin.',
                style: DbText.style(
                  size: 32,
                  weight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Öğrenci hesabınla programa gir.',
                style: DbText.style(
                  size: 16,
                  weight: FontWeight.w600,
                  color: DbColors.muted,
                ),
              ),
              const SizedBox(height: 28),
              _Field(
                controller: _email,
                hint: 'E-posta veya kullanıcı adı',
                icon: Icons.person_rounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _password,
                hint: 'Şifre',
                icon: Icons.lock_rounded,
                obscure: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                trailing: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: DbColors.muted,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: DbText.style(
                    size: 14,
                    weight: FontWeight.w700,
                    color: DbColors.red,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              LipButton(label: _busy ? 'GİRİLİYOR' : 'GİRİŞ YAP', onPressed: _submit),
              const SizedBox(height: 8),
              const SizedBox(height: 12),
              Text(
                'Demo hesap\n${DemoAccount.username}  ·  ${DemoAccount.password}\nSite hesabın da aynı alandan girer.',
                textAlign: TextAlign.center,
                style: DbText.style(
                  size: 14,
                  weight: FontWeight.w700,
                  color: DbColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.trailing,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? trailing;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: DbText.style(size: 16, weight: FontWeight.w700),
      cursorColor: DbColors.navy,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: DbText.style(
          size: 15,
          weight: FontWeight.w600,
          color: const Color(0xFF9AA3B2),
        ),
        prefixIcon: Icon(icon, color: DbColors.navy),
        suffixIcon: trailing,
        filled: true,
        fillColor: DbColors.mist,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DbColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DbColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DbColors.navy, width: 2),
        ),
      ),
    );
  }
}
