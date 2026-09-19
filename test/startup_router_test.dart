import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aditya_kirana/cart_provider.dart';
import 'package:aditya_kirana/language_provider.dart';
import 'package:aditya_kirana/main.dart';
import 'package:aditya_kirana/shop_provider.dart';
import 'package:aditya_kirana/shop_selector_screen.dart';
import 'package:aditya_kirana/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });


  testWidgets('shows the shop selector when no shop is saved', (tester) async {
    final shopProvider = ShopProvider();
    await shopProvider.loadCurrentShop();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: shopProvider),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: const NearKiranaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ShopSelectorScreen), findsOneWidget);
  });

  testWidgets('shows the login screen when a shop is already saved', (tester) async {
    final shopProvider = ShopProvider();
    await shopProvider.setShop('SHOP_001', 'Aditya Kirana');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: shopProvider),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: const NearKiranaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
