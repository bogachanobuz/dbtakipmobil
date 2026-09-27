abstract final class DemoAccount {
  static const firstName = 'Demo';
  static const surname = 'Öğrenci';
  static const name = '$firstName $surname';
  static const email = 'demo@dbtakip.com';
  static const phone = '0555 000 00 00';
  static const className = '12. Sınıf';
  static const username = 'demo';
  static const password = 'demo123';
  static const sessionKey = 'demo_session_v1';

  static bool matches(String login, String passwordInput) {
    return login.trim().toLowerCase() == username &&
        passwordInput == password;
  }
}
