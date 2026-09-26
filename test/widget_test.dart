import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dbtakip/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch shows the welcome story', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DbTakipApp(showWelcome: true));

    expect(find.textContaining('Günün programı'), findsOneWidget);
    expect(find.text('DEVAM'), findsOneWidget);
    expect(find.text('ZATEN HESABIM VAR'), findsOneWidget);

    await tester.tap(find.text('DEVAM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Çözdükçe'), findsOneWidget);

    await tester.tap(find.text('DEVAM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('HADİ BAŞLAYALIM'), findsOneWidget);

    await tester.tap(find.text('HADİ BAŞLAYALIM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Tekrar hoş geldin.'), findsOneWidget);
    expect(find.text('GİRİŞ YAP'), findsOneWidget);
  });
}
