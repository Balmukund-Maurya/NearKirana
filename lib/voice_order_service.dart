// Service layer for Feature 61: Voice-Based Grocery Ordering (वॉइस-बेस्ड ग्रॉसरी ऑर्डरिंग)

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'cart_provider.dart';
import 'crash_reporting_service.dart';
import 'firebase_utils.dart';
import 'sound_service.dart';
import 'voice_order_models.dart';
import 'voice_order_parser.dart';

enum VoiceListeningState {
  idle,
  listening,
  processing,
  success,
  error,
}

class VoiceOrderService {
  final FirebaseFirestore _firestore;

  VoiceOrderService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseUtils.firestore;

  /// Fetches active product catalog for the current store
  Future<List<VoiceCatalogProduct>> fetchCatalog(String shopId) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('products');
      if (shopId.isNotEmpty) {
        query = query.where('shop_id', isEqualTo: shopId);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => VoiceCatalogProduct.fromFirestore(doc.data(), doc.id))
          .where((p) => p.name.isNotEmpty)
          .toList();
    } catch (e, stack) {
      if (kDebugMode) {
        print('Error fetching catalog for voice order: $e');
      }
      CrashReportingService().recordError(
        e,
        stack,
        reason: 'VoiceOrderService.fetchCatalog failed for shop $shopId',
      );
      return [];
    }
  }

  /// Parses spoken query against the shop's catalog
  Future<VoiceOrderParseResult> processSpokenQuery({
    required String spokenText,
    required String shopId,
    List<VoiceCatalogProduct>? preloadedCatalog,
  }) async {
    final catalog = preloadedCatalog ?? await fetchCatalog(shopId);
    return VoiceOrderParser.parseSpokenOrder(
      spokenText: spokenText,
      catalog: catalog,
    );
  }

  /// Commits ready voice items directly to the customer's cart
  int addItemsToCart({
    required CartProvider cartProvider,
    required List<ParsedVoiceItem> items,
  }) {
    int addedCount = 0;

    for (final item in items) {
      if (!item.isReadyToAdd) continue;
      final prod = item.effectiveProduct;
      if (prod == null) continue;

      // Add item to cart
      cartProvider.addItem(
        prod.id,
        prod.name,
        prod.price,
        prod.isLoose,
        prod.stockQuantity,
        imageUrl: prod.imageUrl,
      );

      // Set the precise requested quantity (e.g. 2.0 kg or 0.5 kg)
      cartProvider.setQuantity(prod.id, item.finalQuantity);
      addedCount++;
    }

    if (addedCount > 0) {
      SoundService().addToCart();
      CrashReportingService().addBreadcrumb(
        'Voice Order: Added $addedCount items to cart',
        category: 'voice_ordering',
        data: {'count': addedCount},
      );
    }

    return addedCount;
  }

  /// Logs voice query session for store owner insights
  Future<void> saveVoiceOrderLog({
    required String shopId,
    required String customerPhone,
    required String spokenText,
    required List<ParsedVoiceItem> items,
  }) async {
    try {
      final matchedNames = items
          .where((i) => i.effectiveProduct != null)
          .map((i) => i.effectiveProduct!.name)
          .toList();

      final docRef = _firestore.collection('voice_order_logs').doc();
      final log = VoiceOrderSessionLog(
        id: docRef.id,
        shopId: shopId,
        customerPhone: customerPhone,
        spokenText: spokenText,
        itemCount: items.length,
        matchedItemNames: matchedNames,
        createdAt: DateTime.now(),
      );

      await docRef.set(log.toMap());
    } catch (e) {
      // Non-critical audit logging, swallow error
      if (kDebugMode) {
        print('Voice order log save ignored: $e');
      }
    }
  }
}

/// Helper speech recognition controller with live simulation and audio ripple waves
class VoiceListeningController with ChangeNotifier {
  VoiceListeningState _state = VoiceListeningState.idle;
  String _currentTranscript = '';
  double _audioLevel = 0.0;
  Timer? _listeningTimer;
  Timer? _waveTimer;

  VoiceListeningState get state => _state;
  String get currentTranscript => _currentTranscript;
  double get audioLevel => _audioLevel;
  bool get isListening => _state == VoiceListeningState.listening;

  void startListening({String? simulatedTranscript}) {
    _state = VoiceListeningState.listening;
    _currentTranscript = '';
    _audioLevel = 0.3;
    notifyListeners();

    SoundService().play('scan_beep.wav');

    // Simulate animated audio ripple waves
    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (_state != VoiceListeningState.listening) {
        timer.cancel();
        return;
      }
      _audioLevel = 0.2 + ((timer.tick % 5) * 0.18);
      notifyListeners();
    });

    // Auto complete simulated speech after 1.8 seconds if simulatedTranscript provided
    if (simulatedTranscript != null) {
      _listeningTimer?.cancel();
      _listeningTimer = Timer(const Duration(milliseconds: 1600), () {
        completeListening(simulatedTranscript);
      });
    }
  }

  void updateTranscript(String text) {
    _currentTranscript = text;
    notifyListeners();
  }

  void completeListening(String finalTranscript) {
    _waveTimer?.cancel();
    _listeningTimer?.cancel();
    _state = VoiceListeningState.processing;
    _currentTranscript = finalTranscript;
    _audioLevel = 0.0;
    notifyListeners();

    // Short processing delay for natural UX feel
    Future.delayed(const Duration(milliseconds: 300), () {
      _state = VoiceListeningState.success;
      notifyListeners();
    });
  }

  void stopListening() {
    _waveTimer?.cancel();
    _listeningTimer?.cancel();
    _state = VoiceListeningState.idle;
    _audioLevel = 0.0;
    notifyListeners();
  }

  void reset() {
    _waveTimer?.cancel();
    _listeningTimer?.cancel();
    _state = VoiceListeningState.idle;
    _currentTranscript = '';
    _audioLevel = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _listeningTimer?.cancel();
    super.dispose();
  }
}
