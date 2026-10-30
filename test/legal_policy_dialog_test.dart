import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:near_kirana/language_provider.dart';
import 'package:near_kirana/widgets/legal_policy_dialog.dart';

void main() {
  testWidgets('LegalPolicyDialog renders Privacy Policy and Terms tabs', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LegalPolicyDialog(initialTabIndex: 0),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Header
    expect(find.text('NearKirana Legal & Compliance'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsAtLeastNWidgets(1));
    expect(find.text('Terms of Service'), findsAtLeastNWidgets(1));

    // Verify Privacy Policy content
    expect(find.text('1. Overview'), findsOneWidget);
    expect(find.text('2. Information We Collect'), findsOneWidget);

    // Scroll and verify permissions
    await tester.scrollUntilVisible(
      find.text('3. Device Permissions & Purpose Justification'),
      50.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('3. Device Permissions & Purpose Justification'), findsOneWidget);

    // Switch to Terms of Service tab
    await tester.tap(find.text('Terms of Service').first);
    await tester.pumpAndSettle();

    // Verify Terms of Service content
    expect(find.text('1. Acceptance of Terms'), findsOneWidget);
    expect(find.text('2. Store Ownership & Product Pricing'), findsOneWidget);
  });
}
