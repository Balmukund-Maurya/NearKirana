import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:near_kirana/language_provider.dart';
import 'package:near_kirana/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 65: Complete Localization - Dictionary & Key Parity Tests', () {
    test('English dictionary contains all required checkout, error, status, invoice, empty state & admin strings', () {
      final loc = lookupAppLocalizations(const Locale('en'));

      // Checkout & Bill details
      expect(loc.bill_details, 'Bill Details');
      expect(loc.item_total, 'Item Total');
      expect(loc.delivery_charges, 'Delivery Charges');
      expect(loc.free_delivery_label, 'FREE');
      expect(loc.platform_fee, 'Platform Fee');
      expect(loc.coupon_discount, 'Coupon Discount');
      expect(loc.total_savings, 'Your Total Savings');
      expect(loc.to_pay, 'To Pay');
      expect(loc.payment_method, 'Payment Method');
      expect(loc.cash_on_delivery, 'Cash on Delivery (COD)');
      expect(loc.pay_online_upi, 'Pay Online / UPI');
      expect(loc.khata_pay, 'Pay with Khata (Udhaar)');
      expect(loc.deliver_to, 'Deliver To');
      expect(loc.change_address_btn, 'Change');
      expect(loc.add_address_btn, 'Add Address');
      expect(loc.est_delivery_time, 'Estimated Delivery in 15-30 Mins');
      expect(loc.order_processing, 'Processing your order...');
      expect(loc.back_to_cart, 'Back to Cart');
      expect(loc.order_confirmed, 'Order Confirmed!');

      // Form validation errors
      expect(loc.err_invalid_phone, 'Please enter a valid 10-digit mobile number');
      expect(loc.err_name_required, 'Name is required');
      expect(loc.err_enter_address, 'Please enter complete address');
      expect(loc.err_invalid_pin, 'Please enter a valid PIN');
      expect(loc.err_min_amount, 'Minimum order amount is required');
      expect(loc.err_stock_negative, 'Stock cannot be negative');
      expect(loc.err_price_zero, 'Price must be greater than zero');
      expect(loc.err_enter_quantity, 'Please enter valid quantity');
      expect(loc.err_select_payment, 'Please select a payment method');
      expect(loc.err_empty_cart_checkout, 'Cannot checkout with an empty cart');

      // Order statuses & notifications
      expect(loc.order_status_pending, 'Pending');
      expect(loc.order_status_accepted, 'Accepted');
      expect(loc.order_status_packing, 'Packing');
      expect(loc.order_status_ready, 'Ready');
      expect(loc.order_status_out, 'Out for Delivery');
      expect(loc.order_status_delivered, 'Delivered');
      expect(loc.order_status_cancelled, 'Cancelled');
      expect(loc.order_status_rejected, 'Rejected');
      expect(loc.notif_order_placed_title, 'Order Placed!');
      expect(loc.notif_order_placed_body, 'Your order has been placed successfully.');
      expect(loc.notif_out_for_delivery_body, 'Your order is on the way!');
      expect(loc.notif_delivered_body, 'Your order has been delivered. Thank you!');
      expect(loc.item_added_snack, 'Item added to cart');
      expect(loc.item_removed_snack, 'Item removed from cart');
      expect(loc.cart_cleared_snack, 'Cart cleared');

      // Digital invoices & receipts
      expect(loc.tax_invoice_title, 'Tax Invoice / Bill');
      expect(loc.invoice_no_lbl, 'Invoice No');
      expect(loc.invoice_date_lbl, 'Invoice Date');
      expect(loc.billed_to_lbl, 'Billed To');
      expect(loc.item_col, 'Item');
      expect(loc.qty_col, 'Qty');
      expect(loc.rate_col, 'Rate');
      expect(loc.amt_col, 'Amount');
      expect(loc.grand_total_lbl, 'Grand Total');
      expect(loc.thank_you_shopping, 'Thank you for shopping with us!');
      expect(loc.download_pdf_btn, 'Download Invoice PDF');
      expect(loc.print_receipt_btn, 'Print Receipt');
      expect(loc.share_invoice_btn, 'Share Invoice');
      expect(loc.order_summary, 'Order Summary');
      expect(loc.taxes_included, 'Taxes included');

      // Empty states
      expect(loc.empty_cart_title, 'Your Cart is Empty');
      expect(loc.empty_cart_subtitle, "Looks like you haven't added anything yet.");
      expect(loc.start_shopping_btn, 'Start Shopping');
      expect(loc.order_by_voice_btn, 'Order by Voice');
      expect(loc.no_orders_title, 'No Orders Placed Yet');
      expect(loc.no_orders_subtitle, 'Your past orders and live tracking will appear here.');
      expect(loc.no_products_found_title, 'No Products Found');
      expect(loc.no_products_found_subtitle, 'Try searching with a different name or category.');
      expect(loc.no_notifications_title, 'No Notifications');
      expect(loc.no_notifications_subtitle, 'Updates about your orders will show up here.');

      // Admin workflows
      expect(loc.admin_overview, 'Store Overview');
      expect(loc.admin_inventory, 'Inventory & Stock');
      expect(loc.admin_orders, 'Orders & Billing');
      expect(loc.admin_khata, 'Customer Khata');
      expect(loc.admin_analytics, 'Sales & Analytics');
      expect(loc.admin_settings, 'Store Settings');
      expect(loc.mark_as_packed, 'Mark as Packed');
      expect(loc.mark_as_delivered, 'Mark as Delivered');
      expect(loc.assign_delivery_boy, 'Assign Delivery Boy');
      expect(loc.out_for_delivery_btn, 'Send Out for Delivery');
      expect(loc.confirm_payment_btn, 'Confirm Payment');
      expect(loc.stock_updated_snack, 'Stock updated successfully');
    });

    test('Hindi (Devanagari) dictionary contains all translated keys without English fallbacks', () {
      final loc = lookupAppLocalizations(const Locale('hi'));

      // Checkout & Bill details
      expect(loc.bill_details, 'बिल विवरण');
      expect(loc.item_total, 'आइटम का कुल');
      expect(loc.delivery_charges, 'डिलीवरी शुल्क');
      expect(loc.free_delivery_label, 'मुफ़्त');
      expect(loc.platform_fee, 'प्लेटफ़ॉर्म शुल्क');
      expect(loc.coupon_discount, 'कूपन छूट');
      expect(loc.total_savings, 'आपकी कुल बचत');
      expect(loc.to_pay, 'कुल भुगतान');
      expect(loc.payment_method, 'भुगतान का तरीका');
      expect(loc.cash_on_delivery, 'कैश ऑन डिलीवरी (नकद)');
      expect(loc.pay_online_upi, 'ऑनलाइन / यूपीआई से भुगतान करें');
      expect(loc.khata_pay, 'खाता (उधार) से भुगतान करें');
      expect(loc.deliver_to, 'डिलीवरी का पता');
      expect(loc.change_address_btn, 'बदलें');
      expect(loc.add_address_btn, 'पता जोड़ें');
      expect(loc.est_delivery_time, 'अनुमानित डिलीवरी 15-30 मिनट में');
      expect(loc.order_processing, 'आपका ऑर्डर प्रोसेस हो रहा है...');
      expect(loc.back_to_cart, 'कार्ट पर वापस जाएं');
      expect(loc.order_confirmed, 'ऑर्डर कन्फर्म हुआ!');

      // Form validation errors
      expect(loc.err_invalid_phone, 'कृपया एक मान्य 10-अंकीय मोबाइल नंबर दर्ज करें');
      expect(loc.err_name_required, 'नाम अनिवार्य है');
      expect(loc.err_enter_address, 'कृपया पूरा पता दर्ज करें');
      expect(loc.err_invalid_pin, 'कृपया एक मान्य पिन दर्ज करें');
      expect(loc.err_min_amount, 'न्यूनतम ऑर्डर राशि आवश्यक है');
      expect(loc.err_stock_negative, 'स्टॉक नकारात्मक नहीं हो सकता');
      expect(loc.err_price_zero, 'कीमत शून्य से अधिक होनी चाहिए');
      expect(loc.err_enter_quantity, 'कृपया मान्य मात्रा दर्ज करें');
      expect(loc.err_select_payment, 'कृपया भुगतान का तरीका चुनें');
      expect(loc.err_empty_cart_checkout, 'खाली कार्ट के साथ चेकआउट नहीं किया जा सकता');

      // Order statuses & notifications
      expect(loc.order_status_pending, 'लंबित');
      expect(loc.order_status_accepted, 'स्वीकृत');
      expect(loc.order_status_packing, 'पैकिंग जारी');
      expect(loc.order_status_ready, 'तैयार');
      expect(loc.order_status_out, 'रास्ते में');
      expect(loc.order_status_delivered, 'डिलीवर हो गया');
      expect(loc.order_status_cancelled, 'रद्द किया गया');
      expect(loc.order_status_rejected, 'अस्वीकृत');
      expect(loc.notif_order_placed_title, 'ऑर्डर दर्ज हुआ!');
      expect(loc.item_added_snack, 'आइटम कार्ट में जोड़ा गया');
      expect(loc.item_removed_snack, 'आइटम कार्ट से हटाया गया');
      expect(loc.cart_cleared_snack, 'कार्ट खाली कर दिया गया');

      // Digital invoices & receipts
      expect(loc.tax_invoice_title, 'टैक्स इनवॉइस / बिल');
      expect(loc.invoice_no_lbl, 'इनवॉइस संख्या');
      expect(loc.invoice_date_lbl, 'इनवॉइस दिनांक');
      expect(loc.billed_to_lbl, 'ग्राहक विवरण');
      expect(loc.item_col, 'वस्तु');
      expect(loc.qty_col, 'मात्रा');
      expect(loc.rate_col, 'दर');
      expect(loc.amt_col, 'रकम');
      expect(loc.grand_total_lbl, 'कुल योग');
      expect(loc.thank_you_shopping, 'हमारे साथ खरीदारी करने के लिए धन्यवाद!');
      expect(loc.download_pdf_btn, 'इनवॉइस PDF डाउनलोड करें');
      expect(loc.print_receipt_btn, 'रसीद प्रिंट करें');
      expect(loc.share_invoice_btn, 'इनवॉइस साझा करें');
      expect(loc.order_summary, 'ऑर्डर सारांश');
      expect(loc.taxes_included, 'कर शामिल');

      // Empty states
      expect(loc.empty_cart_title, 'आपकी कार्ट खाली है');
      expect(loc.start_shopping_btn, 'खरीदारी शुरू करें');
      expect(loc.order_by_voice_btn, 'बोलकर सामान मंगाएं');
      expect(loc.no_orders_title, 'अभी तक कोई ऑर्डर नहीं दिया गया');
      expect(loc.no_products_found_title, 'कोई उत्पाद नहीं मिला');
      expect(loc.no_notifications_title, 'कोई सूचना नहीं');

      // Admin workflows
      expect(loc.admin_overview, 'दुकान अवलोकन');
      expect(loc.admin_inventory, 'इन्वेंट्री और स्टॉक');
      expect(loc.admin_orders, 'ऑर्डर और बिलिंग');
      expect(loc.admin_khata, 'ग्राहक खाता');
      expect(loc.admin_analytics, 'बिक्री और विश्लेषण');
      expect(loc.admin_settings, 'दुकान सेटिंग्स');
      expect(loc.mark_as_packed, 'पैक के रूप में चिह्नित करें');
      expect(loc.mark_as_delivered, 'डिलीवर के रूप में चिह्नित करें');
      expect(loc.assign_delivery_boy, 'डिलीवरी बॉय असाइन करें');
      expect(loc.out_for_delivery_btn, 'डिलीवरी के लिए भेजें');
      expect(loc.confirm_payment_btn, 'भुगतान की पुष्टि करें');
      expect(loc.stock_updated_snack, 'स्टॉक सफलतापूर्वक अपडेट हुआ');
    });

    test('Hinglish (Roman Hindi) dictionary contains natural conversational terms', () {
      final loc = lookupAppLocalizations(const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'));

      // Checkout & Bill details
      expect(loc.bill_details, 'Bill Details');
      expect(loc.item_total, 'Items Ka Total');
      expect(loc.delivery_charges, 'Delivery Charges');
      expect(loc.free_delivery_label, 'FREE');
      expect(loc.coupon_discount, 'Coupon Discount');
      expect(loc.total_savings, 'Aapki Total Bachat');
      expect(loc.to_pay, 'Kul Bhugtan');
      expect(loc.payment_method, 'Payment Ka Tarika');
      expect(loc.cash_on_delivery, 'Cash on Delivery (COD)');
      expect(loc.pay_online_upi, 'Online / UPI se Pay Karein');
      expect(loc.khata_pay, 'Khata (Udhaar) se Pay Karein');
      expect(loc.deliver_to, 'Deliver To');
      expect(loc.order_confirmed, 'Order Confirm Ho Gaya!');

      // Form errors
      expect(loc.err_invalid_phone, 'Kripya 10-digit ka valid mobile number daalein');
      expect(loc.err_name_required, 'Naam likhna zaroori hai');
      expect(loc.err_enter_address, 'Kripya pura address daalein');
      expect(loc.err_empty_cart_checkout, 'Khali cart ke saath checkout nahi kar sakte');

      // Order statuses & notifications
      expect(loc.order_status_pending, 'Pending');
      expect(loc.order_status_accepted, 'Accepted');
      expect(loc.order_status_packing, 'Packing Chalu');
      expect(loc.order_status_out, 'Raste Mein');
      expect(loc.order_status_delivered, 'Deliver Ho Gaya');
      expect(loc.item_added_snack, 'Item cart mein add ho gaya');
      expect(loc.item_removed_snack, 'Item cart se hata diya gaya');

      // Digital invoice & empty states
      expect(loc.tax_invoice_title, 'Tax Invoice / Bill');
      expect(loc.grand_total_lbl, 'Grand Total');
      expect(loc.thank_you_shopping, 'Hamare saath shopping karne ke liye shukriya!');
      expect(loc.download_pdf_btn, 'Invoice PDF Download Karein');
      expect(loc.empty_cart_title, 'Aapki Cart Khali Hai');
      expect(loc.order_by_voice_btn, 'Bolkar Order Karein');
      expect(loc.no_orders_title, 'Abhi tak koi order nahi kiya gaya');
    });
  });

  group('Feature 65: Language Selection Persistence Across Restarts', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial boot defaults to English when SharedPreferences is empty', () async {
      final provider = LanguageProvider();
      await provider.loadSavedLanguage();

      expect(provider.currentLanguage, 'en');
      expect(provider.currentLocale, const Locale('en'));
      expect(provider.isEnglish, true);
      expect(provider.isHindi, false);
      expect(provider.isHinglish, false);
    });

    test('Switching to Hindi saves "hi" in SharedPreferences and notifies listeners', () async {
      final provider = LanguageProvider();
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      await provider.setLanguage('hi');

      expect(provider.currentLanguage, 'hi');
      expect(provider.currentLocale, const Locale('hi'));
      expect(provider.isHindi, true);
      expect(notificationCount, greaterThan(0));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_language'), 'hi');
    });

    test('Simulating app restart restores previously selected Hindi language', () async {
      // Simulate stored language in device disk storage
      SharedPreferences.setMockInitialValues({'app_language': 'hi'});

      // Fresh provider instance created on app startup
      final restartedProvider = LanguageProvider();
      await restartedProvider.loadSavedLanguage();

      expect(restartedProvider.currentLanguage, 'hi');
      expect(restartedProvider.currentLocale, const Locale('hi'));
      expect(restartedProvider.isHindi, true);
      expect(restartedProvider.isEnglish, false);
    });

    test('Switching to Hinglish saves "hinglish" and restores BCP-47 hi_Latn after restart', () async {
      SharedPreferences.setMockInitialValues({'app_language': 'hinglish'});

      final restartedProvider = LanguageProvider();
      await restartedProvider.loadSavedLanguage();

      expect(restartedProvider.currentLanguage, 'hinglish');
      expect(restartedProvider.currentLocale, const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'));
      expect(restartedProvider.isHinglish, true);
    });

    test('Corrupted or invalid language key in storage safely falls back to English without crashing', () async {
      // Corrupt/invalid value in prefs
      SharedPreferences.setMockInitialValues({'app_language': 'corrupted_unknown_lang_123'});

      final provider = LanguageProvider();
      await provider.loadSavedLanguage();

      // Gracefully falls back to English
      expect(provider.currentLanguage, 'en');
      expect(provider.currentLocale, const Locale('en'));
      expect(provider.isEnglish, true);
    });
  });

  group('Feature 65: Dynamic UI Localization Rendering Tests', () {
    Widget createLocalizedApp(LanguageProvider provider, Widget child) {
      return ChangeNotifierProvider<LanguageProvider>.value(
        value: provider,
        child: Consumer<LanguageProvider>(
          builder: (context, lang, _) {
            return MaterialApp(
              locale: lang.currentLocale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: child,
            );
          },
        ),
      );
    }

    testWidgets('Renders localized Checkout Bill Details in English and updates immediately to Hindi', (tester) async {
      SharedPreferences.setMockInitialValues({'app_language': 'en'});
      final provider = LanguageProvider();
      await provider.loadSavedLanguage();

      Widget testCheckoutCard() {
        return Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: Column(
                children: [
                  Text(l10n.bill_details, key: const ValueKey('bill_details_title')),
                  Text(l10n.delivery_charges, key: const ValueKey('delivery_charges_lbl')),
                  Text(l10n.free_delivery_label, key: const ValueKey('free_badge')),
                  Text(l10n.to_pay, key: const ValueKey('to_pay_lbl')),
                  Text(l10n.cash_on_delivery, key: const ValueKey('cod_lbl')),
                  Text(l10n.empty_cart_title, key: const ValueKey('empty_cart_lbl')),
                  Text(l10n.download_pdf_btn, key: const ValueKey('pdf_btn_lbl')),
                ],
              ),
            );
          },
        );
      }

      await tester.pumpWidget(createLocalizedApp(provider, testCheckoutCard()));
      await tester.pumpAndSettle();

      // Verify initial English rendering
      expect(find.text('Bill Details'), findsOneWidget);
      expect(find.text('Delivery Charges'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('To Pay'), findsOneWidget);
      expect(find.text('Cash on Delivery (COD)'), findsOneWidget);
      expect(find.text('Your Cart is Empty'), findsOneWidget);
      expect(find.text('Download Invoice PDF'), findsOneWidget);

      // Dynamically switch language to Hindi
      await provider.setLanguage('hi');
      await tester.pumpAndSettle();

      // Verify instant Hindi rendering
      expect(find.text('बिल विवरण'), findsOneWidget);
      expect(find.text('डिलीवरी शुल्क'), findsOneWidget);
      expect(find.text('मुफ़्त'), findsOneWidget);
      expect(find.text('कुल भुगतान'), findsOneWidget);
      expect(find.text('कैश ऑन डिलीवरी (नकद)'), findsOneWidget);
      expect(find.text('आपकी कार्ट खाली है'), findsOneWidget);
      expect(find.text('इनवॉइस PDF डाउनलोड करें'), findsOneWidget);

      // Dynamically switch language to Hinglish
      await provider.setLanguage('hinglish');
      await tester.pumpAndSettle();

      // Verify instant Hinglish rendering
      expect(find.text('Bill Details'), findsOneWidget);
      expect(find.text('Delivery Charges'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('Kul Bhugtan'), findsOneWidget);
      expect(find.text('Cash on Delivery (COD)'), findsOneWidget);
      expect(find.text('Aapki Cart Khali Hai'), findsOneWidget);
      expect(find.text('Invoice PDF Download Karein'), findsOneWidget);
    });

    testWidgets('Context extension context.l10n returns valid AppLocalizations instance', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final provider = LanguageProvider();

      late AppLocalizations retrievedL10n;
      await tester.pumpWidget(
        createLocalizedApp(
          provider,
          Builder(
            builder: (context) {
              retrievedL10n = context.l10n;
              return Container();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(retrievedL10n, isNotNull);
      expect(retrievedL10n.bill_details, isNotEmpty);
    });
  });
}
