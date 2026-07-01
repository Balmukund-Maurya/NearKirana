import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// SoundService — Singleton for playing app sounds & haptic feedback.
/// Usage: SoundService().addToCart();
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;
  bool _hapticsEnabled = true;

  bool get isEnabled => _enabled;
  void setEnabled(bool value) => _enabled = value;
  void setHapticsEnabled(bool value) => _hapticsEnabled = value;

  Future<void> play(String file) async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$file'));
    } catch (e) {
      debugPrint('Sound error: $e');
    }
  }

  Future<void> _vibrate({int duration = 50, int amplitude = 64}) async {
    if (!_hapticsEnabled) return;
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        Vibration.vibrate(duration: duration, amplitude: amplitude);
      }
    } catch (e) {
      debugPrint('Vibration error: $e');
    }
  }

  // ─── Customer Sounds ─────────────────────────────────────

  /// Item added to cart
  Future<void> addToCart() async {
    await play('add_cart.wav');
    _vibrate(duration: 40, amplitude: 80);
  }

  /// Item removed from cart
  Future<void> removeFromCart() => play('remove.wav');

  /// Order placed successfully
  Future<void> orderSuccess() async {
    await play('order_success.wav');
    _vibrate(duration: 200, amplitude: 128);
  }

  /// Order cancelled
  Future<void> orderCancelled() => play('cancel.wav');

  /// PIN entered incorrectly
  Future<void> wrongPin() async {
    await play('error.wav');
    _vibrate(duration: 300, amplitude: 200);
  }

  /// PIN entered correctly / Login success
  Future<void> loginSuccess() => play('success_pin.wav');

  /// Generic success
  Future<void> success() => loginSuccess();

  /// Out of stock tap
  Future<void> blocked() => play('blocked.wav');

  /// Language changed
  Future<void> languageSwitch() => play('switch.wav');

  // ─── Admin Sounds ─────────────────────────────────────

  /// Barcode scanned
  Future<void> barcodeScanned() => play('scan_beep.wav');

  /// New order received
  Future<void> newOrder() async {
    await play('new_order.wav');
    _vibrate(duration: 500, amplitude: 200);
  }

  /// Order status updated
  Future<void> statusUpdated() => play('status_update.wav');

  /// Order dispatched
  Future<void> orderDispatched() => play('dispatch.wav');

  /// Order delivered
  Future<void> orderDelivered() => play('delivered.wav');

  /// Low stock warning
  Future<void> lowStockWarning() => play('low_stock.wav');

  /// Product saved/edited
  Future<void> productSaved() => play('save.wav');

  void dispose() {
    _player.dispose();
  }
}
