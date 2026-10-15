import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:razorpay_flutter/razorpay_flutter.dart';

sealed class RazorpayCheckoutResult {
  const RazorpayCheckoutResult();
}

class RazorpaySuccessResult extends RazorpayCheckoutResult {
  final String paymentId;
  final String? orderId;
  final String? signature;

  const RazorpaySuccessResult({
    required this.paymentId,
    this.orderId,
    this.signature,
  });
}

class RazorpayFailureResult extends RazorpayCheckoutResult {
  final int code;
  final String message;

  const RazorpayFailureResult({
    required this.code,
    required this.message,
  });
}

class RazorpayWalletResult extends RazorpayCheckoutResult {
  final String walletName;

  const RazorpayWalletResult({required this.walletName});
}

class RazorpayService {
  static final RazorpayService _instance = RazorpayService._internal();
  factory RazorpayService() => _instance;
  RazorpayService._internal();

  Razorpay? _razorpay;

  /// Checks if Razorpay native checkout is supported on current platform (Android & iOS)
  static bool get isPlatformSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Starts a Razorpay payment flow.
  /// Returns a Future that resolves only when the user completes payment, cancels, or fails.
  Future<RazorpayCheckoutResult> checkout({
    required String keyId,
    required double amount, // In INR Rupees
    required String shopName,
    required String customerPhone,
    String? customerName,
    String? description,
    Map<String, dynamic>? notes,
  }) async {
    if (!isPlatformSupported) {
      return const RazorpayFailureResult(
        code: -2,
        message:
            'Online Payment Gateway is supported on Android & iOS mobile devices. Please scan the QR code to pay or select Cash on Delivery.',
      );
    }

    final completer = Completer<RazorpayCheckoutResult>();

    try {
      // Dispose any previous instance safely
      _razorpay?.clear();
      _razorpay = Razorpay();

    _razorpay!.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      (PaymentSuccessResponse response) {
        if (!completer.isCompleted) {
          completer.complete(
            RazorpaySuccessResult(
              paymentId: response.paymentId ?? '',
              orderId: response.orderId,
              signature: response.signature,
            ),
          );
        }
      },
    );

    _razorpay!.on(
      Razorpay.EVENT_PAYMENT_ERROR,
      (PaymentFailureResponse response) {
        if (!completer.isCompleted) {
          completer.complete(
            RazorpayFailureResult(
              code: response.code ?? -1,
              message:
                  response.message ?? 'Payment cancelled or declined by user.',
            ),
          );
        }
      },
    );

    _razorpay!.on(
      Razorpay.EVENT_EXTERNAL_WALLET,
      (ExternalWalletResponse response) {
        if (!completer.isCompleted) {
          completer.complete(
            RazorpayWalletResult(
              walletName: response.walletName ?? 'external_wallet',
            ),
          );
        }
      },
    );

    final int amountInPaise = (amount * 100).round();

    final options = {
      'key': keyId.trim(),
      'amount': amountInPaise,
      'name': shopName,
      'description': description ?? 'NearKirana Order Payment',
      'timeout': 300, // 5 minutes timeout
      'prefill': {
        'contact': customerPhone,
        if (customerName != null && customerName.isNotEmpty)
          'name': customerName,
      },
      'theme': {
        'color': '#047857', // Emerald theme
      },
      'notes': ?notes,
    };

      runZonedGuarded(() {
        _razorpay!.open(options);
      }, (error, stack) {
        if (!completer.isCompleted) {
          completer.complete(
            RazorpayFailureResult(
              code: -1,
              message: 'Payment gateway error: $error',
            ),
          );
        }
      });
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete(
          RazorpayFailureResult(
            code: -1,
            message: 'Could not launch payment gateway: $e',
          ),
        );
      }
    }

    return completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        return const RazorpayFailureResult(
          code: -3,
          message:
              'Payment session timed out. Please try again, pay via Store UPI QR, or choose Cash on Delivery.',
        );
      },
    ).whenComplete(() {
      _razorpay?.clear();
      _razorpay = null;
    });
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
