import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/invoice_model.dart';
import 'package:near_kirana/invoice_service.dart';
import 'package:near_kirana/widgets/digital_receipt_dialog.dart';

void main() {
  group('Feature 50: Digital Invoice & Receipt - InvoiceModel Tests', () {
    test('Constructs deterministic InvoiceModel from Firestore order data', () {
      final orderData = {
        'order_id': 'ORD-987654',
        'created_at': Timestamp.fromDate(DateTime(2026, 10, 13, 19, 30)),
        'customer_name': 'Aarav Patel',
        'phone_number': '9876543210',
        'delivery_address': 'Flat 101, Lotus Apartments, Indiranagar',
        'delivery_pin': '4321',
        'delivery_type': 'Delivery',
        'payment_method': 'Cash on Delivery',
        'payment_status': 'Pending',
        'subtotal': 600.0,
        'discount': 50.0,
        'coupon_code': 'SAVE50',
        'delivery_fee': 20.0,
        'total_amount': 570.0,
        'tax_rate': 5.0,
        'items': [
          {
            'id': 'prod_1',
            'name': 'Aashirvaad Shudh Chakki Atta 5kg',
            'quantity': 1.0,
            'unit_price': 250.0,
            'total_price': 250.0,
            'unit': 'pack',
            'is_loose': false,
          },
          {
            'id': 'prod_2',
            'name': 'Fortune Sunlite Refined Sunflower Oil 1L',
            'quantity': 2.0,
            'unit_price': 150.0,
            'total_price': 300.0,
            'unit': 'bottle',
            'is_loose': false,
          },
          {
            'id': 'prod_3',
            'name': 'Loose Fresh Potatoes (Aloo)',
            'quantity': 2.5,
            'unit_price': 20.0,
            'total_price': 50.0,
            'unit': 'kg',
            'is_loose': true,
          },
        ],
      };

      final shopData = {
        'shop_id': 'shop_sharma_01',
        'shop_name': 'Sharma Kirana & General Store',
        'address': 'Main Market Road, Indiranagar, Bengaluru',
        'phone': '9811223344',
        'gstin': '29ABCDE1234F1Z5',
        'fssai': '11223344556677',
        'upi_id': 'sharmakiranastore@okhdfcbank',
      };

      final invoice = InvoiceModel.fromOrder(
        orderData,
        orderId: 'ORD-987654',
        shopData: shopData,
      );

      // Verify header & shop
      expect(invoice.shop.shopName, 'Sharma Kirana & General Store');
      expect(invoice.shop.gstin, '29ABCDE1234F1Z5');
      expect(invoice.shop.fssai, '11223344556677');
      expect(invoice.shop.upiId, 'sharmakiranastore@okhdfcbank');

      // Verify customer
      expect(invoice.customer.customerName, 'Aarav Patel');
      expect(invoice.customer.customerPhone, '9876543210');
      expect(invoice.customer.deliveryPin, '4321');

      // Verify itemization
      expect(invoice.items.length, 3);
      expect(invoice.items[0].name, 'Aashirvaad Shudh Chakki Atta 5kg');
      expect(invoice.items[0].quantity, 1.0);
      expect(invoice.items[0].totalPrice, 250.0);
      expect(invoice.items[2].isLoose, isTrue);
      expect(invoice.items[2].quantity, 2.5);

      // Strict Financial Consistency Check
      expect(invoice.subtotal, 600.0);
      expect(invoice.discount, 50.0);
      expect(invoice.couponCode, 'SAVE50');
      expect(invoice.deliveryFee, 20.0);
      expect(invoice.finalTotal, 570.0); // Exact match with order record
      expect(invoice.formattedTotal, '₹570.00');

      // Tax calculations
      expect(invoice.taxRate, 5.0);
      expect(invoice.taxAmount, greaterThan(0));
      expect(invoice.cgstAmount, closeTo(invoice.sgstAmount, 0.001));
      expect(invoice.cgstAmount + invoice.sgstAmount, closeTo(invoice.taxAmount, 0.001));

      // Deterministic invoice number formatting
      expect(invoice.invoiceNumber, startsWith('INV-20261013-'));
    });

    test('Handles missing/fallback fields smoothly without crashing', () {
      final minimalOrder = <String, dynamic>{
        'items': [],
      };

      final invoice = InvoiceModel.fromOrder(minimalOrder, orderId: 'MIN-001');

      expect(invoice.orderId, 'MIN-001');
      expect(invoice.shop.shopName, 'NearKirana Store');
      expect(invoice.customer.customerName, 'Customer');
      expect(invoice.items, isEmpty);
      expect(invoice.subtotal, 0.0);
      expect(invoice.discount, 0.0);
      expect(invoice.deliveryFee, 0.0);
      expect(invoice.finalTotal, 0.0);
      expect(invoice.formattedTotal, '₹0.00');
    });

    test('Serializes toMap and contains required audit fields', () {
      final invoice = InvoiceModel(
        invoiceNumber: 'INV-20261013-TEST01',
        orderId: 'ORD-TEST01',
        orderDate: DateTime(2026, 10, 13, 10, 0),
        shop: const InvoiceShopDetails(
          shopId: 'shop_1',
          shopName: 'Test Shop',
          address: 'Test Locality',
          phone: '9999999999',
        ),
        customer: const InvoiceCustomerDetails(
          customerName: 'Test Customer',
          customerPhone: '8888888888',
          deliveryAddress: 'Test Address',
          deliveryPin: '1234',
        ),
        items: const [
          InvoiceItem(
            id: 'item_1',
            name: 'Biscuits',
            quantity: 2.0,
            unitPrice: 20.0,
            totalPrice: 40.0,
          ),
        ],
        subtotal: 40.0,
        deliveryFee: 10.0,
        discount: 5.0,
        couponCode: 'WELCOME',
        finalTotal: 45.0,
      );

      final map = invoice.toMap();
      expect(map['invoice_number'], 'INV-20261013-TEST01');
      expect(map['order_id'], 'ORD-TEST01');
      expect(map['final_total'], 45.0);
      expect(map['coupon_code'], 'WELCOME');
      expect(map['shop']['shop_name'], 'Test Shop');
      expect(map['customer']['delivery_pin'], '1234');
      expect((map['items'] as List).length, 1);
    });
  });

  group('Feature 50: Digital Invoice & Receipt - InvoiceService Tests', () {
    late InvoiceModel sampleInvoice;

    setUp(() {
      sampleInvoice = InvoiceModel(
        invoiceNumber: 'INV-20261013-ABCD12',
        orderId: 'ORD-12345',
        orderDate: DateTime(2026, 10, 13, 19, 45),
        shop: const InvoiceShopDetails(
          shopId: 'shop_kirana_99',
          shopName: 'Gupta Kirana Store',
          address: 'Shop #4, Market Complex, Hazratganj, Lucknow',
          phone: '9876501234',
          gstin: '09AABCG1234H1Z8',
          fssai: '22721100000001',
          upiId: 'guptakirana@upi',
        ),
        customer: const InvoiceCustomerDetails(
          customerName: 'Priya Verma',
          customerPhone: '9123456780',
          deliveryAddress: 'B-12, Sector C, Mahanagar, Lucknow',
          deliveryPin: '5678',
        ),
        items: const [
          InvoiceItem(
            id: 'prod_basmati',
            name: 'India Gate Basmati Rice 1kg',
            quantity: 1.0,
            unitPrice: 120.0,
            totalPrice: 120.0,
            unit: 'pack',
          ),
          InvoiceItem(
            id: 'prod_sugar',
            name: 'Madhur Pure Sugar',
            quantity: 2.0,
            unitPrice: 45.0,
            totalPrice: 90.0,
            unit: 'kg',
            isLoose: true,
          ),
        ],
        subtotal: 210.0,
        deliveryFee: 15.0,
        discount: 25.0,
        couponCode: 'FESTIVE25',
        taxRate: 5.0,
        taxAmount: 10.0,
        cgstAmount: 5.0,
        sgstAmount: 5.0,
        finalTotal: 200.0,
      );
    });

    test('generatePdfBytes produces valid vector PDF binary format', () async {
      final service = InvoiceService();
      final pdfBytes = await service.generatePdfBytes(sampleInvoice);

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(500));

      // A valid PDF file starts with '%PDF-' (ASCII: 0x25, 0x50, 0x44, 0x46, 0x2D)
      final header = ascii.decode(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('generateShareableText produces structured WhatsApp / SMS receipt message', () {
      final service = InvoiceService();
      final text = service.generateShareableText(sampleInvoice);

      expect(text, contains('TAX INVOICE & CASH RECEIPT'));
      expect(text, contains('Gupta Kirana Store'));
      expect(text, contains('INV-20261013-ABCD12'));
      expect(text, contains('Priya Verma'));
      expect(text, contains('5678')); // Delivery PIN
      expect(text, contains('India Gate Basmati Rice 1kg'));
      expect(text, contains('Madhur Pure Sugar'));
      expect(text, contains('₹210.00')); // Subtotal
      expect(text, contains('FESTIVE25')); // Coupon
      expect(text, contains('₹200.00')); // Grand Total
    });

    test('saveInvoiceRecord writes invoice document to Cloud Firestore', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = InvoiceService(firestore: fakeFirestore);

      await service.saveInvoiceRecord(sampleInvoice);

      final doc = await fakeFirestore
          .collection('invoices')
          .doc(sampleInvoice.invoiceNumber)
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['invoice_number'], 'INV-20261013-ABCD12');
      expect(doc.data()?['final_total'], 200.0);
    });
  });

  group('Feature 50: Digital Invoice & Receipt - DigitalReceiptDialog Widget Tests', () {
    late InvoiceModel dialogInvoice;

    setUp(() {
      dialogInvoice = InvoiceModel(
        invoiceNumber: 'INV-20261013-UI001',
        orderId: 'ORD-UI-7788',
        orderDate: DateTime(2026, 10, 13, 14, 0),
        shop: const InvoiceShopDetails(
          shopId: 'shop_ui_1',
          shopName: 'BlinkKirana Express',
          address: 'Road 12, Banjara Hills, Hyderabad',
          phone: '9849012345',
          gstin: '36AAAAA0000A1Z5',
        ),
        customer: const InvoiceCustomerDetails(
          customerName: 'Kavita Reddy',
          customerPhone: '9000011223',
          deliveryAddress: 'Plot 45, Jubilee Hills, Hyderabad',
          deliveryPin: '9900',
        ),
        items: const [
          InvoiceItem(
            id: 'item_milk',
            name: 'Amul Taaza Milk 500ml',
            quantity: 2.0,
            unitPrice: 28.0,
            totalPrice: 56.0,
            unit: 'pouch',
          ),
          InvoiceItem(
            id: 'item_bread',
            name: 'Britannia Brown Bread 400g',
            quantity: 1.0,
            unitPrice: 45.0,
            totalPrice: 45.0,
            unit: 'pack',
          ),
        ],
        subtotal: 101.0,
        deliveryFee: 0.0,
        discount: 10.0,
        couponCode: 'SAVE10',
        taxRate: 5.0,
        taxAmount: 4.81,
        cgstAmount: 2.40,
        sgstAmount: 2.41,
        finalTotal: 91.0,
      );
    });

    testWidgets('Renders all receipt sections, item details, and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DigitalReceiptDialog(invoice: dialogInvoice),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header shop details
      expect(find.text('BlinkKirana Express'), findsOneWidget);
      expect(find.text('Road 12, Banjara Hills, Hyderabad'), findsOneWidget);

      // Invoice info
      expect(find.text('INV-20261013-UI001'), findsOneWidget);
      expect(find.textContaining('ORD-UI-7788'), findsOneWidget);
      expect(find.textContaining('GSTIN: 36AAAAA0000A1Z5'), findsOneWidget);

      // Customer info
      expect(find.textContaining('Billed To: Kavita Reddy'), findsOneWidget);
      expect(find.textContaining('Delivery PIN: 9900'), findsOneWidget);

      // Items list
      expect(find.text('Amul Taaza Milk 500ml'), findsOneWidget);
      expect(find.text('Britannia Brown Bread 400g'), findsOneWidget);

      // Financials
      expect(find.text('₹101.00'), findsOneWidget); // Subtotal
      expect(find.text('-₹10.00'), findsOneWidget); // Discount
      expect(find.text('FREE'), findsOneWidget); // Delivery fee
      expect(find.text('₹91.00'), findsOneWidget); // Grand total

      // Action Buttons
      expect(find.text('Download PDF'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Share WhatsApp'), findsOneWidget);
    });

    testWidgets('DigitalReceiptDialog.showForOrder opens modal correctly', (tester) async {
      final testOrderData = {
        'order_id': 'ORD-MODAL-11',
        'subtotal': 150.0,
        'total_amount': 150.0,
        'customer_name': 'Ramesh Kumar',
        'phone_number': '9988776655',
        'delivery_address': 'Flat 2B, MG Road',
        'items': [
          {
            'name': 'Tata Salt 1kg',
            'quantity': 1.0,
            'unit_price': 28.0,
            'total_price': 28.0,
          }
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  DigitalReceiptDialog.showForOrder(
                    ctx,
                    orderData: testOrderData,
                    orderId: 'ORD-MODAL-11',
                  );
                },
                child: const Text('Open Receipt'),
              ),
            ),
          ),
        ),
      );

      // Tap button to open dialog
      await tester.tap(find.text('Open Receipt'));
      await tester.pumpAndSettle();

      // Receipt opened
      expect(find.text('Tata Salt 1kg'), findsOneWidget);
      expect(find.textContaining('Billed To: Ramesh Kumar'), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);

      // Tap close icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('Tata Salt 1kg'), findsNothing);
    });
  });
}
