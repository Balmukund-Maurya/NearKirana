import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:near_kirana/cart_provider.dart';
import 'package:near_kirana/language_provider.dart';
import 'package:near_kirana/main.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/shop_selector_screen.dart';
import 'package:near_kirana/gateway_screen.dart';
import 'package:near_kirana/user_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'firebase_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    setupFirebaseAuthMocks();
    SharedPreferences.setMockInitialValues({});
    FirebaseUtils.setFirestore(FakeFirebaseFirestore());
  });

  testWidgets('shows GatewayScreen on initial launch when no phone is logged in', (tester) async {
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

    expect(find.byType(GatewayScreen), findsOneWidget);
  });

  testWidgets('routes to shop selector when customer role and phone are saved', (tester) async {
    SharedPreferences.setMockInitialValues({
      'global_phone': '9876543210',
      'app_role': 'customer',
    });

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

  testWidgets('routes to login screen when customer role, phone and shop are saved', (tester) async {
    SharedPreferences.setMockInitialValues({
      'global_phone': '9876543210',
      'app_role': 'customer',
      'current_shop_id': 'SHOP_001',
      'current_shop_name': 'Aditya Kirana',
    });

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

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
