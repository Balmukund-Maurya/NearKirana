import 'package:flutter_test/flutter_test.dart';
import 'package:near_kirana/main.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/cart_provider.dart';
import 'package:near_kirana/language_provider.dart';
import 'package:near_kirana/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {

  testWidgets('app boots with the router widget', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FirebaseUtils.setFirestore(FakeFirebaseFirestore());
    
    final shopProvider = ShopProvider();
    
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

    expect(find.byType(NearKiranaApp), findsOneWidget);
  });
}
