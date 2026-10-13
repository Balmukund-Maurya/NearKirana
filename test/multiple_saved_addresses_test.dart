import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/user_provider.dart';
import 'package:near_kirana/saved_address_model.dart';
import 'package:near_kirana/address_selection_bottom_sheet.dart';
import 'firebase_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    setupFirebaseAuthMocks();
    SharedPreferences.setMockInitialValues({});
    FirebaseUtils.setFirestore(FakeFirebaseFirestore());
  });

  group('Feature 45 - SavedAddress Model Tests', () {
    test('creates SavedAddress with correct properties and formattedAddress', () {
      final address = SavedAddress(
        id: 'addr_1',
        title: 'My Sweet Home',
        address: 'Bhopal Central, MP',
        houseNo: 'Flat 402',
        landmark: 'Near Rose Garden',
        latitude: 23.259933,
        longitude: 77.412615,
        label: 'Home',
        isDefault: true,
      );

      expect(address.id, 'addr_1');
      expect(address.label, 'Home');
      expect(address.isDefault, isTrue);
      expect(address.formattedAddress, 'Flat 402, Bhopal Central, MP, Near Rose Garden');
      expect(address.icon, Icons.home_rounded);
    });

    test('serializes to and from Map accurately', () {
      final original = SavedAddress(
        id: 'addr_office',
        title: 'IT Park Office',
        address: 'Indore Bypass',
        houseNo: 'Tower B, 3rd Floor',
        landmark: 'Next to Tech Hub',
        latitude: 22.7196,
        longitude: 75.8577,
        label: 'Office',
        isDefault: false,
      );

      final map = original.toMap();
      final reconstituted = SavedAddress.fromMap(map);

      expect(reconstituted.id, original.id);
      expect(reconstituted.title, original.title);
      expect(reconstituted.address, original.address);
      expect(reconstituted.houseNo, original.houseNo);
      expect(reconstituted.landmark, original.landmark);
      expect(reconstituted.latitude, original.latitude);
      expect(reconstituted.longitude, original.longitude);
      expect(reconstituted.label, original.label);
      expect(reconstituted.isDefault, original.isDefault);
      expect(reconstituted.icon, Icons.business_rounded);
    });

    test('copyWith updates properties properly', () {
      final original = SavedAddress(
        id: 'addr_custom',
        title: 'Grandparents Home',
        address: 'Old Town, Bhopal',
        houseNo: '12',
        landmark: 'Main Temple',
        latitude: 23.25,
        longitude: 77.40,
        label: 'Other',
        isDefault: false,
      );

      final updated = original.copyWith(
        houseNo: '12-A',
        isDefault: true,
        label: 'Home',
      );

      expect(updated.id, original.id);
      expect(updated.houseNo, '12-A');
      expect(updated.isDefault, isTrue);
      expect(updated.label, 'Home');
      expect(updated.icon, Icons.home_rounded);
    });
  });

  group('Feature 45 - UserProvider Multiple Addresses CRUD & Default Management', () {
    test('adds multiple addresses (Home, Office, Other) and manages single default', () async {
      final provider = UserProvider();

      final home = SavedAddress(
        id: 'addr_home',
        title: 'Home Address',
        address: '10 Number Market, Bhopal',
        houseNo: 'H-21',
        landmark: 'Opposite State Bank',
        latitude: 23.23,
        longitude: 77.42,
        label: 'Home',
        isDefault: true,
      );

      final office = SavedAddress(
        id: 'addr_office',
        title: 'Headquarters',
        address: 'MP Nagar Zone 1, Bhopal',
        houseNo: 'Plot 45',
        landmark: 'Near City Mall',
        latitude: 23.24,
        longitude: 77.43,
        label: 'Office',
        isDefault: false,
      );

      final other = SavedAddress(
        id: 'addr_other',
        title: 'Farm House',
        address: 'Kolar Road, Bhopal',
        houseNo: 'Farm 3',
        landmark: 'Bypass Road',
        latitude: 23.18,
        longitude: 77.41,
        label: 'Other',
        isDefault: false,
      );

      await provider.saveAddressModel(home);
      await provider.saveAddressModel(office);
      await provider.saveAddressModel(other);

      expect(provider.savedAddressesList.length, 3);
      expect(provider.savedAddressesList.map((a) => a.label).toList(), ['Home', 'Office', 'Other']);
      expect(provider.savedAddressesList.where((a) => a.isDefault).length, 1);
      expect(provider.savedAddressesList.firstWhere((a) => a.isDefault).id, 'addr_home');

      // Now set Office as default
      await provider.setDefaultAddress('addr_office');
      expect(provider.savedAddressesList.where((a) => a.isDefault).length, 1);
      expect(provider.savedAddressesList.firstWhere((a) => a.isDefault).id, 'addr_office');
      expect(provider.savedAddressesList.firstWhere((a) => a.id == 'addr_home').isDefault, isFalse);
    });

    test('edits an existing address in-place', () async {
      final provider = UserProvider();
      final initial = SavedAddress(
        id: 'addr_edit_test',
        title: 'Apartment',
        address: 'Arera Colony',
        houseNo: 'A-10',
        landmark: 'Market',
        latitude: 23.21,
        longitude: 77.44,
        label: 'Home',
        isDefault: true,
      );

      await provider.saveAddressModel(initial);
      expect(provider.savedAddressesList.length, 1);
      expect(provider.savedAddressesList.first.houseNo, 'A-10');

      final updated = initial.copyWith(
        houseNo: 'A-10, Top Floor, Penthouse',
        landmark: 'Near Metro Station',
      );

      await provider.saveAddressModel(updated);
      expect(provider.savedAddressesList.length, 1);
      expect(provider.savedAddressesList.first.houseNo, 'A-10, Top Floor, Penthouse');
      expect(provider.savedAddressesList.first.landmark, 'Near Metro Station');
    });

    test('deleting default address assigns new default if addresses remain', () async {
      final provider = UserProvider();
      final addr1 = SavedAddress(
        id: 'addr_1',
        title: 'Home',
        address: 'Address 1',
        houseNo: '1',
        latitude: 23.2,
        longitude: 77.4,
        label: 'Home',
        isDefault: true,
      );
      final addr2 = SavedAddress(
        id: 'addr_2',
        title: 'Office',
        address: 'Address 2',
        houseNo: '2',
        latitude: 23.3,
        longitude: 77.5,
        label: 'Office',
        isDefault: false,
      );

      await provider.saveAddressModel(addr1);
      await provider.saveAddressModel(addr2);
      expect(provider.savedAddressesList.length, 2);

      await provider.deleteAddressById('addr_1');
      expect(provider.savedAddressesList.length, 1);
      expect(provider.savedAddressesList.first.id, 'addr_2');
      expect(provider.savedAddressesList.first.isDefault, isTrue);
    });
  });

  group('Feature 45 - Checkout Address Selection & Serviceability Validation', () {
    test('validates address inside store delivery radius as serviceable', () {
      final provider = UserProvider();
      // Configure Store at Bhopal coordinates with 5km delivery radius
      provider.setStoreLocation(23.259933, 77.412615);
      provider.setDeliveryRadius(5.0);

      // Home address 0.5 km away from store
      final nearAddress = SavedAddress(
        id: 'addr_near',
        title: 'Nearby Residence',
        address: 'Main Street, 2 blocks away',
        houseNo: 'B-12',
        latitude: 23.262000,
        longitude: 77.415000,
        label: 'Home',
      );

      final result = provider.evaluateAddressServiceability(nearAddress);
      expect(result.isServiceable, isTrue);
      expect(result.distanceKm, lessThan(1.0));
      expect(result.deliveryRadiusKm, 5.0);
      expect(result.errorMessage, isNull);
    });

    test('validates address outside store delivery radius as unserviceable with exact distance', () {
      final provider = UserProvider();
      // Store at Bhopal with 5.0 km radius
      provider.setStoreLocation(23.259933, 77.412615);
      provider.setDeliveryRadius(5.0);

      // Far office address ~20 km away
      final farAddress = SavedAddress(
        id: 'addr_far',
        title: 'Far Office Hub',
        address: 'Industrial Sector 5',
        houseNo: 'Block 9',
        latitude: 23.400000,
        longitude: 77.550000,
        label: 'Office',
      );

      final result = provider.evaluateAddressServiceability(farAddress);
      expect(result.isServiceable, isFalse);
      expect(result.distanceKm, greaterThan(15.0));
      expect(result.errorMessage, contains('Outside delivery radius'));
    });

    test('selectAddressForCheckout updates active address and recalculates serviceability dynamically', () async {
      final provider = UserProvider();
      provider.setStoreLocation(23.259933, 77.412615);
      provider.setDeliveryRadius(5.0);

      final homeAddress = SavedAddress(
        id: 'addr_home',
        title: 'Home',
        address: 'Local Colony',
        houseNo: '101',
        latitude: 23.261000,
        longitude: 77.413000,
        label: 'Home',
        isDefault: true,
      );

      final distantOffice = SavedAddress(
        id: 'addr_office',
        title: 'Outstation Office',
        address: 'Highway Corner',
        houseNo: 'Off-5',
        latitude: 23.450000,
        longitude: 77.600000,
        label: 'Office',
        isDefault: false,
      );

      await provider.saveAddressModel(homeAddress);
      await provider.saveAddressModel(distantOffice);

      // 1. Customer selects Home address at checkout
      await provider.selectAddressForCheckout(homeAddress);
      expect(provider.activeAddress?.id, 'addr_home');
      expect(provider.addressLabel, 'Home');
      expect(provider.isServiceable, isTrue);
      expect(provider.serviceabilityError, isNull);

      // 2. Customer switches to distant Office address at checkout
      await provider.selectAddressForCheckout(distantOffice);
      expect(provider.activeAddress?.id, 'addr_office');
      expect(provider.addressLabel, 'Office');
      expect(provider.isServiceable, isFalse);
      expect(provider.serviceabilityError, contains('Outside delivery radius'));
    });
  });

  group('Feature 45 - UI Widgets: AddressSelectionBottomSheet & Selection Flow', () {
    testWidgets('renders saved addresses and allows selection at checkout', (tester) async {
      final userProvider = UserProvider();
      userProvider.setStoreLocation(23.259933, 77.412615);
      userProvider.setDeliveryRadius(5.0);

      final homeAddress = SavedAddress(
        id: 'addr_home',
        title: 'Home',
        address: 'Shivaji Nagar, Bhopal',
        houseNo: 'Plot 14',
        latitude: 23.261000,
        longitude: 77.413000,
        label: 'Home',
        isDefault: true,
      );

      final officeAddress = SavedAddress(
        id: 'addr_office',
        title: 'Office',
        address: 'MP Nagar, Bhopal',
        houseNo: 'Tech Park 2',
        latitude: 23.263000,
        longitude: 77.414000,
        label: 'Office',
        isDefault: false,
      );

      await userProvider.saveAddressModel(homeAddress);
      await userProvider.saveAddressModel(officeAddress);

      SavedAddress? chosenAddress;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<UserProvider>.value(
            value: userProvider,
            child: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    chosenAddress = await AddressSelectionBottomSheet.show(
                      context,
                      isCheckoutMode: true,
                    );
                  },
                  child: const Text('Open Address Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap to open bottom sheet
      await tester.tap(find.text('Open Address Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet title and addresses are displayed
      expect(find.text('Delivery Addresses'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Office'), findsOneWidget);
      expect(find.text('DEFAULT'), findsOneWidget);
      expect(find.text('Add New'), findsOneWidget);

      // Tap on Office address to select it for checkout
      await tester.tap(find.text('Office'));
      await tester.pumpAndSettle();

      // Bottom sheet should close and chosenAddress should be Office
      expect(chosenAddress, isNotNull);
      expect(chosenAddress?.id, 'addr_office');
      expect(userProvider.activeAddress?.id, 'addr_office');
      expect(userProvider.addressLabel, 'Office');
    });
  });
}
