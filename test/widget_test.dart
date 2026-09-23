import 'package:flutter_test/flutter_test.dart';
import 'package:near_kirana/main.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_mock.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
  });

  testWidgets('app boots with the router widget', (tester) async {
    FirebaseUtils.setFirestore(FakeFirebaseFirestore());
    await tester.pumpWidget(const NearKiranaApp());
    expect(find.byType(NearKiranaApp), findsOneWidget);
  });
}
