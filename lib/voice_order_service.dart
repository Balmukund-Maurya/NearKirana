// Service layer for Feature 61: Voice-Based Grocery Ordering (वॉइस-बेस्ड ग्रॉसरी ऑर्डरिंग)

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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
      var products = snapshot.docs
          .map((doc) => VoiceCatalogProduct.fromFirestore(doc.data(), doc.id))
          .where((p) => p.name.isNotEmpty)
          .toList();

      // If store has 0 products tagged with shop_id, fallback to all active products in the system
      if (products.isEmpty && shopId.isNotEmpty) {
        final allSnapshot =
            await _firestore.collection('products').limit(300).get();
        products = allSnapshot.docs
            .map((doc) => VoiceCatalogProduct.fromFirestore(doc.data(), doc.id))
            .where((p) => p.name.isNotEmpty)
            .toList();
      }

      return products;
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

/// Speech recognition controller with real microphone STT and animated audio level feedback
class VoiceListeningController with ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechInitialized = false;
  bool _hasSpeechRecognition = false;
  String? _errorMessage;

  VoiceListeningState _state = VoiceListeningState.idle;
  String _currentTranscript = '';
  double _audioLevel = 0.0;
  Timer? _listeningTimer;
  Timer? _waveTimer;

  VoiceListeningState get state => _state;
  String get currentTranscript => _currentTranscript;
  double get audioLevel => _audioLevel;
  bool get isListening => _state == VoiceListeningState.listening;
  String? get errorMessage => _errorMessage;
  bool get hasSpeechRecognition => _hasSpeechRecognition;

  Future<void> startListening({
    String? simulatedTranscript,
    String? localeId,
  }) async {
    _waveTimer?.cancel();
    _listeningTimer?.cancel();
    _currentTranscript = '';
    _errorMessage = null;

    // Simulation / headless testing mode
    if (simulatedTranscript != null) {
      _state = VoiceListeningState.listening;
      _audioLevel = 0.3;
      notifyListeners();

      SoundService().play('scan_beep.wav');

      _waveTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
        if (_state != VoiceListeningState.listening) {
          timer.cancel();
          return;
        }
        _audioLevel = 0.2 + ((timer.tick % 5) * 0.18);
        notifyListeners();
      });

      _listeningTimer = Timer(const Duration(milliseconds: 1600), () {
        completeListening(simulatedTranscript);
      });
      return;
    }

    // REAL Microphone Speech Recognition
    try {
      if (!_speechInitialized) {
        _hasSpeechRecognition = await _speech.initialize(
          onError: (val) {
            debugPrint('STT Error: ${val.errorMsg}');
            _handleSpeechError(val.errorMsg);
          },
          onStatus: (status) {
            debugPrint('STT Status: $status');
            if (status == 'done' || status == 'notListening') {
              if (_state == VoiceListeningState.listening) {
                if (_currentTranscript.trim().isNotEmpty) {
                  completeListening(_currentTranscript.trim());
                } else {
                  stopListening();
                }
              }
            }
          },
        );
        _speechInitialized = true;
      }

      if (!_hasSpeechRecognition) {
        _state = VoiceListeningState.error;
        _errorMessage =
            'Speech recognition is not available or microphone permission was denied.';
        notifyListeners();
        return;
      }

      _state = VoiceListeningState.listening;
      _audioLevel = 0.25;
      notifyListeners();

      SoundService().play('scan_beep.wav');

      // Attempt detecting Hindi/English locale
      String? targetLocale = localeId;
      if (targetLocale == null) {
        try {
          final locales = await _speech.locales();
          final hasHindi =
              locales.any((l) => l.localeId.toLowerCase().startsWith('hi'));
          if (hasHindi) {
            targetLocale = locales
                .firstWhere((l) => l.localeId.toLowerCase().startsWith('hi'))
                .localeId;
          } else {
            final hasIndianEng =
                locales.any((l) => l.localeId.toLowerCase() == 'en_in');
            if (hasIndianEng) targetLocale = 'en_IN';
          }
        } catch (_) {}
      }

      await _speech.listen(
        onResult: (result) {
          _currentTranscript = result.recognizedWords;
          notifyListeners();
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            completeListening(result.recognizedWords.trim());
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: targetLocale,
          cancelOnError: false,
          partialResults: true,
        ),
        onSoundLevelChange: (level) {
          _audioLevel = ((level + 20) / 30).clamp(0.1, 1.0);
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Real speech recognition error: $e');
      _handleSpeechError('Microphone error: $e');
    }
  }

  void _handleSpeechError(String message) {
    _waveTimer?.cancel();
    _listeningTimer?.cancel();
    _errorMessage = message;
    if (_currentTranscript.trim().isNotEmpty) {
      completeListening(_currentTranscript.trim());
    } else {
      _state = VoiceListeningState.error;
      _audioLevel = 0.0;
      notifyListeners();
    }
  }

  void updateTranscript(String text) {
    _currentTranscript = text;
    notifyListeners();
  }

  void completeListening(String finalTranscript) async {
    _waveTimer?.cancel();
    _listeningTimer?.cancel();
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
    }
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

  void stopListening() async {
    _waveTimer?.cancel();
    _listeningTimer?.cancel();
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
    }
    _state = VoiceListeningState.idle;
    _audioLevel = 0.0;
    notifyListeners();
  }

  void reset() async {
    _waveTimer?.cancel();
    _listeningTimer?.cancel();
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
    }
    _state = VoiceListeningState.idle;
    _currentTranscript = '';
    _errorMessage = null;
    _audioLevel = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _listeningTimer?.cancel();
    if (_speech.isListening) {
      _speech.stop();
    }
    super.dispose();
  }
}
