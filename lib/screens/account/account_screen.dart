import 'package:flutter/material.dart';

import '../../demo/demo_account.dart';
import '../../theme/db_theme.dart';
import '../../widgets/lip_button.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final TextEditingController _name;
  late final TextEditingController _surname;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _bio;
  late final TextEditingController _current;
  late final TextEditingController _next;
  late final TextEditingController _again;
  String? _note;
  bool _noteIsError = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: DemoAccount.firstName);
    _surname = TextEditingController(text: DemoAccount.surname);
    _email = TextEditingController(text: DemoAccount.email);
    _phone = TextEditingController(text: DemoAccount.phone);
    _bio = TextEditingController();
    _current = TextEditingController();
    _next = TextEditingController();
    _again = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    _email.dispose();
    _phone.dispose();
    _bio.dispose();
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  void _save() {
    final changingPassword = _current.text.isNotEmpty ||
        _next.text.isNotEmpty ||
        _again.text.isNotEmpty;
    if (changingPassword) {
      if (_current.text != DemoAccount.password) {
        setState(() {
          _noteIsError = true;
          _note = 'Mevcut şifre hatalı.';
        });
        return;
      }
      if (_next.text.length < 6) {
        setState(() {
          _noteIsError = true;
          _note = 'Yeni şifre en az 6 karakter olmalı.';
        });
        return;
      }
      if (_next.text != _again.text) {
        setState(() {
          _noteIsError = true;
          _note = 'Yeni şifreler aynı değil.';
        });
        return;
      }
    }
    setState(() {
      _noteIsError = false;
      _note = 'Bilgiler bu ekranda duruyor.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final initials = '${_name.text.isEmpty ? 'D' : _name.text[0]}${_surname.text.isEmpty ? '' : _surname.text[0]}'
        .toUpperCase();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: DbColors.ink,
        title: Text('Hesabım', style: DbText.style(size: 18, weight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: DbColors.navy,
                child: Text(
                  initials,
                  style: DbText.style(size: 18, weight: FontWeight.w900, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_name.text} ${_surname.text}'.trim(),
                      style: DbText.style(size: 20, weight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DemoAccount.className,
                      style: DbText.style(size: 14, weight: FontWeight.w700, color: DbColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _label('Ad'),
          _box(_name, 'Ad'),
          const SizedBox(height: 12),
          _label('Soyad'),
          _box(_surname, 'Soyad'),
          const SizedBox(height: 12),
          _label('E-posta'),
          _box(_email, 'E-posta', type: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _label('Telefon'),
          _box(_phone, 'Telefon', type: TextInputType.phone),
          const SizedBox(height: 12),
          _label('Hakkımda'),
          _box(_bio, 'Kendinden bahset...', lines: 3),
          const SizedBox(height: 22),
          Text('Şifre', style: DbText.style(size: 18, weight: FontWeight.w900)),
          const SizedBox(height: 12),
          _box(_current, 'Mevcut şifre', secret: true),
          const SizedBox(height: 12),
          _box(_next, 'Yeni şifre', secret: true),
          const SizedBox(height: 12),
          _box(_again, 'Yeni şifre tekrar', secret: true),
          if (_note != null) ...[
            const SizedBox(height: 14),
            Text(
              _note!,
              style: DbText.style(
                size: 14,
                weight: FontWeight.w800,
                color: _noteIsError ? DbColors.red : DbColors.navy,
              ),
            ),
          ],
          const SizedBox(height: 18),
          LipButton(label: 'KAYDET', onPressed: _save),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.muted)),
    );
  }

  Widget _box(
    TextEditingController controller,
    String hint, {
    TextInputType? type,
    bool secret = false,
    int lines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: secret,
      minLines: lines,
      maxLines: secret ? 1 : lines,
      onChanged: (_) => setState(() {}),
      style: DbText.style(size: 16, weight: FontWeight.w700),
      cursorColor: DbColors.navy,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: DbText.style(size: 15, weight: FontWeight.w600, color: const Color(0xFF9AA3B2)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
